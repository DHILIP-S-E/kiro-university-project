import os

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://u:p@localhost/db")

from datetime import datetime, timezone

from app.models.delivery import DELIVERY_STATUSES, NotificationDelivery


def test_to_dict_round_trips_fields():
    fire = datetime(2026, 10, 4, 9, 0, tzinfo=timezone.utc)
    d = NotificationDelivery(
        id="d1", reminder_id="r1", user_id="u1", channel="push", status="sent",
        fire_at=fire, message_id="m1", error=None, created_at=fire,
    ).to_dict()
    assert d["reminder_id"] == "r1" and d["status"] == "sent"
    assert d["fire_at"] == fire.isoformat()


def test_to_dict_handles_missing_times():
    d = NotificationDelivery(id="d", reminder_id="r", user_id="u").to_dict()
    assert d["fire_at"] is None and d["created_at"] is None


def test_lifecycle_statuses_cover_the_spec():
    assert {"scheduled", "triggered", "sent", "delivered", "failed", "retrying", "cancelled"} <= set(DELIVERY_STATUSES)
