"""
Account data rights (spec R5.7, R5.8): export everything, delete everything.
Deletion cascades S3 objects, DB rows, and pending cloud reminder schedules.
"""

import json
import logging

from fastapi import APIRouter, Depends
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user_id
from app.database import get_db
from app.models.capture import Capture
from app.models.delivery import NotificationDelivery
from app.models.event import Event, EventDeadline
from app.models.memory import MemoryDocument
from app.models.reminder import Reminder
from app.services import knowledge_base, scheduling
from app.services.s3_service import delete_object

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/export")
async def export_account(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Return all of the user's data as one JSON document."""

    async def rows(model):
        result = await db.execute(select(model).where(model.user_id == user_id))
        return [r.to_dict() for r in result.scalars().all()]

    return {
        "user_id": user_id,
        "reminders": await rows(Reminder),
        "events": await rows(Event),
        "event_deadlines": await rows(EventDeadline),
        "captures": await rows(Capture),
        "memory_documents": await rows(MemoryDocument),
        "notification_deliveries": await rows(NotificationDelivery),
    }


@router.delete("")
async def delete_account(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Permanently delete all user data (S3 media, schedules, database rows)."""
    reminders = (
        await db.execute(select(Reminder).where(Reminder.user_id == user_id))
    ).scalars().all()
    for r in reminders:
        try:
            scheduling.cancel_reminder(r.id, r.scheduled_at, json.loads(r.offsets or "[]"))
        except Exception:
            logger.exception("Could not cancel schedules for reminder %s", r.id)

    captures = (
        await db.execute(select(Capture).where(Capture.user_id == user_id))
    ).scalars().all()
    for c in captures:
        if c.storage_key:
            delete_object(c.storage_key)

    knowledge_base.remove_user_documents(user_id)
    for model in (NotificationDelivery, MemoryDocument, Capture, EventDeadline, Reminder, Event):
        await db.execute(delete(model).where(model.user_id == user_id))
    await db.commit()
    return {"deleted": True, "reminders": len(reminders), "captures": len(captures)}
