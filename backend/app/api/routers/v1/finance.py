from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlmodel import Session, select

from app.api.dependencies.auth import CurrentUser, require_permissions
from app.api.dependencies.unit_scope import ensure_unit_in_scope, resolve_unit_scope_ids
from app.core.db import get_session
from app.core.enums import FinancePeriod, PaymentStatus
from app.domain.shared.exceptions import DomainError
from app.infrastructure.persistence.models import Booking, Expense, Payment, Unit, UnitAsset
from app.schemas.finance import (
    AssetCreate,
    AssetRead,
    ExpenseCreate,
    ExpenseRead,
    PaymentCreate,
    PaymentRead,
    UnitCostCenterRead,
)

router = APIRouter()

PERIOD_MONTHS = {
    FinancePeriod.month: 1,
    FinancePeriod.quarter: 3,
    FinancePeriod.year: 12,
}
FINANCE_PERIOD_QUERY = Query(FinancePeriod.month)
FINANCE_ANCHOR_DATE_QUERY = Query(default=None)


def _month_floor(value: date) -> date:
    return date(value.year, value.month, 1)


def _add_months(value: date, months: int) -> date:
    month_index = value.month - 1 + months
    year = value.year + month_index // 12
    month = (month_index % 12) + 1
    return date(year, month, 1)


def _resolve_period_window(
    *,
    period: FinancePeriod,
    anchor_date: date | None,
) -> tuple[datetime, datetime]:
    current_anchor = anchor_date or datetime.now(timezone.utc).date()
    if period == FinancePeriod.month:
        start_date = _month_floor(current_anchor)
    elif period == FinancePeriod.quarter:
        quarter_start_month = ((current_anchor.month - 1) // 3) * 3 + 1
        start_date = date(current_anchor.year, quarter_start_month, 1)
    else:
        start_date = date(current_anchor.year, 1, 1)

    end_date = _add_months(start_date, PERIOD_MONTHS[period])
    return (
        datetime.combine(start_date, datetime.min.time(), tzinfo=timezone.utc),
        datetime.combine(end_date, datetime.min.time(), tzinfo=timezone.utc),
    )


def _period_month_starts(start_date: date, end_date: date) -> list[date]:
    items: list[date] = []
    cursor = start_date
    while cursor < end_date:
        items.append(cursor)
        cursor = _add_months(cursor, 1)
    return items


def _as_utc_datetime(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _asset_monthly_depreciation(asset: UnitAsset) -> float:
    depreciable_base = max(asset.acquisition_cost - asset.residual_value, 0)
    useful_life = max(asset.useful_life_months, 1)
    return round(depreciable_base / useful_life, 2)


def _asset_period_depreciation(
    asset: UnitAsset,
    *,
    start_date: date,
    end_date: date,
) -> float:
    if not asset.is_active:
        return 0
    commissioned_at = _as_utc_datetime(asset.commissioned_at)
    service_start = _month_floor(commissioned_at.date())
    service_end = _add_months(service_start, max(asset.useful_life_months, 1))
    month_count = sum(
        1
        for month_start in _period_month_starts(start_date, end_date)
        if service_start <= month_start < service_end
    )
    return round(_asset_monthly_depreciation(asset) * month_count, 2)


def _serialize_asset(
    asset: UnitAsset,
    *,
    resolved_unit: Unit,
    period_depreciation: float,
) -> AssetRead:
    return AssetRead(
        id=asset.id,
        unit_id=resolved_unit.id,
        unit_code=resolved_unit.code,
        unit_name=resolved_unit.name,
        name=asset.name,
        category=asset.category,
        acquisition_cost=asset.acquisition_cost,
        residual_value=asset.residual_value,
        useful_life_months=asset.useful_life_months,
        commissioned_at=asset.commissioned_at,
        monthly_depreciation=_asset_monthly_depreciation(asset),
        period_depreciation=period_depreciation,
        is_active=asset.is_active,
        notes=asset.notes,
    )


def _resolve_booking_unit_id(session: Session, booking_id: str | None) -> str | None:
    if booking_id is None:
        return None
    booking = session.get(Booking, booking_id)
    return booking.unit_id if booking else None


def _load_booking_unit_map(session: Session) -> dict[str, str]:
    return {
        booking.id: booking.unit_id
        for booking in session.exec(select(Booking).where(Booking.unit_id.is_not(None))).all()
    }


def _load_unit_map(session: Session, unit_scope_ids: list[str]) -> dict[str, Unit]:
    statement = select(Unit).where(Unit.is_active)
    if unit_scope_ids:
        statement = statement.where(Unit.id.in_(unit_scope_ids))
    return {unit.id: unit for unit in session.exec(statement).all()}


def _resolve_finance_unit_id(
    *,
    unit_id: str | None,
    booking_id: str | None,
    booking_unit_map: dict[str, str],
) -> str | None:
    if unit_id:
        return unit_id
    if booking_id:
        return booking_unit_map.get(booking_id)
    return None


def _serialize_payment(
    payment: Payment,
    *,
    resolved_unit: Unit | None,
) -> PaymentRead:
    return PaymentRead(
        id=payment.id,
        booking_id=payment.booking_id,
        unit_id=resolved_unit.id if resolved_unit else None,
        unit_code=resolved_unit.code if resolved_unit else None,
        unit_name=resolved_unit.name if resolved_unit else None,
        created_at=payment.created_at,
        amount=payment.amount,
        currency=payment.currency,
        method=payment.method,
        status=payment.status,
        reference_no=payment.reference_no,
    )


def _serialize_expense(
    expense: Expense,
    *,
    resolved_unit: Unit | None,
) -> ExpenseRead:
    return ExpenseRead(
        id=expense.id,
        unit_id=resolved_unit.id if resolved_unit else expense.unit_id,
        unit_code=resolved_unit.code if resolved_unit else None,
        unit_name=resolved_unit.name if resolved_unit else None,
        booking_id=expense.booking_id,
        created_at=expense.created_at,
        category=expense.category,
        description=expense.description,
        amount=expense.amount,
        currency=expense.currency,
    )


def _payment_revenue_amount(payment: Payment) -> float:
    if payment.status == PaymentStatus.unpaid:
        return 0
    if payment.status == PaymentStatus.refunded:
        return -payment.amount
    return payment.amount


@router.get("/payments", response_model=list[PaymentRead])
def list_payments(
    user: Annotated[CurrentUser, Depends(require_permissions("finance.view"))],
    session: Annotated[Session, Depends(get_session)],
    period: FinancePeriod = FINANCE_PERIOD_QUERY,
    anchor_date: date | None = FINANCE_ANCHOR_DATE_QUERY,
) -> list[PaymentRead]:
    unit_scope_ids = resolve_unit_scope_ids(session, user)
    unit_map = _load_unit_map(session, unit_scope_ids)
    booking_unit_map = _load_booking_unit_map(session)
    period_start, period_end = _resolve_period_window(period=period, anchor_date=anchor_date)
    payments = session.exec(
        select(Payment)
        .where(Payment.created_at >= period_start, Payment.created_at < period_end)
        .order_by(Payment.created_at.desc())
    ).all()
    items: list[PaymentRead] = []
    for payment in payments:
        resolved_unit_id = _resolve_finance_unit_id(
            unit_id=None,
            booking_id=payment.booking_id,
            booking_unit_map=booking_unit_map,
        )
        if unit_scope_ids and resolved_unit_id not in unit_map:
            continue
        items.append(_serialize_payment(payment, resolved_unit=unit_map.get(resolved_unit_id)))
    return items


@router.post("/payments", response_model=PaymentRead)
def create_payment(
    payload: PaymentCreate,
    user: Annotated[CurrentUser, Depends(require_permissions("finance.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> PaymentRead:
    unit_scope_ids = resolve_unit_scope_ids(session, user)
    booking_unit_id = _resolve_booking_unit_id(session, payload.booking_id)
    if payload.booking_id is not None and booking_unit_id is None:
        raise DomainError(
            code="BOOKING_NOT_FOUND",
            message="Booking not found.",
            status_code=404,
        )
    if unit_scope_ids and booking_unit_id is None:
        raise DomainError(
            code="UNIT_SCOPE_REQUIRED",
            message="Scoped finance users must target a booking within their assigned units.",
            status_code=403,
        )
    if booking_unit_id is not None:
        ensure_unit_in_scope(booking_unit_id, unit_scope_ids)
    payment = Payment.model_validate(payload)
    session.add(payment)
    session.commit()
    session.refresh(payment)
    resolved_unit = session.get(Unit, booking_unit_id) if booking_unit_id else None
    return _serialize_payment(payment, resolved_unit=resolved_unit)


@router.get("/expenses", response_model=list[ExpenseRead])
def list_expenses(
    user: Annotated[CurrentUser, Depends(require_permissions("finance.view"))],
    session: Annotated[Session, Depends(get_session)],
    period: FinancePeriod = FINANCE_PERIOD_QUERY,
    anchor_date: date | None = FINANCE_ANCHOR_DATE_QUERY,
) -> list[ExpenseRead]:
    unit_scope_ids = resolve_unit_scope_ids(session, user)
    unit_map = _load_unit_map(session, unit_scope_ids)
    booking_unit_map = _load_booking_unit_map(session)
    period_start, period_end = _resolve_period_window(period=period, anchor_date=anchor_date)
    expenses = session.exec(
        select(Expense)
        .where(Expense.created_at >= period_start, Expense.created_at < period_end)
        .order_by(Expense.created_at.desc())
    ).all()
    items: list[ExpenseRead] = []
    for expense in expenses:
        resolved_unit_id = _resolve_finance_unit_id(
            unit_id=expense.unit_id,
            booking_id=expense.booking_id,
            booking_unit_map=booking_unit_map,
        )
        if unit_scope_ids and resolved_unit_id not in unit_map:
            continue
        items.append(_serialize_expense(expense, resolved_unit=unit_map.get(resolved_unit_id)))
    return items


@router.post("/expenses", response_model=ExpenseRead)
def create_expense(
    payload: ExpenseCreate,
    user: Annotated[CurrentUser, Depends(require_permissions("finance.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> ExpenseRead:
    unit_scope_ids = resolve_unit_scope_ids(session, user)
    booking_unit_id = _resolve_booking_unit_id(session, payload.booking_id)
    if payload.booking_id is not None and booking_unit_id is None:
        raise DomainError(
            code="BOOKING_NOT_FOUND",
            message="Booking not found.",
            status_code=404,
        )
    resolved_unit_id = payload.unit_id or booking_unit_id
    if unit_scope_ids and resolved_unit_id is None:
        raise DomainError(
            code="UNIT_SCOPE_REQUIRED",
            message="Scoped finance users must target a unit or booking within their assignments.",
            status_code=403,
        )
    if resolved_unit_id is not None:
        ensure_unit_in_scope(resolved_unit_id, unit_scope_ids)
    expense = Expense.model_validate(payload, update={"unit_id": resolved_unit_id})
    session.add(expense)
    session.commit()
    session.refresh(expense)
    resolved_unit = session.get(Unit, resolved_unit_id) if resolved_unit_id else None
    return _serialize_expense(expense, resolved_unit=resolved_unit)


@router.get("/assets", response_model=list[AssetRead])
def list_assets(
    user: Annotated[CurrentUser, Depends(require_permissions("finance.view"))],
    session: Annotated[Session, Depends(get_session)],
    period: FinancePeriod = FINANCE_PERIOD_QUERY,
    anchor_date: date | None = FINANCE_ANCHOR_DATE_QUERY,
) -> list[AssetRead]:
    unit_scope_ids = resolve_unit_scope_ids(session, user)
    unit_map = _load_unit_map(session, unit_scope_ids)
    period_start, period_end = _resolve_period_window(period=period, anchor_date=anchor_date)
    period_start_date = period_start.date()
    period_end_date = period_end.date()
    assets = session.exec(
        select(UnitAsset)
        .where(UnitAsset.commissioned_at < period_end)
        .order_by(UnitAsset.commissioned_at.desc())
    ).all()
    items: list[AssetRead] = []
    for asset in assets:
        resolved_unit = unit_map.get(asset.unit_id)
        if resolved_unit is None:
            continue
        commissioned_at = _as_utc_datetime(asset.commissioned_at)
        period_depreciation = _asset_period_depreciation(
            asset,
            start_date=period_start_date,
            end_date=period_end_date,
        )
        if period_depreciation == 0 and not (period_start <= commissioned_at < period_end):
            continue
        items.append(
            _serialize_asset(
                asset,
                resolved_unit=resolved_unit,
                period_depreciation=period_depreciation,
            )
        )
    return items


@router.post("/assets", response_model=AssetRead)
def create_asset(
    payload: AssetCreate,
    user: Annotated[CurrentUser, Depends(require_permissions("finance.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> AssetRead:
    if payload.acquisition_cost <= 0:
        raise DomainError(
            code="ASSET_COST_INVALID",
            message="Asset acquisition cost must be greater than zero.",
            status_code=422,
        )
    if payload.useful_life_months <= 0:
        raise DomainError(
            code="ASSET_USEFUL_LIFE_INVALID",
            message="Asset useful life must be at least one month.",
            status_code=422,
        )
    if payload.residual_value < 0 or payload.residual_value >= payload.acquisition_cost:
        raise DomainError(
            code="ASSET_RESIDUAL_VALUE_INVALID",
            message="Residual value must be zero or less than the acquisition cost.",
            status_code=422,
        )

    unit_scope_ids = resolve_unit_scope_ids(session, user)
    ensure_unit_in_scope(payload.unit_id, unit_scope_ids)
    resolved_unit = session.get(Unit, payload.unit_id)
    if resolved_unit is None:
        raise DomainError(
            code="UNIT_NOT_FOUND",
            message="Unit not found.",
            status_code=404,
        )

    asset = UnitAsset.model_validate(
        payload,
        update={"commissioned_at": payload.commissioned_at or datetime.now(timezone.utc)},
    )
    session.add(asset)
    session.commit()
    session.refresh(asset)
    period_depreciation = _asset_period_depreciation(
        asset,
        start_date=_month_floor(asset.commissioned_at.date()),
        end_date=_add_months(_month_floor(asset.commissioned_at.date()), 1),
    )
    return _serialize_asset(
        asset,
        resolved_unit=resolved_unit,
        period_depreciation=period_depreciation,
    )


@router.get("/cost-centers", response_model=list[UnitCostCenterRead])
def list_cost_centers(
    user: Annotated[CurrentUser, Depends(require_permissions("finance.view"))],
    session: Annotated[Session, Depends(get_session)],
    period: FinancePeriod = FINANCE_PERIOD_QUERY,
    anchor_date: date | None = FINANCE_ANCHOR_DATE_QUERY,
) -> list[UnitCostCenterRead]:
    unit_scope_ids = resolve_unit_scope_ids(session, user)
    unit_map = _load_unit_map(session, unit_scope_ids)
    booking_unit_map = _load_booking_unit_map(session)
    period_start, period_end = _resolve_period_window(period=period, anchor_date=anchor_date)
    period_start_date = period_start.date()
    period_end_date = period_end.date()
    period_month_count = len(_period_month_starts(period_start_date, period_end_date))
    centers = {
        unit.id: {
            "revenue": 0.0,
            "expenses": 0.0,
            "capital_expenditure": 0.0,
            "depreciation": 0.0,
            "payment_count": 0,
            "expense_count": 0,
            "asset_count": 0,
        }
        for unit in unit_map.values()
    }

    payments = session.exec(
        select(Payment).where(Payment.created_at >= period_start, Payment.created_at < period_end)
    ).all()
    for payment in payments:
        resolved_unit_id = _resolve_finance_unit_id(
            unit_id=None,
            booking_id=payment.booking_id,
            booking_unit_map=booking_unit_map,
        )
        if resolved_unit_id not in centers:
            continue
        revenue_amount = _payment_revenue_amount(payment)
        centers[resolved_unit_id]["revenue"] += revenue_amount
        if revenue_amount != 0:
            centers[resolved_unit_id]["payment_count"] += 1

    expenses = session.exec(
        select(Expense).where(Expense.created_at >= period_start, Expense.created_at < period_end)
    ).all()
    for expense in expenses:
        resolved_unit_id = _resolve_finance_unit_id(
            unit_id=expense.unit_id,
            booking_id=expense.booking_id,
            booking_unit_map=booking_unit_map,
        )
        if resolved_unit_id not in centers:
            continue
        centers[resolved_unit_id]["expenses"] += expense.amount
        centers[resolved_unit_id]["expense_count"] += 1

    units_with_asset_schedule: set[str] = set()
    assets = session.exec(
        select(UnitAsset).where(UnitAsset.commissioned_at < period_end)
    ).all()
    for asset in assets:
        if asset.unit_id not in centers:
            continue
        commissioned_at = _as_utc_datetime(asset.commissioned_at)
        units_with_asset_schedule.add(asset.unit_id)
        centers[asset.unit_id]["asset_count"] += 1
        centers[asset.unit_id]["depreciation"] += _asset_period_depreciation(
            asset,
            start_date=period_start_date,
            end_date=period_end_date,
        )
        if period_start <= commissioned_at < period_end:
            centers[asset.unit_id]["capital_expenditure"] += asset.acquisition_cost

    for unit in unit_map.values():
        if unit.id in units_with_asset_schedule:
            continue
        centers[unit.id]["depreciation"] += round(
            unit.monthly_depreciation * period_month_count,
            2,
        )

    return [
        UnitCostCenterRead(
            unit_id=unit.id,
            unit_code=unit.code,
            unit_name=unit.name,
            currency=unit.currency,
            revenue=round(centers[unit.id]["revenue"], 2),
            expenses=round(centers[unit.id]["expenses"], 2),
            capital_expenditure=round(centers[unit.id]["capital_expenditure"], 2),
            depreciation=round(centers[unit.id]["depreciation"], 2),
            profit_loss=(
                round(centers[unit.id]["revenue"], 2)
                - round(centers[unit.id]["expenses"], 2)
                - round(centers[unit.id]["depreciation"], 2)
            ),
            payment_count=centers[unit.id]["payment_count"],
            expense_count=centers[unit.id]["expense_count"],
            asset_count=centers[unit.id]["asset_count"],
        )
        for unit in sorted(unit_map.values(), key=lambda item: item.code)
    ]
