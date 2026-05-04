"""expand core schema to current models

Revision ID: 20260503_0002
Revises: 20260502_0001
Create Date: 2026-05-03 00:00:00.000000
"""

from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "20260503_0002"
down_revision = "20260502_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "role",
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("code", sa.String(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("code"),
    )
    op.create_index(op.f("ix_role_code"), "role", ["code"], unique=False)

    op.create_table(
        "user",
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("full_name", sa.String(), nullable=False),
        sa.Column("email", sa.String(), nullable=False),
        sa.Column("password_hash", sa.String(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("email"),
    )
    op.create_index(op.f("ix_user_email"), "user", ["email"], unique=False)

    op.create_table(
        "client",
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("full_name", sa.String(), nullable=False),
        sa.Column("email", sa.String(), nullable=True),
        sa.Column("phone", sa.String(), nullable=False),
        sa.Column("nationality", sa.String(), nullable=True),
        sa.Column("id_type", sa.String(), nullable=True),
        sa.Column("id_number", sa.String(), nullable=True),
        sa.Column("is_blacklisted", sa.Boolean(), nullable=False),
        sa.Column("blacklist_reason", sa.String(), nullable=True),
        sa.Column("notes", sa.String(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_client_email"), "client", ["email"], unique=False)
    op.create_index(op.f("ix_client_phone"), "client", ["phone"], unique=False)

    op.create_table(
        "amenity",
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("code", sa.String(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("code"),
    )
    op.create_index(op.f("ix_amenity_code"), "amenity", ["code"], unique=False)

    op.create_table(
        "userrole",
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("role_id", sa.String(), nullable=False),
        sa.Column("assigned_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["role_id"], ["role.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"]),
        sa.PrimaryKeyConstraint("user_id", "role_id"),
    )

    op.create_table(
        "unitimage",
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("unit_id", sa.String(), nullable=False),
        sa.Column("s3_key", sa.String(), nullable=False),
        sa.Column("is_cover", sa.Boolean(), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["unit_id"], ["unit.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_unitimage_unit_id"), "unitimage", ["unit_id"], unique=False)

    op.create_table(
        "unitamenity",
        sa.Column("unit_id", sa.String(), nullable=False),
        sa.Column("amenity_id", sa.String(), nullable=False),
        sa.ForeignKeyConstraint(["amenity_id"], ["amenity.id"]),
        sa.ForeignKeyConstraint(["unit_id"], ["unit.id"]),
        sa.PrimaryKeyConstraint("unit_id", "amenity_id"),
    )

    op.create_table(
        "refreshtoken",
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("token_hash", sa.String(), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("revoked_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_refreshtoken_user_id"), "refreshtoken", ["user_id"], unique=False)

    op.create_table(
        "auditlog",
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("actor_user_id", sa.String(), nullable=True),
        sa.Column("action", sa.String(), nullable=False),
        sa.Column("resource_type", sa.String(), nullable=False),
        sa.Column("resource_id", sa.String(), nullable=False),
        sa.Column("request_id", sa.String(), nullable=True),
        sa.Column("before_data", sa.String(), nullable=True),
        sa.Column("after_data", sa.String(), nullable=True),
        sa.ForeignKeyConstraint(["actor_user_id"], ["user.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_auditlog_actor_user_id"), "auditlog", ["actor_user_id"], unique=False)

    op.create_table(
        "outboxevent",
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("aggregate_type", sa.String(), nullable=False),
        sa.Column("aggregate_id", sa.String(), nullable=False),
        sa.Column("event_type", sa.String(), nullable=False),
        sa.Column("payload", sa.String(), nullable=False),
        sa.Column("available_at", sa.DateTime(), nullable=False),
        sa.Column("processed_at", sa.DateTime(), nullable=True),
        sa.Column("attempts", sa.Integer(), nullable=False),
        sa.Column("last_error", sa.String(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "ledgerentry",
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("unit_id", sa.String(), nullable=True),
        sa.Column("booking_id", sa.String(), nullable=True),
        sa.Column("payment_id", sa.String(), nullable=True),
        sa.Column("expense_id", sa.String(), nullable=True),
        sa.Column("entry_type", sa.String(), nullable=False),
        sa.Column("direction", sa.String(), nullable=False),
        sa.Column("amount", sa.Float(), nullable=False),
        sa.Column("currency", sa.String(), nullable=False),
        sa.Column("notes", sa.String(), nullable=True),
        sa.ForeignKeyConstraint(["booking_id"], ["booking.id"]),
        sa.ForeignKeyConstraint(["expense_id"], ["expense.id"]),
        sa.ForeignKeyConstraint(["payment_id"], ["payment.id"]),
        sa.ForeignKeyConstraint(["unit_id"], ["unit.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_ledgerentry_booking_id"), "ledgerentry", ["booking_id"], unique=False)
    op.create_index(op.f("ix_ledgerentry_expense_id"), "ledgerentry", ["expense_id"], unique=False)
    op.create_index(op.f("ix_ledgerentry_payment_id"), "ledgerentry", ["payment_id"], unique=False)
    op.create_index(op.f("ix_ledgerentry_unit_id"), "ledgerentry", ["unit_id"], unique=False)

    with op.batch_alter_table("booking", schema=None) as batch_op:
        batch_op.add_column(sa.Column("client_id", sa.String(), nullable=True))
        batch_op.create_index(batch_op.f("ix_booking_client_id"), ["client_id"], unique=False)
        batch_op.create_foreign_key("fk_booking_client_id_client", "client", ["client_id"], ["id"])


def downgrade() -> None:
    with op.batch_alter_table("booking", schema=None) as batch_op:
        batch_op.drop_constraint("fk_booking_client_id_client", type_="foreignkey")
        batch_op.drop_index(batch_op.f("ix_booking_client_id"))
        batch_op.drop_column("client_id")

    op.drop_index(op.f("ix_ledgerentry_unit_id"), table_name="ledgerentry")
    op.drop_index(op.f("ix_ledgerentry_payment_id"), table_name="ledgerentry")
    op.drop_index(op.f("ix_ledgerentry_expense_id"), table_name="ledgerentry")
    op.drop_index(op.f("ix_ledgerentry_booking_id"), table_name="ledgerentry")
    op.drop_table("ledgerentry")

    op.drop_table("outboxevent")

    op.drop_index(op.f("ix_auditlog_actor_user_id"), table_name="auditlog")
    op.drop_table("auditlog")

    op.drop_index(op.f("ix_refreshtoken_user_id"), table_name="refreshtoken")
    op.drop_table("refreshtoken")

    op.drop_table("unitamenity")

    op.drop_index(op.f("ix_unitimage_unit_id"), table_name="unitimage")
    op.drop_table("unitimage")

    op.drop_table("userrole")

    op.drop_index(op.f("ix_amenity_code"), table_name="amenity")
    op.drop_table("amenity")

    op.drop_index(op.f("ix_client_phone"), table_name="client")
    op.drop_index(op.f("ix_client_email"), table_name="client")
    op.drop_table("client")

    op.drop_index(op.f("ix_user_email"), table_name="user")
    op.drop_table("user")

    op.drop_index(op.f("ix_role_code"), table_name="role")
    op.drop_table("role")
