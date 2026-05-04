"""add permissions and per-user access overrides

Revision ID: 20260503_0004
Revises: 20260503_0003
Create Date: 2026-05-03 20:15:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "20260503_0004"
down_revision = "20260503_0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "permission",
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("code", sa.String(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("module", sa.String(), nullable=False),
        sa.Column("description", sa.String(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("code"),
    )
    op.create_index(op.f("ix_permission_code"), "permission", ["code"], unique=False)

    op.create_table(
        "rolepermission",
        sa.Column("role_id", sa.String(), nullable=False),
        sa.Column("permission_id", sa.String(), nullable=False),
        sa.ForeignKeyConstraint(["permission_id"], ["permission.id"]),
        sa.ForeignKeyConstraint(["role_id"], ["role.id"]),
        sa.PrimaryKeyConstraint("role_id", "permission_id"),
    )

    op.create_table(
        "userpermissionoverride",
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("permission_id", sa.String(), nullable=False),
        sa.Column("effect", sa.String(), nullable=False),
        sa.ForeignKeyConstraint(["permission_id"], ["permission.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"]),
        sa.PrimaryKeyConstraint("user_id", "permission_id"),
    )


def downgrade() -> None:
    op.drop_table("userpermissionoverride")
    op.drop_table("rolepermission")
    op.drop_index(op.f("ix_permission_code"), table_name="permission")
    op.drop_table("permission")