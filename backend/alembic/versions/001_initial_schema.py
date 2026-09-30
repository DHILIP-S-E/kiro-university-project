"""Initial schema — all tables

Revision ID: 001
Revises:
Create Date: 2026-09-30
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── reminders ────────────────────────────────────────────────────────────
    op.create_table(
        "reminders",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(255), nullable=False),
        sa.Column("title", sa.String(500), nullable=False),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("reminder_type", sa.String(50), nullable=False, server_default="time"),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("timezone", sa.String(100), server_default="UTC"),
        sa.Column("priority", sa.String(20), server_default="medium"),
        sa.Column("status", sa.String(20), server_default="active"),
        sa.Column("alarm_enabled", sa.Boolean, server_default="true"),
        sa.Column("notification_enabled", sa.Boolean, server_default="true"),
        sa.Column("recurrence_rule", sa.String(500), nullable=True),
        sa.Column("source", sa.String(50), server_default="manual"),
        sa.Column("context_id", sa.String(36), nullable=True),
        sa.Column("offsets", sa.Text, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_reminders_user_id", "reminders", ["user_id"])
    op.create_index("ix_reminders_status", "reminders", ["status"])

    # ── events ───────────────────────────────────────────────────────────────
    op.create_table(
        "events",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(255), nullable=False),
        sa.Column("title", sa.String(500), nullable=False),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("event_type", sa.String(50), server_default="custom"),
        sa.Column("start_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("timezone", sa.String(100), server_default="UTC"),
        sa.Column("location", sa.String(500), nullable=True),
        sa.Column("is_virtual", sa.Boolean, server_default="false"),
        sa.Column("event_url", sa.String(1000), nullable=True),
        sa.Column("organizer", sa.String(500), nullable=True),
        sa.Column("registration_url", sa.String(1000), nullable=True),
        sa.Column("status", sa.String(20), server_default="upcoming"),
        sa.Column("summary_id", sa.String(36), nullable=True),
        sa.Column("photo_count", sa.Integer, server_default="0"),
        sa.Column("voice_note_count", sa.Integer, server_default="0"),
        sa.Column("document_count", sa.Integer, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_events_user_id", "events", ["user_id"])
    op.create_index("ix_events_status", "events", ["status"])

    # ── event_deadlines ───────────────────────────────────────────────────────
    op.create_table(
        "event_deadlines",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "event_id",
            sa.String(36),
            sa.ForeignKey("events.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("user_id", sa.String(255), nullable=False),
        sa.Column("title", sa.String(500), nullable=False),
        sa.Column("deadline_type", sa.String(50), server_default="custom"),
        sa.Column("deadline_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", sa.String(20), server_default="active"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_event_deadlines_event_id", "event_deadlines", ["event_id"])

    # ── captures ─────────────────────────────────────────────────────────────
    op.create_table(
        "captures",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(255), nullable=False),
        sa.Column("event_id", sa.String(36), nullable=True),
        sa.Column("capture_type", sa.String(20), nullable=False),
        sa.Column("storage_key", sa.String(1000), nullable=True),
        sa.Column("mime_type", sa.String(100), nullable=True),
        sa.Column("duration", sa.Integer, nullable=True),
        sa.Column("transcription", sa.Text, nullable=True),
        sa.Column("content", sa.Text, nullable=True),
        sa.Column("processing_status", sa.String(20), server_default="uploaded"),
        sa.Column("ai_summary", sa.Text, nullable=True),
        sa.Column("ai_topics", sa.Text, nullable=True),
        sa.Column("ai_key_points", sa.Text, nullable=True),
        sa.Column("ai_actions", sa.Text, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_captures_user_id", "captures", ["user_id"])
    op.create_index("ix_captures_event_id", "captures", ["event_id"])

    # ── memory_documents ──────────────────────────────────────────────────────
    op.create_table(
        "memory_documents",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(255), nullable=False),
        sa.Column("event_id", sa.String(36), nullable=True),
        sa.Column("event_title", sa.String(500), nullable=True),
        sa.Column("overview", sa.Text, nullable=True),
        sa.Column("key_topics", sa.Text, nullable=True),
        sa.Column("key_takeaways", sa.Text, nullable=True),
        sa.Column("things_learned", sa.Text, nullable=True),
        sa.Column("important_people", sa.Text, nullable=True),
        sa.Column("resources", sa.Text, nullable=True),
        sa.Column("links", sa.Text, nullable=True),
        sa.Column("action_items", sa.Text, nullable=True),
        sa.Column("deadlines", sa.Text, nullable=True),
        sa.Column("decisions", sa.Text, nullable=True),
        sa.Column("search_vector", sa.Text, nullable=True),
        sa.Column("event_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_memory_documents_user_id", "memory_documents", ["user_id"])
    op.create_index("ix_memory_documents_event_id", "memory_documents", ["event_id"])

    # ── notification_deliveries ───────────────────────────────────────────────
    op.create_table(
        "notification_deliveries",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("reminder_id", sa.String(36), nullable=False),
        sa.Column("user_id", sa.String(255), nullable=False),
        sa.Column("device_id", sa.String(255), nullable=True),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("sent_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("status", sa.String(20), server_default="scheduled"),
        sa.Column("provider", sa.String(50), nullable=True),
        sa.Column("attempt_count", sa.Integer, server_default="0"),
        sa.Column("error_code", sa.String(100), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index(
        "ix_notification_deliveries_reminder_id",
        "notification_deliveries",
        ["reminder_id"],
    )


def downgrade() -> None:
    op.drop_table("notification_deliveries")
    op.drop_table("memory_documents")
    op.drop_table("captures")
    op.drop_table("event_deadlines")
    op.drop_table("events")
    op.drop_table("reminders")
