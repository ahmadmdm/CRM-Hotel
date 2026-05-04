"""initial schema

Revision ID: 20260502_0001
Revises:
Create Date: 2026-05-02 00:00:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "20260502_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "unit",
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("code", sa.String(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("city", sa.String(), nullable=False),
        sa.Column("country", sa.String(), nullable=False),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("nightly_rate", sa.Float(), nullable=False),
        sa.Column("monthly_rate", sa.Float(), nullable=False),
        sa.Column("currency", sa.String(), nullable=False),
        sa.Column("capacity", sa.Integer(), nullable=False),
        sa.Column("bedrooms", sa.Integer(), nullable=False),
        sa.Column("bathrooms", sa.Integer(), nullable=False),
        sa.Column("smart_lock_code_encrypted", sa.String(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("code"),
    )
    op.create_index(op.f("ix_unit_code"), "unit", ["code"], unique=False)

    op.create_table(
        "booking",
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("booking_reference", sa.String(), nullable=False),
        sa.Column("unit_id", sa.String(), nullable=False),
        sa.Column("client_name", sa.String(), nullable=False),
        sa.Column("client_phone", sa.String(), nullable=False),
        sa.Column("source_channel", sa.String(), nullable=False),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("payment_status", sa.String(), nullable=False),
        sa.Column("check_in_at", sa.DateTime(), nullable=False),
        sa.Column("check_out_at", sa.DateTime(), nullable=False),
        sa.Column("checked_in_at", sa.DateTime(), nullable=True),
        sa.Column("checked_out_at", sa.DateTime(), nullable=True),
        sa.Column("guest_count", sa.Integer(), nullable=False),
        sa.Column("base_amount", sa.Float(), nullable=False),
        sa.Column("tax_amount", sa.Float(), nullable=False),
        sa.Column("security_deposit", sa.Float(), nullable=False),
        sa.Column("total_amount", sa.Float(), nullable=False),
        sa.Column("outstanding_amount", sa.Float(), nullable=False),
        sa.Column("created_by", sa.String(), nullable=True),
        sa.ForeignKeyConstraint(["unit_id"], ["unit.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("booking_reference"),
    )
    op.create_index(
        op.f("ix_booking_booking_reference"), "booking", ["booking_reference"], unique=False
    )
    op.create_index(op.f("ix_booking_unit_id"), "booking", ["unit_id"], unique=False)

    op.create_table(
        "housekeepingtask",
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("unit_id", sa.String(), nullable=False),
        sa.Column("booking_id", sa.String(), nullable=True),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("priority", sa.String(), nullable=False),
        sa.Column("notes", sa.String(), nullable=True),
        sa.Column("completed_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["booking_id"], ["booking.id"]),
        sa.ForeignKeyConstraint(["unit_id"], ["unit.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_housekeepingtask_booking_id"), "housekeepingtask", ["booking_id"], unique=False
    )
    op.create_index(
        op.f("ix_housekeepingtask_unit_id"), "housekeepingtask", ["unit_id"], unique=False
    )

    op.create_table(
        "maintenanceticket",
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("unit_id", sa.String(), nullable=False),
        sa.Column("booking_id", sa.String(), nullable=True),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("description", sa.String(), nullable=True),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("priority", sa.String(), nullable=False),
        sa.Column("resolved_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["booking_id"], ["booking.id"]),
        sa.ForeignKeyConstraint(["unit_id"], ["unit.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_maintenanceticket_booking_id"), "maintenanceticket", ["booking_id"], unique=False
    )
    op.create_index(
        op.f("ix_maintenanceticket_unit_id"), "maintenanceticket", ["unit_id"], unique=False
    )

    op.create_table(
        "payment",
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("booking_id", sa.String(), nullable=True),
        sa.Column("amount", sa.Float(), nullable=False),
        sa.Column("currency", sa.String(), nullable=False),
        sa.Column("method", sa.String(), nullable=False),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("reference_no", sa.String(), nullable=True),
        sa.ForeignKeyConstraint(["booking_id"], ["booking.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_payment_booking_id"), "payment", ["booking_id"], unique=False)

    op.create_table(
        "expense",
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("unit_id", sa.String(), nullable=True),
        sa.Column("booking_id", sa.String(), nullable=True),
        sa.Column("category", sa.String(), nullable=False),
        sa.Column("description", sa.String(), nullable=True),
        sa.Column("amount", sa.Float(), nullable=False),
        sa.Column("currency", sa.String(), nullable=False),
        sa.ForeignKeyConstraint(["booking_id"], ["booking.id"]),
        sa.ForeignKeyConstraint(["unit_id"], ["unit.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_expense_booking_id"), "expense", ["booking_id"], unique=False)
    op.create_index(op.f("ix_expense_unit_id"), "expense", ["unit_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_expense_unit_id"), table_name="expense")
    op.drop_index(op.f("ix_expense_booking_id"), table_name="expense")
    op.drop_table("expense")
    op.drop_index(op.f("ix_payment_booking_id"), table_name="payment")
    op.drop_table("payment")
    op.drop_index(op.f("ix_maintenanceticket_unit_id"), table_name="maintenanceticket")
    op.drop_index(op.f("ix_maintenanceticket_booking_id"), table_name="maintenanceticket")
    op.drop_table("maintenanceticket")
    op.drop_index(op.f("ix_housekeepingtask_unit_id"), table_name="housekeepingtask")
    op.drop_index(op.f("ix_housekeepingtask_booking_id"), table_name="housekeepingtask")
    op.drop_table("housekeepingtask")
    op.drop_index(op.f("ix_booking_unit_id"), table_name="booking")
    op.drop_index(op.f("ix_booking_booking_reference"), table_name="booking")
    op.drop_table("booking")
    op.drop_index(op.f("ix_unit_code"), table_name="unit")
    op.drop_table("unit")
