"""add user unit assignments

Revision ID: 20260504_0005
Revises: 20260503_0004
Create Date: 2026-05-04 11:30:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "20260504_0005"
down_revision = "20260503_0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "userunitassignment",
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("unit_id", sa.String(), nullable=False),
        sa.Column("assigned_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["unit_id"], ["unit.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"]),
        sa.PrimaryKeyConstraint("user_id", "unit_id"),
    )
    op.create_index(op.f("ix_userunitassignment_unit_id"), "userunitassignment", ["unit_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_userunitassignment_unit_id"), table_name="userunitassignment")
    op.drop_table("userunitassignment")