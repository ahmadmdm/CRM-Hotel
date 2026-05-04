from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, field_validator

from app.core.enums import BookingStatus, PaymentStatus, UnitStatus


class BookingCreate(BaseModel):
    unit_id: str
    client_name: str
    client_phone: str
    source_channel: str = "direct"
    check_in_at: datetime
    check_out_at: datetime
    guest_count: int = 1
    base_amount: float = 0
    tax_amount: float = 0
    security_deposit: float = 0
    total_amount: float = 0
    outstanding_amount: float = 0

    @field_validator("check_out_at")
    @classmethod
    def validate_dates(cls, value: datetime, info):
        check_in_at = info.data.get("check_in_at")
        if check_in_at and value <= check_in_at:
            raise ValueError("check_out_at must be greater than check_in_at")
        return value


class BookingRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    booking_reference: str
    unit_id: str
    client_name: str
    client_phone: str
    source_channel: str
    status: BookingStatus
    payment_status: PaymentStatus
    check_in_at: datetime
    check_out_at: datetime
    guest_count: int
    base_amount: float
    tax_amount: float
    security_deposit: float
    total_amount: float
    outstanding_amount: float


class BookingTransitionResponse(BaseModel):
    booking_id: str
    booking_status: BookingStatus
    unit_status: UnitStatus
