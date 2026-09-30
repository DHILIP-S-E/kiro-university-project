"""
Capture API router.

Upload flow:
  1. Flutter  →  POST /captures/upload-url  →  gets {upload_url, capture_id, s3_key}
  2. Flutter  →  PUT  <upload_url>          →  uploads file directly to S3
  3. Flutter  →  POST /captures             →  registers capture in DB
  4. Flutter  →  GET  /captures/{id}/download-url  →  gets pre-signed GET URL

Text notes and links skip S3 entirely (content stored in DB).
"""

import uuid
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user_id
from app.database import get_db
from app.models.capture import Capture
from app.services.s3_service import (
    generate_upload_url,
    generate_download_url,
    delete_object,
)

router = APIRouter()

# S3 key pattern:  users/{user_id}/events/{event_id}/{type}/{capture_id}.{ext}
#                  users/{user_id}/misc/{type}/{capture_id}.{ext}
_S3_KEY_TEMPLATE = "users/{user_id}/{event_part}{capture_type}/{capture_id}.{ext}"


# ── Pydantic schemas ──────────────────────────────────────────────────────────

class UploadUrlRequest(BaseModel):
    capture_type: str          # photo | voice | document
    file_extension: str        # jpg | m4a | pdf | mp4
    content_type: str          # image/jpeg | audio/m4a | application/pdf
    event_id: Optional[str] = None


class RegisterCaptureRequest(BaseModel):
    capture_id: str
    storage_key: str
    capture_type: str
    event_id: Optional[str] = None
    mime_type: Optional[str] = None
    duration: Optional[int] = None   # seconds, for audio/video


class TextNoteRequest(BaseModel):
    content: str
    event_id: Optional[str] = None


class LinkRequest(BaseModel):
    url: str
    event_id: Optional[str] = None


class CaptureUpdateRequest(BaseModel):
    processing_status: Optional[str] = None
    transcription: Optional[str] = None
    ai_summary: Optional[str] = None
    ai_topics: Optional[str] = None      # JSON string
    ai_key_points: Optional[str] = None  # JSON string
    ai_actions: Optional[str] = None     # JSON string


# ── Routes ────────────────────────────────────────────────────────────────────

@router.post("/upload-url")
async def get_upload_url(
    body: UploadUrlRequest,
    user_id: str = Depends(get_current_user_id),
):
    """Step 1 — get a pre-signed PUT URL for direct S3 upload."""
    capture_id = str(uuid.uuid4())
    event_part = f"events/{body.event_id}/" if body.event_id else "misc/"
    s3_key = _S3_KEY_TEMPLATE.format(
        user_id=user_id,
        event_part=event_part,
        capture_type=body.capture_type,
        capture_id=capture_id,
        ext=body.file_extension,
    )
    upload_url = generate_upload_url(s3_key, body.content_type)
    return {
        "upload_url": upload_url,
        "capture_id": capture_id,
        "s3_key": s3_key,
        "expires_in": 3600,
    }


@router.post("", status_code=status.HTTP_201_CREATED)
async def register_capture(
    body: RegisterCaptureRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Step 3 — register capture in DB after successful S3 upload."""
    now = datetime.utcnow()
    capture = Capture(
        id=body.capture_id,
        user_id=user_id,
        event_id=body.event_id,
        capture_type=body.capture_type,
        storage_key=body.storage_key,
        mime_type=body.mime_type,
        duration=body.duration,
        processing_status="queued",
        created_at=now,
        updated_at=now,
    )
    db.add(capture)
    await db.commit()
    await db.refresh(capture)
    return capture.to_dict()


@router.post("/note", status_code=status.HTTP_201_CREATED)
async def create_text_note(
    body: TextNoteRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Create a text note — no S3 upload needed."""
    now = datetime.utcnow()
    capture = Capture(
        id=str(uuid.uuid4()),
        user_id=user_id,
        event_id=body.event_id,
        capture_type="note",
        content=body.content,
        processing_status="queued",
        created_at=now,
        updated_at=now,
    )
    db.add(capture)
    await db.commit()
    await db.refresh(capture)
    return capture.to_dict()


@router.post("/link", status_code=status.HTTP_201_CREATED)
async def save_link(
    body: LinkRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Save a URL — no S3 upload needed."""
    now = datetime.utcnow()
    capture = Capture(
        id=str(uuid.uuid4()),
        user_id=user_id,
        event_id=body.event_id,
        capture_type="link",
        content=body.url,
        processing_status="queued",
        created_at=now,
        updated_at=now,
    )
    db.add(capture)
    await db.commit()
    await db.refresh(capture)
    return capture.to_dict()


@router.get("")
async def list_captures(
    event_id: Optional[str] = None,
    capture_type: Optional[str] = None,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    query = select(Capture).where(Capture.user_id == user_id)
    if event_id:
        query = query.where(Capture.event_id == event_id)
    if capture_type:
        query = query.where(Capture.capture_type == capture_type)
    query = query.order_by(Capture.created_at.desc())
    result = await db.execute(query)
    return [c.to_dict() for c in result.scalars().all()]


@router.get("/{capture_id}")
async def get_capture(
    capture_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    capture = await _get_owned(capture_id, user_id, db)
    return capture.to_dict()


@router.get("/{capture_id}/download-url")
async def get_download_url(
    capture_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Return a short-lived pre-signed GET URL for the capture's S3 object."""
    capture = await _get_owned(capture_id, user_id, db)
    if not capture.storage_key:
        raise HTTPException(
            status_code=404,
            detail="This capture has no associated file",
        )
    url = generate_download_url(capture.storage_key)
    return {"download_url": url, "expires_in": 3600}


@router.patch("/{capture_id}")
async def update_capture(
    capture_id: str,
    body: CaptureUpdateRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Update processing status and AI result fields (called by backend workers)."""
    capture = await _get_owned(capture_id, user_id, db)
    if body.processing_status is not None:
        capture.processing_status = body.processing_status
    if body.transcription is not None:
        capture.transcription = body.transcription
    if body.ai_summary is not None:
        capture.ai_summary = body.ai_summary
    if body.ai_topics is not None:
        capture.ai_topics = body.ai_topics
    if body.ai_key_points is not None:
        capture.ai_key_points = body.ai_key_points
    if body.ai_actions is not None:
        capture.ai_actions = body.ai_actions
    capture.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(capture)
    return capture.to_dict()


@router.delete("/{capture_id}", status_code=status.HTTP_200_OK)
async def delete_capture(
    capture_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    capture = await _get_owned(capture_id, user_id, db)
    # Remove S3 object if present
    if capture.storage_key:
        delete_object(capture.storage_key)
    await db.delete(capture)
    await db.commit()
    return {"deleted": capture_id}


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _get_owned(capture_id: str, user_id: str, db: AsyncSession) -> Capture:
    result = await db.execute(
        select(Capture).where(
            Capture.id == capture_id, Capture.user_id == user_id
        )
    )
    capture = result.scalar_one_or_none()
    if not capture:
        raise HTTPException(status_code=404, detail="Capture not found")
    return capture
