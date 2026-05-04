from __future__ import annotations

from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends
from sqlmodel import Session, select

from app.api.dependencies.auth import CurrentUser, require_permissions
from app.api.dependencies.pagination import PaginationParams, pagination_params
from app.api.dependencies.unit_scope import (
    apply_unit_scope,
    ensure_unit_in_scope,
    resolve_unit_scope_ids,
)
from app.core.db import get_session
from app.core.enums import BookingStatus, UnitStatus
from app.domain.shared.exceptions import DomainError
from app.infrastructure.persistence.models import Booking, HousekeepingTask, Unit
from app.schemas.bookings import BookingCreate, BookingRead, BookingTransitionResponse
from app.schemas.common import PaginatedResponse

router = APIRouter()


def _ensure_unit_available(
    session: Session, unit_id: str, check_in_at: datetime, check_out_at: datetime
) -> None:
    overlapping = session.exec(
        select(Booking).where(
            Booking.unit_id == unit_id,
            Booking.status.in_(
                [BookingStatus.pending, BookingStatus.confirmed, BookingStatus.checked_in]
            ),
            Booking.check_in_at < check_out_at,
            Booking.check_out_at > check_in_at,
        )
    ).first()
    if overlapping:
        raise DomainError(
            code="BOOKING_OVERLAP",
            message="The unit is not available for the selected period.",
            details={"unit_id": unit_id},
            status_code=409,
        )


@router.get("", response_model=PaginatedResponse[BookingRead])
def list_bookings(
    user: Annotated[CurrentUser, Depends(require_permissions("bookings.view"))],
    pagination: Annotated[PaginationParams, Depends(pagination_params)],
    session: Annotated[Session, Depends(get_session)],
) -> PaginatedResponse[BookingRead]:
    statement = select(Booking).order_by(Booking.check_in_at.desc())
    statement = apply_unit_scope(statement, resolve_unit_scope_ids(session, user), Booking.unit_id)
    total_items = len(session.exec(statement).all())
    offset = (pagination.page - 1) * pagination.page_size
    items = session.exec(statement.offset(offset).limit(pagination.page_size)).all()
    return PaginatedResponse.create(
        items=items, page=pagination.page, page_size=pagination.page_size, total_items=total_items
    )


@router.post("", response_model=BookingRead)
def create_booking(
    payload: BookingCreate,
    user: Annotated[CurrentUser, Depends(require_permissions("bookings.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> BookingRead:
    ensure_unit_in_scope(payload.unit_id, resolve_unit_scope_ids(session, user))
    unit = session.get(Unit, payload.unit_id)
    if not unit:
        raise ValueError("Unit not found")
    _ensure_unit_available(session, payload.unit_id, payload.check_in_at, payload.check_out_at)
    booking = Booking.model_validate(
        payload,
        update={
            "status": BookingStatus.confirmed,
            "created_by": user["id"],
        },
    )
    session.add(booking)
    unit.status = UnitStatus.reserved
    session.add(unit)
    session.commit()
    session.refresh(booking)
    return BookingRead.model_validate(booking)


@router.post("/{booking_id}/check-in", response_model=BookingTransitionResponse)
def check_in_booking(
    booking_id: str,
    user: Annotated[CurrentUser, Depends(require_permissions("bookings.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> BookingTransitionResponse:
    booking = session.get(Booking, booking_id)
    if not booking:
        raise ValueError("Booking not found")
    ensure_unit_in_scope(booking.unit_id, resolve_unit_scope_ids(session, user))
    if booking.status != BookingStatus.confirmed:
        raise DomainError(
            code="INVALID_TRANSITION", message="Only confirmed bookings can be checked in."
        )
    booking.status = BookingStatus.checked_in
    booking.checked_in_at = datetime.now(timezone.utc)
    unit = session.get(Unit, booking.unit_id)
    if unit:
        unit.status = UnitStatus.occupied
        session.add(unit)
    session.add(booking)
    session.commit()
    return BookingTransitionResponse(
        booking_id=booking.id,
        booking_status=booking.status,
        unit_status=unit.status if unit else UnitStatus.occupied,
    )


@router.post("/{booking_id}/check-out", response_model=BookingTransitionResponse)
def check_out_booking(
    booking_id: str,
    user: Annotated[CurrentUser, Depends(require_permissions("bookings.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> BookingTransitionResponse:
    booking = session.get(Booking, booking_id)
    if not booking:
        raise ValueError("Booking not found")
    ensure_unit_in_scope(booking.unit_id, resolve_unit_scope_ids(session, user))
    if booking.status != BookingStatus.checked_in:
        raise DomainError(
            code="INVALID_TRANSITION", message="Only checked-in bookings can be checked out."
        )
    booking.status = BookingStatus.checked_out
    booking.checked_out_at = datetime.now(timezone.utc)
    unit = session.get(Unit, booking.unit_id)
    if unit:
        unit.status = UnitStatus.pending_cleaning
        session.add(unit)
    task = HousekeepingTask(unit_id=booking.unit_id, booking_id=booking.id)
    session.add(booking)
    session.add(task)
    session.commit()
    return BookingTransitionResponse(
        booking_id=booking.id,
        booking_status=booking.status,
        unit_status=unit.status if unit else UnitStatus.pending_cleaning,
    )
