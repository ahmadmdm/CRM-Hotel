from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends
from sqlmodel import Session, select

from app.api.dependencies.auth import CurrentUser, require_permissions
from app.api.dependencies.unit_scope import resolve_unit_scope_ids
from app.core.db import get_session
from app.core.enums import TaskStatus, TicketStatus, UnitStatus
from app.infrastructure.persistence.models import (
    Booking,
    Expense,
    HousekeepingTask,
    MaintenanceTicket,
    Payment,
    Unit,
)
from app.schemas.reports import DashboardKpis

router = APIRouter()


def _build_dashboard_kpis(session: Session, unit_scope_ids: list[str]) -> DashboardKpis:
    unit_statement = select(Unit)
    if unit_scope_ids:
        unit_statement = unit_statement.where(Unit.id.in_(unit_scope_ids))

    total_units = len(session.exec(unit_statement).all())
    occupied_units = len(
        session.exec(unit_statement.where(Unit.status == UnitStatus.occupied)).all()
    )
    pending_cleaning = len(
        session.exec(
            select(HousekeepingTask).where(HousekeepingTask.status != TaskStatus.completed)
            if not unit_scope_ids
            else select(HousekeepingTask).where(
                HousekeepingTask.status != TaskStatus.completed,
                HousekeepingTask.unit_id.in_(unit_scope_ids),
            )
        ).all()
    )
    open_tickets = len(
        session.exec(
            select(MaintenanceTicket).where(
                MaintenanceTicket.status.in_([TicketStatus.open, TicketStatus.in_progress])
            )
            if not unit_scope_ids
            else select(MaintenanceTicket).where(
                MaintenanceTicket.status.in_([TicketStatus.open, TicketStatus.in_progress]),
                MaintenanceTicket.unit_id.in_(unit_scope_ids),
            )
        ).all()
    )
    payment_statement = select(Payment)
    if unit_scope_ids:
        payment_statement = payment_statement.join(Booking).where(
            Booking.unit_id.in_(unit_scope_ids)
        )
    total_revenue = sum(payment.amount for payment in session.exec(payment_statement).all())

    expense_statement = select(Expense)
    if unit_scope_ids:
        expense_statement = expense_statement.where(Expense.unit_id.in_(unit_scope_ids))
    total_expenses = sum(expense.amount for expense in session.exec(expense_statement).all())

    booking_statement = select(Booking)
    if unit_scope_ids:
        booking_statement = booking_statement.where(Booking.unit_id.in_(unit_scope_ids))
    active_bookings = len(session.exec(booking_statement).all())
    occupancy_rate = round((occupied_units / total_units) * 100, 2) if total_units else 0
    return DashboardKpis(
        total_units=total_units,
        occupied_units=occupied_units,
        active_bookings=active_bookings,
        pending_cleaning=pending_cleaning,
        open_tickets=open_tickets,
        total_revenue=total_revenue,
        total_expenses=total_expenses,
        occupancy_rate=occupancy_rate,
    )


@router.get("/dashboard", response_model=DashboardKpis)
def dashboard_kpis(
    user: Annotated[CurrentUser, Depends(require_permissions("dashboard.view"))],
    session: Annotated[Session, Depends(get_session)],
) -> DashboardKpis:
    return _build_dashboard_kpis(session, resolve_unit_scope_ids(session, user))


@router.get("/summary", response_model=DashboardKpis)
def reports_summary(
    user: Annotated[CurrentUser, Depends(require_permissions("reports.view"))],
    session: Annotated[Session, Depends(get_session)],
) -> DashboardKpis:
    return _build_dashboard_kpis(session, resolve_unit_scope_ids(session, user))
