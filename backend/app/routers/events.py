"""
Event API router — full CRUD with nested deadlines, user-scoped.
"""

import uuid
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.auth import get_current_user_id
from app.database import get_db
from app.models.event import Event, EventDeadline
from app.models.capture import Capture

router = APIRouter()


# ── Pydantic schemas ──────────────────────────────────────────────────────────

class DeadlineIn(BaseModel):
    title: str
    deadline_type: str = "custom"
    deadline_at: datetime


class EventCreate(BaseModel):
    title: str
    description: Optional[str] = None
    event_type: str = "custom"
    start_at: datetime
    end_at: Optional[datetime] = None
    timezone: str = "UTC"
    location: Optional[str] = None
    is_virtual: bool = False
    event_url: Optional[str] = None
    organizer: Optional[str] = None
    registration_url: Optional[str] = None
    deadlines: list[DeadlineIn] = []


class EventUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = None
    start_at: Optional[datetime] = None
    end_at: Optional[datetime] = None
    location: Optional[str] = None
    event_url: Optional[str] = None
    organizer: Optional[str] = None


# ── Routes ────────────────────────────────────────────────────────────────────

@router.post("", status_code=status.HTTP_201_CREATED)
async def create_event(
    body: EventCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.utcnow()
    event_id = str(uuid.uuid4())

    event = Event(
        id=event_id,
        user_id=user_id,
        title=body.title,
        description=body.description,
        event_type=body.event_type,
        start_at=body.start_at,
        end_at=body.end_at,
        timezone=body.timezone,
        location=body.location,
        is_virtual=body.is_virtual,
        event_url=body.event_url,
        organizer=body.organizer,
        registration_url=body.registration_url,
        created_at=now,
        updated_at=now,
    )
    db.add(event)

    for dl in body.deadlines:
        deadline = EventDeadline(
            id=str(uuid.uuid4()),
            event_id=event_id,
            user_id=user_id,
            title=dl.title,
            deadline_type=dl.deadline_type,
            deadline_at=dl.deadline_at,
            created_at=now,
        )
        db.add(deadline)

    await db.commit()

    # Re-fetch with deadlines loaded
    result = await db.execute(
        select(Event)
        .options(selectinload(Event.deadlines))
        .where(Event.id == event_id)
    )
    event = result.scalar_one()
    return event.to_dict()


@router.get("")
async def list_events(
    event_status: Optional[str] = None,
    event_type: Optional[str] = None,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    query = (
        select(Event)
        .options(selectinload(Event.deadlines))
        .where(Event.user_id == user_id)
    )
    if event_status:
        query = query.where(Event.status == event_status)
    if event_type:
        query = query.where(Event.event_type == event_type)
    query = query.order_by(Event.start_at.desc())
    result = await db.execute(query)
    events = result.scalars().all()

    # Attach live capture counts
    out = []
    for e in events:
        d = e.to_dict()
        counts = await _capture_counts(e.id, user_id, db)
        d.update(counts)
        out.append(d)
    return out


@router.get("/{event_id}")
async def get_event(
    event_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    event = await _get_owned(event_id, user_id, db)
    d = event.to_dict()
    counts = await _capture_counts(event_id, user_id, db)
    d.update(counts)
    return d


@router.patch("/{event_id}")
async def update_event(
    event_id: str,
    body: EventUpdate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    event = await _get_owned(event_id, user_id, db)
    if body.title is not None:
        event.title = body.title
    if body.description is not None:
        event.description = body.description
    if body.status is not None:
        event.status = body.status
    if body.start_at is not None:
        event.start_at = body.start_at
    if body.end_at is not None:
        event.end_at = body.end_at
    if body.location is not None:
        event.location = body.location
    if body.event_url is not None:
        event.event_url = body.event_url
    if body.organizer is not None:
        event.organizer = body.organizer
    event.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(event)
    return event.to_dict()


@router.delete("/{event_id}", status_code=status.HTTP_200_OK)
async def delete_event(
    event_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    event = await _get_owned(event_id, user_id, db)
    await db.delete(event)
    await db.commit()
    return {"deleted": event_id}


@router.post("/{event_id}/deadlines", status_code=status.HTTP_201_CREATED)
async def add_deadline(
    event_id: str,
    body: DeadlineIn,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    await _get_owned(event_id, user_id, db)
    deadline = EventDeadline(
        id=str(uuid.uuid4()),
        event_id=event_id,
        user_id=user_id,
        title=body.title,
        deadline_type=body.deadline_type,
        deadline_at=body.deadline_at,
        created_at=datetime.utcnow(),
    )
    db.add(deadline)
    await db.commit()
    await db.refresh(deadline)
    return deadline.to_dict()


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _get_owned(event_id: str, user_id: str, db: AsyncSession) -> Event:
    result = await db.execute(
        select(Event)
        .options(selectinload(Event.deadlines))
        .where(Event.id == event_id, Event.user_id == user_id)
    )
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return event


async def _capture_counts(event_id: str, user_id: str, db: AsyncSession) -> dict:
    result = await db.execute(
        select(Capture.capture_type, func.count(Capture.id))
        .where(Capture.event_id == event_id, Capture.user_id == user_id)
        .group_by(Capture.capture_type)
    )
    rows = result.all()
    counts = {"photo_count": 0, "voice_note_count": 0, "document_count": 0}
    for ctype, cnt in rows:
        if ctype == "photo":
            counts["photo_count"] = cnt
        elif ctype == "voice":
            counts["voice_note_count"] = cnt
        elif ctype == "document":
            counts["document_count"] = cnt
    return counts
