"""
Lambda: EventBridge Scheduler -> SNS push (cloud layer of the two-layer alarm).

Invoked at each reminder fire time with the payload written by
app.services.scheduling. Publishes to the notifications SNS topic (fans out to
APNs/FCM platform endpoints) and records every attempt in notification_deliveries
(spec R7.4). Quiet hours (R7.3) suppress non-critical pushes; the device layer
still fires locally.
"""

import json
import logging
import os
import uuid
from datetime import datetime, timedelta, timezone

import boto3
import psycopg2

from app.db_url import sync_database_url

logger = logging.getLogger()
logger.setLevel(logging.INFO)

_sns = None


def in_quiet_hours(hour: int, start: int = 22, end: int = 7) -> bool:
    if start == end:
        return False
    return start <= hour < end if start < end else (hour >= start or hour < end)


def should_suppress(priority: str, fire_at: datetime, utc_offset_minutes: int = 0) -> bool:
    """High-priority reminders always ring; others respect quiet hours."""
    if priority == "high":
        return False
    local = fire_at.astimezone(timezone(timedelta(minutes=utc_offset_minutes)))
    return in_quiet_hours(local.hour)


def _record(conn, reminder_id, user_id, status, fire_at, message_id=None, error=None):
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO notification_deliveries "
            "(id, reminder_id, user_id, channel, status, fire_at, message_id, error, created_at) "
            "VALUES (%s,%s,%s,'push',%s,%s,%s,%s,now())",
            (str(uuid.uuid4()), reminder_id, user_id, status, fire_at, message_id, error),
        )
    conn.commit()


def handler(event, _context):
    global _sns
    _sns = _sns or boto3.client("sns")
    reminder_id, user_id = event["reminder_id"], event["user_id"]
    fire_at = datetime.fromisoformat(event["fire_at"])
    conn = psycopg2.connect(sync_database_url())
    try:
        _record(conn, reminder_id, user_id, "triggered", fire_at)
        if should_suppress(event.get("priority", "medium"), fire_at):
            logger.info("Quiet hours: suppressed push for %s", reminder_id)
            return {"suppressed": True}
        try:
            resp = _sns.publish(
                TopicArn=os.environ["NOTIFICATION_TOPIC_ARN"],
                Message=json.dumps({"default": event["title"], "reminder_id": reminder_id}),
                MessageStructure="json",
                MessageAttributes={"user_id": {"DataType": "String", "StringValue": user_id}},
            )
            _record(conn, reminder_id, user_id, "sent", fire_at, message_id=resp["MessageId"])
            return {"sent": True, "message_id": resp["MessageId"]}
        except Exception as exc:  # never lose a reminder silently
            logger.exception("SNS publish failed")
            _record(conn, reminder_id, user_id, "failed", fire_at, error=str(exc)[:1000])
            raise
    finally:
        conn.close()
