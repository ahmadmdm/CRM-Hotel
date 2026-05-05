from __future__ import annotations

from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy import and_, or_
from sqlmodel import Session, select

from app.api.dependencies.auth import CurrentUser, require_permissions
from app.api.dependencies.unit_scope import (
    apply_unit_scope,
    ensure_unit_in_scope,
    resolve_unit_scope_ids,
)
from app.core.access_control import (
    get_access_profile_for_user,
    get_effective_unit_scope_ids_for_user,
    get_operation_team_ids_for_user,
)
from app.core.db import get_session
from app.core.enums import NotificationKind, OperationTeamType, TicketStatus, UnitStatus
from app.core.notifications import (
    assignment_recipient_user_ids,
    create_notifications,
    user_ids_with_permissions,
)
from app.domain.shared.exceptions import DomainError
from app.infrastructure.persistence.models import (
    MaintenanceTicket,
    OperationTeam,
    OperationTeamMember,
    OperationTeamUnitAssignment,
    Unit,
    User,
)
from app.schemas.operations import (
    AssignableUserRead,
    MaintenanceTicketCreate,
    MaintenanceTicketRead,
    OperationAssignmentUpdate,
)

router = APIRouter()

MAINTENANCE_ASSIGNEE_PERMISSIONS = frozenset({"maintenance.view", "maintenance.manage"})


def _notify_maintenance_event(
    session: Session,
    *,
    actor_user_id: str,
    ticket: MaintenanceTicket,
    title: str,
    body: str,
) -> None:
    manager_ids = set(
        user_ids_with_permissions(session, {"notifications.manage"}, exclude_user_ids={actor_user_id})
    )
    assignment_ids = set(
        assignment_recipient_user_ids(
            session,
            assigned_user_id=ticket.assigned_user_id,
            assigned_team_id=ticket.assigned_team_id,
        )
    )
    assignment_ids.discard(actor_user_id)
    create_notifications(
        session,
        recipient_user_ids=manager_ids | assignment_ids,
        actor_user_id=actor_user_id,
        kind=NotificationKind.maintenance,
        title=title,
        body=body,
        resource_type="maintenance_ticket",
        resource_id=ticket.id,
    )


def _actor_can_manage_assignments(user: CurrentUser) -> bool:
    return "users.manage_access" in user.permissions


def _resolve_assignable_users(
    session: Session,
    *,
    unit_id: str | None = None,
) -> list[AssignableUserRead]:
    results: list[AssignableUserRead] = []
    teams = session.exec(
        select(OperationTeam)
        .where(
            OperationTeam.is_active,
            OperationTeam.operation_type == OperationTeamType.maintenance,
        )
        .order_by(OperationTeam.name)
    ).all()
    for team in teams:
        team_unit_ids = session.exec(
            select(OperationTeamUnitAssignment.unit_id)
            .where(OperationTeamUnitAssignment.team_id == team.id)
            .order_by(OperationTeamUnitAssignment.unit_id)
        ).all()
        if unit_id and unit_id not in team_unit_ids:
            continue
        eligible_member_ids: list[str] = []
        member_ids = session.exec(
            select(OperationTeamMember.user_id).where(OperationTeamMember.team_id == team.id)
        ).all()
        for member_id in member_ids:
            access_profile = get_access_profile_for_user(session, member_id)
            effective_permissions = set(access_profile.effective_permission_codes)
            if not MAINTENANCE_ASSIGNEE_PERMISSIONS.issubset(effective_permissions):
                continue
            effective_unit_ids = get_effective_unit_scope_ids_for_user(session, member_id)
            if unit_id and effective_unit_ids and unit_id not in effective_unit_ids:
                continue
            eligible_member_ids.append(member_id)
        if not eligible_member_ids:
            continue
        results.append(
            AssignableUserRead(
                target_type="team",
                id=team.id,
                name=team.name,
                description=team.description,
                assigned_unit_ids=list(team_unit_ids),
                member_user_ids=eligible_member_ids,
            )
        )
    candidates = session.exec(select(User).where(User.is_active).order_by(User.full_name)).all()
    for candidate in candidates:
        access_profile = get_access_profile_for_user(session, candidate.id)
        effective_permissions = set(access_profile.effective_permission_codes)
        if not MAINTENANCE_ASSIGNEE_PERMISSIONS.issubset(effective_permissions):
            continue
        assigned_unit_ids = get_effective_unit_scope_ids_for_user(session, candidate.id)
        if unit_id and assigned_unit_ids and unit_id not in assigned_unit_ids:
            continue
        results.append(
            AssignableUserRead(
                target_type="user",
                id=candidate.id,
                name=candidate.full_name,
                email=candidate.email,
                assigned_unit_ids=assigned_unit_ids,
            )
        )
    return results


def _resolve_assignment(
    session: Session,
    *,
    unit_id: str,
    assigned_user_id: str | None,
    assigned_team_id: str | None,
) -> tuple[str | None, str | None]:
    if assigned_user_id and assigned_team_id:
        raise DomainError(
            code="MULTIPLE_ASSIGNEES_NOT_ALLOWED",
            message="Choose either a user or a team for assignment, not both.",
            status_code=422,
        )
    if not assigned_user_id and not assigned_team_id:
        return None, None
    assignable_targets = {
        (target.target_type, target.id): target
        for target in _resolve_assignable_users(session, unit_id=unit_id)
    }
    if assigned_user_id and ("user", assigned_user_id) not in assignable_targets:
        raise DomainError(
            code="ASSIGNEE_NOT_ELIGIBLE",
            message="The selected assignee is not eligible for this maintenance ticket.",
            status_code=422,
        )
    if assigned_team_id and ("team", assigned_team_id) not in assignable_targets:
        raise DomainError(
            code="ASSIGNEE_NOT_ELIGIBLE",
            message="The selected team is not eligible for this maintenance ticket.",
            status_code=422,
        )
    return assigned_user_id, assigned_team_id


def _apply_assignee_scope(statement, *, session: Session, user: CurrentUser):
    if _actor_can_manage_assignments(user):
        return statement
    team_ids = get_operation_team_ids_for_user(
        session,
        user["id"],
        operation_type=OperationTeamType.maintenance,
    )
    conditions = [
        and_(
            MaintenanceTicket.assigned_user_id.is_(None),
            MaintenanceTicket.assigned_team_id.is_(None),
        ),
        MaintenanceTicket.assigned_user_id == user["id"],
    ]
    if team_ids:
        conditions.append(MaintenanceTicket.assigned_team_id.in_(team_ids))
    return statement.where(or_(*conditions))


def _serialize_ticket(session: Session, ticket: MaintenanceTicket) -> MaintenanceTicketRead:
    unit = session.get(Unit, ticket.unit_id)
    assignee = session.get(User, ticket.assigned_user_id) if ticket.assigned_user_id else None
    team = session.get(OperationTeam, ticket.assigned_team_id) if ticket.assigned_team_id else None
    return MaintenanceTicketRead(
        id=ticket.id,
        unit_id=ticket.unit_id,
        unit_code=unit.code if unit else None,
        unit_name=unit.name if unit else None,
        booking_id=ticket.booking_id,
        assigned_user_id=ticket.assigned_user_id,
        assigned_user_name=assignee.full_name if assignee else None,
        assigned_user_email=assignee.email if assignee else None,
        assigned_team_id=ticket.assigned_team_id,
        assigned_team_name=team.name if team else None,
        title=ticket.title,
        description=ticket.description,
        status=ticket.status,
        priority=ticket.priority,
        resolved_at=ticket.resolved_at,
    )


@router.get("/assignees", response_model=list[AssignableUserRead])
def list_assignable_users(
    _: Annotated[CurrentUser, Depends(require_permissions("maintenance.manage"))],
    session: Annotated[Session, Depends(get_session)],
    unit_id: str | None = None,
) -> list[AssignableUserRead]:
    return _resolve_assignable_users(session, unit_id=unit_id)


@router.get("/tickets", response_model=list[MaintenanceTicketRead])
def list_tickets(
    user: Annotated[
        CurrentUser,
        Depends(require_permissions("maintenance.view", "maintenance.manage")),
    ],
    session: Annotated[Session, Depends(get_session)],
) -> list[MaintenanceTicketRead]:
    unit_scope_ids = resolve_unit_scope_ids(session, user)
    statement = select(MaintenanceTicket).order_by(MaintenanceTicket.created_at.desc())
    statement = apply_unit_scope(statement, unit_scope_ids, MaintenanceTicket.unit_id)
    statement = _apply_assignee_scope(statement, session=session, user=user)
    tickets = session.exec(statement).all()
    return [_serialize_ticket(session, ticket) for ticket in tickets]


@router.post("/tickets", response_model=MaintenanceTicketRead)
def create_ticket(
    payload: MaintenanceTicketCreate,
    user: Annotated[CurrentUser, Depends(require_permissions("maintenance.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> MaintenanceTicketRead:
    ensure_unit_in_scope(payload.unit_id, resolve_unit_scope_ids(session, user))
    unit = session.get(Unit, payload.unit_id)
    if not unit:
        raise DomainError(code="UNIT_NOT_FOUND", message="Unit not found.", status_code=404)
    assigned_user_id, assigned_team_id = _resolve_assignment(
        session,
        unit_id=payload.unit_id,
        assigned_user_id=payload.assigned_user_id,
        assigned_team_id=payload.assigned_team_id,
    )
    ticket = MaintenanceTicket.model_validate(
        payload.model_dump(exclude={"assigned_user_id", "assigned_team_id"}),
        update={
            "assigned_user_id": assigned_user_id,
            "assigned_team_id": assigned_team_id,
        },
    )
    session.add(ticket)
    if unit:
        unit.status = UnitStatus.maintenance
        session.add(unit)
    _notify_maintenance_event(
        session,
        actor_user_id=user["id"],
        ticket=ticket,
        title="Maintenance ticket created",
        body=f"A maintenance ticket was created for unit {unit.code if unit else payload.unit_id}.",
    )
    session.commit()
    session.refresh(ticket)
    return _serialize_ticket(session, ticket)


@router.patch("/tickets/{ticket_id}/assignee", response_model=MaintenanceTicketRead)
def assign_ticket(
    ticket_id: str,
    payload: OperationAssignmentUpdate,
    user: Annotated[CurrentUser, Depends(require_permissions("maintenance.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> MaintenanceTicketRead:
    ticket = session.get(MaintenanceTicket, ticket_id)
    if not ticket:
        raise DomainError(code="TICKET_NOT_FOUND", message="Ticket not found.", status_code=404)
    ensure_unit_in_scope(ticket.unit_id, resolve_unit_scope_ids(session, user))
    ticket.assigned_user_id, ticket.assigned_team_id = _resolve_assignment(
        session,
        unit_id=ticket.unit_id,
        assigned_user_id=payload.assigned_user_id,
        assigned_team_id=payload.assigned_team_id,
    )
    session.add(ticket)
    unit = session.get(Unit, ticket.unit_id)
    _notify_maintenance_event(
        session,
        actor_user_id=user["id"],
        ticket=ticket,
        title="Maintenance ticket assigned",
        body=f"Maintenance ticket for unit {unit.code if unit else ticket.unit_id} was reassigned.",
    )
    session.commit()
    session.refresh(ticket)
    return _serialize_ticket(session, ticket)


@router.post("/tickets/{ticket_id}/resolve", response_model=MaintenanceTicketRead)
def resolve_ticket(
    ticket_id: str,
    user: Annotated[CurrentUser, Depends(require_permissions("maintenance.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> MaintenanceTicketRead:
    ticket = session.get(MaintenanceTicket, ticket_id)
    if not ticket:
        raise DomainError(code="TICKET_NOT_FOUND", message="Ticket not found.", status_code=404)
    ensure_unit_in_scope(ticket.unit_id, resolve_unit_scope_ids(session, user))
    user_team_ids = set(
        get_operation_team_ids_for_user(
            session,
            user["id"],
            operation_type=OperationTeamType.maintenance,
        )
    )
    if not _actor_can_manage_assignments(user) and (
        (ticket.assigned_user_id and ticket.assigned_user_id != user["id"])
        or (ticket.assigned_team_id and ticket.assigned_team_id not in user_team_ids)
    ):
        raise DomainError(
            code="TICKET_ASSIGNED_TO_ANOTHER_USER",
            message="This maintenance ticket is assigned to another user.",
            status_code=403,
        )
    ticket.status = TicketStatus.resolved
    ticket.resolved_at = datetime.now(timezone.utc)
    session.add(ticket)
    remaining = session.exec(
        select(MaintenanceTicket).where(
            MaintenanceTicket.unit_id == ticket.unit_id,
            MaintenanceTicket.id != ticket.id,
            MaintenanceTicket.status.in_([TicketStatus.open, TicketStatus.in_progress]),
        )
    ).first()
    unit = session.get(Unit, ticket.unit_id)
    if unit and not remaining:
        unit.status = UnitStatus.ready
        session.add(unit)
    _notify_maintenance_event(
        session,
        actor_user_id=user["id"],
        ticket=ticket,
        title="Maintenance ticket resolved",
        body=f"Maintenance ticket for unit {unit.code if unit else ticket.unit_id} was resolved.",
    )
    session.commit()
    session.refresh(ticket)
    return _serialize_ticket(session, ticket)
