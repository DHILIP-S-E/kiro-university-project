"""
Reminder API router — full CRUD, user-scoped.
All routes require a valid Cognito JWT.
"""

import json
import uuid
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user_id
from app.database import get_db
from app.models.reminder import Reminder

router = APIRouter()


# ── Pydantic schemas ──────────────────────────────────────────────────────────

class ReminderCreate(BaseModel):
    title: str
    description: Optional[str] = None
    reminder_type: str = "time"
    scheduled_at: Optional[datetime] = None
    timezone: str = "UTC"
    priority: str = "medium"
    alarm_enabled: bool = True
    notification_enabled: bool = True
    recurrence_rule: Optional[str] = None
    source: str = "manual"
    context_id: Optional[str] = None
    offsets: Optional[list[str]] = []


class ReminderUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = None
    scheduled_at: Optional[datetime] = None
    priority: Optional[str] = None
    alarm_enabled: Optional[bool] = None


# ── Routes ────────────────────────────────────────────────────────────────────

@router.post("", status_code=status.HTTP_201_CREATED)
async def create_reminder(
    body: ReminderCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.utcnow()
    reminder = Reminder(
        id=str(uuid.uuid4()),
        user_id=user_id,
        title=body.title,
        description=body.description,
        reminder_type=body.reminder_type,
        scheduled_at=body.scheduled_at,
        timezone=body.timezone,
        priority=body.priority,
        alarm_enabled=body.alarm_enabled,
        notification_enabled=body.notification_enabled,
        recurrence_rule=body.recurrence_rule,
        source=body.source,
        context_id=body.context_id,
        offsets=json.dumps(body.offsets or []),
        created_at=now,
        updated_at=now,
    )
    db.add(reminder)
    await db.commit()
    await db.refresh(reminder)
    return reminder.to_dict()


@router.get("")
async def list_reminders(
    reminder_status: Optional[str] = None,
    reminder_type: Optional[str] = None,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    query = select(Reminder).where(Reminder.user_id == user_id)
    if reminder_status:
        query = query.where(Reminder.status == reminder_status)
    if reminder_type:
        query = query.where(Reminder.reminder_type == reminder_type)
    query = query.order_by(Reminder.scheduled_at.asc().nulls_last())
    result = await db.execute(query)
    return [r.to_dict() for r in result.scalars().all()]


@router.get("/{reminder_id}")
async def get_reminder(
    reminder_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    reminder = await _get_owned(reminder_id, user_id, db)
    return reminder.to_dict()


@router.patch("/{reminder_id}")
async def update_reminder(
    reminder_id: str,
    body: ReminderUpdate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    reminder = await _get_owned(reminder_id, user_id, db)
    if body.title is not None:
        reminder.title = body.title
    if body.description is not None:
        reminder.description = body.description
    if body.status is not None:
        reminder.status = body.status
    if body.scheduled_at is not None:
        reminder.scheduled_at = body.scheduled_at
    if body.priority is not None:
        reminder.priority = body.priority
    if body.alarm_enabled is not None:
        reminder.alarm_enabled = body.alarm_enabled
    reminder.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(reminder)
    return reminder.to_dict()


@router.delete("/{reminder_id}", status_code=status.HTTP_200_OK)
async def delete_reminder(
    reminder_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    reminder = await _get_owned(reminder_id, user_id, db)
    await db.delete(reminder)
    await db.commit()
    return {"deleted": reminder_id}


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _get_owned(reminder_id: str, user_id: str, db: AsyncSession) -> Reminder:
    result = await db.execute(
        select(Reminder).where(
            Reminder.id == reminder_id, Reminder.user_id == user_id
        )
    )
    reminder = result.scalar_one_or_none()
    if not reminder:
        raise HTTPException(status_code=404, detail="Reminder not found")
    return reminder
