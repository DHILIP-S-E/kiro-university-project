"""Enqueue captures that never touch S3 (text notes, links) for AI processing.

Photos/voice/documents are enqueued by the S3 -> EventBridge -> SQS path; notes
and links are stored in the database only, so the API sends the message itself.
"""

import json
import logging

import boto3

from app.config import settings

logger = logging.getLogger(__name__)


def enqueue_text_capture(capture_id: str) -> bool:
    """Best-effort. Returns False (and logs) if the queue is unconfigured or fails;
    the capture stays 'queued' in the database so it can be re-driven."""
    if not settings.capture_queue_url:
        return False
    try:
        boto3.client("sqs", region_name=settings.aws_region).send_message(
            QueueUrl=settings.capture_queue_url,
            MessageBody=json.dumps({"capture_id": capture_id}),
        )
        return True
    except Exception:
        logger.exception("Could not enqueue capture %s", capture_id)
        return False
