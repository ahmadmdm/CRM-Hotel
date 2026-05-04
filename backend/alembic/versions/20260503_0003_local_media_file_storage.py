"""rename unit image storage fields for local media files

Revision ID: 20260503_0003
Revises: 20260503_0002
Create Date: 2026-05-03 06:30:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "20260503_0003"
down_revision = "20260503_0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("unitimage", schema=None) as batch_op:
        batch_op.alter_column(
            "s3_key", new_column_name="file_path", existing_type=sa.String(), nullable=False
        )
        batch_op.add_column(sa.Column("original_filename", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("content_type", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("size_bytes", sa.Integer(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("unitimage", schema=None) as batch_op:
        batch_op.drop_column("size_bytes")
        batch_op.drop_column("content_type")
        batch_op.drop_column("original_filename")
        batch_op.alter_column(
            "file_path", new_column_name="s3_key", existing_type=sa.String(), nullable=False
        )
