"""add operation teams and cost center depreciation

Revision ID: 20260504_0007
Revises: 20260504_0006
Create Date: 2026-05-04 23:40:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260504_0007"
down_revision = "20260504_0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "operationteam",
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("operation_type", sa.String(), nullable=False),
        sa.Column("description", sa.String(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_operationteam_name"), "operationteam", ["name"], unique=True)
    op.create_index(
        op.f("ix_operationteam_operation_type"),
        "operationteam",
        ["operation_type"],
        unique=False,
    )
    op.create_table(
        "operationteammember",
        sa.Column("team_id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("assigned_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["team_id"], ["operationteam.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"]),
        sa.PrimaryKeyConstraint("team_id", "user_id"),
    )
    op.create_table(
        "operationteamunitassignment",
        sa.Column("team_id", sa.String(), nullable=False),
        sa.Column("unit_id", sa.String(), nullable=False),
        sa.Column("assigned_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["team_id"], ["operationteam.id"]),
        sa.ForeignKeyConstraint(["unit_id"], ["unit.id"]),
        sa.PrimaryKeyConstraint("team_id", "unit_id"),
    )

    with op.batch_alter_table("unit") as batch_op:
        batch_op.add_column(
            sa.Column("monthly_depreciation", sa.Float(), nullable=False, server_default="0")
        )

    with op.batch_alter_table("housekeepingtask") as batch_op:
        batch_op.add_column(sa.Column("assigned_team_id", sa.String(), nullable=True))
        batch_op.create_foreign_key(
            "fk_housekeepingtask_assigned_team_id_operationteam",
            "operationteam",
            ["assigned_team_id"],
            ["id"],
        )
        batch_op.create_index(
            op.f("ix_housekeepingtask_assigned_team_id"),
            ["assigned_team_id"],
            unique=False,
        )

    with op.batch_alter_table("maintenanceticket") as batch_op:
        batch_op.add_column(sa.Column("assigned_team_id", sa.String(), nullable=True))
        batch_op.create_foreign_key(
            "fk_maintenanceticket_assigned_team_id_operationteam",
            "operationteam",
            ["assigned_team_id"],
            ["id"],
        )
        batch_op.create_index(
            op.f("ix_maintenanceticket_assigned_team_id"),
            ["assigned_team_id"],
            unique=False,
        )


def downgrade() -> None:
    with op.batch_alter_table("maintenanceticket") as batch_op:
        batch_op.drop_index(op.f("ix_maintenanceticket_assigned_team_id"))
        batch_op.drop_constraint(
            "fk_maintenanceticket_assigned_team_id_operationteam",
            type_="foreignkey",
        )
        batch_op.drop_column("assigned_team_id")

    with op.batch_alter_table("housekeepingtask") as batch_op:
        batch_op.drop_index(op.f("ix_housekeepingtask_assigned_team_id"))
        batch_op.drop_constraint(
            "fk_housekeepingtask_assigned_team_id_operationteam",
            type_="foreignkey",
        )
        batch_op.drop_column("assigned_team_id")

    with op.batch_alter_table("unit") as batch_op:
        batch_op.drop_column("monthly_depreciation")

    op.drop_table("operationteamunitassignment")
    op.drop_table("operationteammember")
    op.drop_index(op.f("ix_operationteam_operation_type"), table_name="operationteam")
    op.drop_index(op.f("ix_operationteam_name"), table_name="operationteam")
    op.drop_table("operationteam")