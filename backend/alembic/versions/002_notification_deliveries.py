"""notification_deliveries: columns the dispatcher records (spec R7.4)

001 already created this table with provider-oriented columns. The dispatcher
logs channel / fire time / SNS message id / error, so add those. The 001
columns stay (nullable, unused) so existing rows and downgrades remain valid.

Revision ID: 002
Revises: 001
Create Date: 2026-09-30
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "002"
down_revision: Union[str, None] = "001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("notification_deliveries", sa.Column("channel", sa.String(20), server_default="push"))
    op.add_column("notification_deliveries", sa.Column("fire_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("notification_deliveries", sa.Column("message_id", sa.String(255), nullable=True))
    op.add_column("notification_deliveries", sa.Column("error", sa.Text, nullable=True))
    op.create_index("ix_notification_deliveries_user_id", "notification_deliveries", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_notification_deliveries_user_id", table_name="notification_deliveries")
    op.drop_column("notification_deliveries", "error")
    op.drop_column("notification_deliveries", "message_id")
    op.drop_column("notification_deliveries", "fire_at")
    op.drop_column("notification_deliveries", "channel")
