"""add finance assets schedule support

Revision ID: 20260505_0008
Revises: 20260504_0007
Create Date: 2026-05-05 01:10:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260505_0008"
down_revision = "20260504_0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "unitasset",
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("unit_id", sa.String(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("category", sa.String(), nullable=False, server_default="asset"),
        sa.Column("acquisition_cost", sa.Float(), nullable=False),
        sa.Column("residual_value", sa.Float(), nullable=False, server_default="0"),
        sa.Column("useful_life_months", sa.Integer(), nullable=False, server_default="12"),
        sa.Column("commissioned_at", sa.DateTime(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("notes", sa.String(), nullable=True),
        sa.ForeignKeyConstraint(["unit_id"], ["unit.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_unitasset_unit_id"), "unitasset", ["unit_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_unitasset_unit_id"), table_name="unitasset")
    op.drop_table("unitasset")