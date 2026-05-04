"""add operation assignee columns

Revision ID: 20260504_0006
Revises: 20260504_0005
Create Date: 2026-05-04 23:25:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "20260504_0006"
down_revision = "20260504_0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("housekeepingtask") as batch_op:
        batch_op.add_column(sa.Column("assigned_user_id", sa.String(), nullable=True))
        batch_op.create_foreign_key(
            "fk_housekeepingtask_assigned_user_id_user",
            "user",
            ["assigned_user_id"],
            ["id"],
        )
        batch_op.create_index(
            op.f("ix_housekeepingtask_assigned_user_id"),
            ["assigned_user_id"],
            unique=False,
        )

    with op.batch_alter_table("maintenanceticket") as batch_op:
        batch_op.add_column(sa.Column("assigned_user_id", sa.String(), nullable=True))
        batch_op.create_foreign_key(
            "fk_maintenanceticket_assigned_user_id_user",
            "user",
            ["assigned_user_id"],
            ["id"],
        )
        batch_op.create_index(
            op.f("ix_maintenanceticket_assigned_user_id"),
            ["assigned_user_id"],
            unique=False,
        )


def downgrade() -> None:
    with op.batch_alter_table("maintenanceticket") as batch_op:
        batch_op.drop_index(op.f("ix_maintenanceticket_assigned_user_id"))
        batch_op.drop_constraint(
            "fk_maintenanceticket_assigned_user_id_user",
            type_="foreignkey",
        )
        batch_op.drop_column("assigned_user_id")

    with op.batch_alter_table("housekeepingtask") as batch_op:
        batch_op.drop_index(op.f("ix_housekeepingtask_assigned_user_id"))
        batch_op.drop_constraint(
            "fk_housekeepingtask_assigned_user_id_user",
            type_="foreignkey",
        )
        batch_op.drop_column("assigned_user_id")