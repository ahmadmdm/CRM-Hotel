from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel

from app.core.enums import PaymentStatus


class PaymentCreate(BaseModel):
    booking_id: str | None = None
    amount: float
    currency: str = "SAR"
    method: str = "cash"
    reference_no: str | None = None


class PaymentRead(BaseModel):
    id: str
    booking_id: str | None = None
    unit_id: str | None = None
    unit_code: str | None = None
    unit_name: str | None = None
    created_at: datetime
    amount: float
    currency: str
    method: str
    status: PaymentStatus
    reference_no: str | None = None


class ExpenseCreate(BaseModel):
    unit_id: str | None = None
    booking_id: str | None = None
    category: str
    description: str | None = None
    amount: float
    currency: str = "SAR"


class ExpenseRead(BaseModel):
    id: str
    unit_id: str | None = None
    unit_code: str | None = None
    unit_name: str | None = None
    booking_id: str | None = None
    created_at: datetime
    category: str
    description: str | None = None
    amount: float
    currency: str


class AssetCreate(BaseModel):
    unit_id: str
    name: str
    category: str = "asset"
    acquisition_cost: float
    residual_value: float = 0
    useful_life_months: int = 12
    commissioned_at: datetime | None = None
    notes: str | None = None


class AssetRead(BaseModel):
    id: str
    unit_id: str
    unit_code: str
    unit_name: str
    name: str
    category: str
    acquisition_cost: float
    residual_value: float
    useful_life_months: int
    commissioned_at: datetime
    monthly_depreciation: float
    period_depreciation: float
    is_active: bool
    notes: str | None = None


class UnitCostCenterRead(BaseModel):
    unit_id: str
    unit_code: str
    unit_name: str
    currency: str
    revenue: float
    expenses: float
    capital_expenditure: float
    depreciation: float
    profit_loss: float
    payment_count: int
    expense_count: int
    asset_count: int
