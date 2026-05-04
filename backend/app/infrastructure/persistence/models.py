from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

from sqlmodel import Field, SQLModel

from app.core.enums import (
    AccessOverrideEffect,
    BookingStatus,
    OperationTeamType,
    PaymentStatus,
    PriorityLevel,
    TaskStatus,
    TicketStatus,
    UnitStatus,
)


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class TimestampedModel(SQLModel):
    created_at: datetime = Field(default_factory=utc_now, nullable=False)
    updated_at: datetime = Field(default_factory=utc_now, nullable=False)


class Role(TimestampedModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    code: str = Field(index=True, unique=True)
    name: str


class Permission(TimestampedModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    code: str = Field(index=True, unique=True)
    name: str
    module: str
    description: str | None = None


class User(TimestampedModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    full_name: str
    email: str = Field(index=True, unique=True)
    password_hash: str
    is_active: bool = True


class UserRole(SQLModel, table=True):
    user_id: str = Field(foreign_key="user.id", primary_key=True)
    role_id: str = Field(foreign_key="role.id", primary_key=True)
    assigned_at: datetime = Field(default_factory=utc_now, nullable=False)


class RolePermission(SQLModel, table=True):
    role_id: str = Field(foreign_key="role.id", primary_key=True)
    permission_id: str = Field(foreign_key="permission.id", primary_key=True)


class UserPermissionOverride(SQLModel, table=True):
    user_id: str = Field(foreign_key="user.id", primary_key=True)
    permission_id: str = Field(foreign_key="permission.id", primary_key=True)
    effect: AccessOverrideEffect = Field(default=AccessOverrideEffect.allow)


class UserUnitAssignment(SQLModel, table=True):
    user_id: str = Field(foreign_key="user.id", primary_key=True)
    unit_id: str = Field(foreign_key="unit.id", primary_key=True)
    assigned_at: datetime = Field(default_factory=utc_now, nullable=False)


class OperationTeam(TimestampedModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    name: str = Field(index=True, unique=True)
    operation_type: OperationTeamType = Field(index=True)
    description: str | None = None
    is_active: bool = True


class OperationTeamMember(SQLModel, table=True):
    team_id: str = Field(foreign_key="operationteam.id", primary_key=True)
    user_id: str = Field(foreign_key="user.id", primary_key=True)
    assigned_at: datetime = Field(default_factory=utc_now, nullable=False)


class OperationTeamUnitAssignment(SQLModel, table=True):
    team_id: str = Field(foreign_key="operationteam.id", primary_key=True)
    unit_id: str = Field(foreign_key="unit.id", primary_key=True)
    assigned_at: datetime = Field(default_factory=utc_now, nullable=False)


class Unit(TimestampedModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    code: str = Field(index=True, unique=True)
    name: str
    city: str
    country: str = "Saudi Arabia"
    status: UnitStatus = Field(default=UnitStatus.ready)
    nightly_rate: float = 0
    monthly_rate: float = 0
    monthly_depreciation: float = 0
    currency: str = "SAR"
    capacity: int = 1
    bedrooms: int = 1
    bathrooms: int = 1
    smart_lock_code_encrypted: str | None = None
    is_active: bool = True


class UnitAsset(TimestampedModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    unit_id: str = Field(foreign_key="unit.id", index=True)
    name: str
    category: str = "asset"
    acquisition_cost: float
    residual_value: float = 0
    useful_life_months: int = 12
    commissioned_at: datetime = Field(default_factory=utc_now, nullable=False)
    is_active: bool = True
    notes: str | None = None


class UnitImage(TimestampedModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    unit_id: str = Field(foreign_key="unit.id", index=True)
    file_path: str
    original_filename: str | None = None
    content_type: str | None = None
    size_bytes: int | None = None
    is_cover: bool = False
    sort_order: int = 0


class Amenity(TimestampedModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    code: str = Field(index=True, unique=True)
    name: str


class UnitAmenity(SQLModel, table=True):
    unit_id: str = Field(foreign_key="unit.id", primary_key=True)
    amenity_id: str = Field(foreign_key="amenity.id", primary_key=True)


class Client(TimestampedModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    full_name: str
    email: str | None = Field(default=None, index=True)
    phone: str = Field(index=True)
    nationality: str | None = None
    id_type: str | None = None
    id_number: str | None = None
    is_blacklisted: bool = False
    blacklist_reason: str | None = None
    notes: str | None = None


class Booking(TimestampedModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    booking_reference: str = Field(
        default_factory=lambda: f"BKG-{uuid4().hex[:10].upper()}", index=True, unique=True
    )
    unit_id: str = Field(foreign_key="unit.id", index=True)
    client_id: str | None = Field(default=None, foreign_key="client.id", index=True)
    client_name: str
    client_phone: str
    source_channel: str = "direct"
    status: BookingStatus = Field(default=BookingStatus.pending)
    payment_status: PaymentStatus = Field(default=PaymentStatus.unpaid)
    check_in_at: datetime
    check_out_at: datetime
    checked_in_at: datetime | None = None
    checked_out_at: datetime | None = None
    guest_count: int = 1
    base_amount: float = 0
    tax_amount: float = 0
    security_deposit: float = 0
    total_amount: float = 0
    outstanding_amount: float = 0
    created_by: str | None = None


class HousekeepingTask(TimestampedModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    unit_id: str = Field(foreign_key="unit.id", index=True)
    booking_id: str | None = Field(default=None, foreign_key="booking.id", index=True)
    assigned_user_id: str | None = Field(default=None, foreign_key="user.id", index=True)
    assigned_team_id: str | None = Field(default=None, foreign_key="operationteam.id", index=True)
    status: TaskStatus = Field(default=TaskStatus.open)
    priority: PriorityLevel = Field(default=PriorityLevel.normal)
    notes: str | None = None
    completed_at: datetime | None = None


class MaintenanceTicket(TimestampedModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    unit_id: str = Field(foreign_key="unit.id", index=True)
    booking_id: str | None = Field(default=None, foreign_key="booking.id", index=True)
    assigned_user_id: str | None = Field(default=None, foreign_key="user.id", index=True)
    assigned_team_id: str | None = Field(default=None, foreign_key="operationteam.id", index=True)
    title: str
    description: str | None = None
    status: TicketStatus = Field(default=TicketStatus.open)
    priority: PriorityLevel = Field(default=PriorityLevel.normal)
    resolved_at: datetime | None = None


class Payment(TimestampedModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    booking_id: str | None = Field(default=None, foreign_key="booking.id", index=True)
    amount: float
    currency: str = "SAR"
    method: str = "cash"
    status: PaymentStatus = Field(default=PaymentStatus.paid)
    reference_no: str | None = None


class LedgerEntry(TimestampedModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    unit_id: str | None = Field(default=None, foreign_key="unit.id", index=True)
    booking_id: str | None = Field(default=None, foreign_key="booking.id", index=True)
    payment_id: str | None = Field(default=None, foreign_key="payment.id", index=True)
    expense_id: str | None = Field(default=None, foreign_key="expense.id", index=True)
    entry_type: str
    direction: str
    amount: float
    currency: str = "SAR"
    notes: str | None = None


class Expense(TimestampedModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    unit_id: str | None = Field(default=None, foreign_key="unit.id", index=True)
    booking_id: str | None = Field(default=None, foreign_key="booking.id", index=True)
    category: str
    description: str | None = None
    amount: float
    currency: str = "SAR"


class RefreshToken(TimestampedModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="user.id", index=True)
    token_hash: str
    expires_at: datetime
    revoked_at: datetime | None = None


class AuditLog(TimestampedModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    actor_user_id: str | None = Field(default=None, foreign_key="user.id", index=True)
    action: str
    resource_type: str
    resource_id: str
    request_id: str | None = None
    before_data: str | None = None
    after_data: str | None = None


class OutboxEvent(TimestampedModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    aggregate_type: str
    aggregate_id: str
    event_type: str
    payload: str
    available_at: datetime = Field(default_factory=utc_now)
    processed_at: datetime | None = None
    attempts: int = 0
    last_error: str | None = None
