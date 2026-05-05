"""add notifications table

Revision ID: 20260505_0009
Revises: 20260505_0008
Create Date: 2026-05-05 03:10:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260505_0009"
down_revision = "20260505_0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "notification",
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("recipient_user_id", sa.String(), nullable=False),
        sa.Column("actor_user_id", sa.String(), nullable=True),
        sa.Column("kind", sa.String(), nullable=False),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("body", sa.String(), nullable=False),
        sa.Column("resource_type", sa.String(), nullable=True),
        sa.Column("resource_id", sa.String(), nullable=True),
        sa.Column("metadata_json", sa.String(), nullable=True),
        sa.Column("is_read", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("read_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["actor_user_id"], ["user.id"]),
        sa.ForeignKeyConstraint(["recipient_user_id"], ["user.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_notification_actor_user_id"), "notification", ["actor_user_id"], unique=False)
    op.create_index(op.f("ix_notification_is_read"), "notification", ["is_read"], unique=False)
    op.create_index(op.f("ix_notification_kind"), "notification", ["kind"], unique=False)
    op.create_index(op.f("ix_notification_recipient_user_id"), "notification", ["recipient_user_id"], unique=False)
    op.create_index(op.f("ix_notification_resource_id"), "notification", ["resource_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_notification_resource_id"), table_name="notification")
    op.drop_index(op.f("ix_notification_recipient_user_id"), table_name="notification")
    op.drop_index(op.f("ix_notification_kind"), table_name="notification")
    op.drop_index(op.f("ix_notification_is_read"), table_name="notification")
    op.drop_index(op.f("ix_notification_actor_user_id"), table_name="notification")
    op.drop_table("notification")