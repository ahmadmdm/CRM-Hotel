from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Annotated

from fastapi import APIRouter, Depends
from sqlmodel import Session, select

from app.api.dependencies.auth import CurrentUser, require_permissions
from app.core.access_control import (
    PERMISSION_CATALOG,
    get_access_profile_for_user,
    get_role_codes_for_user,
)
from app.core.db import get_session
from app.core.enums import OperationTeamType, PriorityLevel, TaskStatus, TicketStatus
from app.domain.shared.exceptions import DomainError
from app.infrastructure.persistence.models import (
    HousekeepingTask,
    MaintenanceTicket,
    OperationTeam,
    OperationTeamMember,
    OperationTeamUnitAssignment,
    Unit,
    User,
)
from app.schemas.access import (
    AssignedUnitRead,
    OperationTeamKpiRead,
    OperationTeamMemberRead,
    OperationTeamRead,
    OperationTeamUpsert,
    PermissionRead,
)

router = APIRouter()

TEAM_REQUIRED_PERMISSIONS = {
    OperationTeamType.housekeeping: frozenset({"housekeeping.view", "housekeeping.complete"}),
    OperationTeamType.maintenance: frozenset({"maintenance.view", "maintenance.manage"}),
}

TEAM_OVERDUE_WINDOWS = {
    PriorityLevel.low: timedelta(hours=72),
    PriorityLevel.normal: timedelta(hours=48),
    PriorityLevel.high: timedelta(hours=24),
    PriorityLevel.urgent: timedelta(hours=8),
}


def _normalized_team_name(name: str) -> str:
    return " ".join(name.split())


def _is_work_item_overdue(*, created_at: datetime, priority: PriorityLevel, now: datetime) -> bool:
    resolved_created_at = _as_utc_datetime(created_at)
    return now - resolved_created_at > TEAM_OVERDUE_WINDOWS.get(
        priority,
        TEAM_OVERDUE_WINDOWS[PriorityLevel.normal],
    )


def _as_utc_datetime(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _build_team_kpis(
    session: Session,
    *,
    team: OperationTeam,
    unit_ids: list[str],
    member_user_ids: list[str],
) -> OperationTeamKpiRead:
    if not unit_ids:
        return OperationTeamKpiRead(
            open_work_items=0,
            overdue_work_items=0,
            average_close_hours=0,
        )

    now = datetime.now(timezone.utc)
    open_work_items = 0
    overdue_work_items = 0
    close_durations_hours: list[float] = []

    if team.operation_type == OperationTeamType.housekeeping:
        records = session.exec(
            select(HousekeepingTask).where(HousekeepingTask.unit_id.in_(unit_ids))
        ).all()
        for record in records:
            is_team_workload = record.assigned_team_id == team.id or (
                record.assigned_team_id is None and record.assigned_user_id in member_user_ids
            )
            if not is_team_workload:
                continue
            if record.status == TaskStatus.completed:
                completed_at = _as_utc_datetime(record.completed_at)
                created_at = _as_utc_datetime(record.created_at)
                if completed_at is not None and created_at is not None:
                    close_durations_hours.append(
                        (completed_at - created_at).total_seconds() / 3600
                    )
                continue
            open_work_items += 1
            if _is_work_item_overdue(
                created_at=record.created_at,
                priority=record.priority,
                now=now,
            ):
                overdue_work_items += 1
    else:
        records = session.exec(
            select(MaintenanceTicket).where(MaintenanceTicket.unit_id.in_(unit_ids))
        ).all()
        for record in records:
            is_team_workload = record.assigned_team_id == team.id or (
                record.assigned_team_id is None and record.assigned_user_id in member_user_ids
            )
            if not is_team_workload:
                continue
            if record.status in {TicketStatus.resolved, TicketStatus.closed}:
                resolved_at = _as_utc_datetime(record.resolved_at)
                created_at = _as_utc_datetime(record.created_at)
                if resolved_at is not None and created_at is not None:
                    close_durations_hours.append(
                        (resolved_at - created_at).total_seconds() / 3600
                    )
                continue
            open_work_items += 1
            if _is_work_item_overdue(
                created_at=record.created_at,
                priority=record.priority,
                now=now,
            ):
                overdue_work_items += 1

    average_close_hours = 0.0
    if close_durations_hours:
        average_close_hours = round(sum(close_durations_hours) / len(close_durations_hours), 1)

    return OperationTeamKpiRead(
        open_work_items=open_work_items,
        overdue_work_items=overdue_work_items,
        average_close_hours=average_close_hours,
    )


def _serialize_team(session: Session, team: OperationTeam) -> OperationTeamRead:
    units = session.exec(
        select(Unit)
        .join(OperationTeamUnitAssignment, OperationTeamUnitAssignment.unit_id == Unit.id)
        .where(OperationTeamUnitAssignment.team_id == team.id)
        .order_by(Unit.code)
    ).all()
    members = session.exec(
        select(User)
        .join(OperationTeamMember, OperationTeamMember.user_id == User.id)
        .where(OperationTeamMember.team_id == team.id)
        .order_by(User.full_name)
    ).all()
    unit_ids = [unit.id for unit in units]
    member_user_ids = [member.id for member in members]
    return OperationTeamRead(
        id=team.id,
        name=team.name,
        operation_type=team.operation_type,
        description=team.description,
        is_active=team.is_active,
        unit_ids=unit_ids,
        member_user_ids=member_user_ids,
        units=[
            AssignedUnitRead(
                id=unit.id,
                code=unit.code,
                name=unit.name,
                city=unit.city,
            )
            for unit in units
        ],
        members=[
            OperationTeamMemberRead(
                id=member.id,
                email=member.email,
                full_name=member.full_name,
                role_codes=get_role_codes_for_user(session, member.id),
            )
            for member in members
        ],
        kpis=_build_team_kpis(
            session,
            team=team,
            unit_ids=unit_ids,
            member_user_ids=member_user_ids,
        ),
    )


def _replace_team_members(session: Session, team_id: str, member_user_ids: list[str]) -> None:
    existing_members = session.exec(
        select(OperationTeamMember).where(OperationTeamMember.team_id == team_id)
    ).all()
    for member in existing_members:
        session.delete(member)
    session.flush()
    for user_id in member_user_ids:
        session.add(OperationTeamMember(team_id=team_id, user_id=user_id))


def _replace_team_units(session: Session, team_id: str, unit_ids: list[str]) -> None:
    existing_units = session.exec(
        select(OperationTeamUnitAssignment).where(OperationTeamUnitAssignment.team_id == team_id)
    ).all()
    for assignment in existing_units:
        session.delete(assignment)
    session.flush()
    for unit_id in unit_ids:
        session.add(OperationTeamUnitAssignment(team_id=team_id, unit_id=unit_id))


def _validate_team_payload(
    session: Session,
    *,
    payload: OperationTeamUpsert,
    current_team_id: str | None = None,
) -> tuple[str, list[str], list[str]]:
    normalized_name = _normalized_team_name(payload.name)
    if not normalized_name:
        raise DomainError(
            code="TEAM_NAME_REQUIRED",
            message="Operation teams require a name.",
            status_code=422,
        )
    unit_ids = list(dict.fromkeys(payload.unit_ids))
    member_user_ids = list(dict.fromkeys(payload.member_user_ids))
    if not unit_ids:
        raise DomainError(
            code="TEAM_UNITS_REQUIRED",
            message="Operation teams must include at least one unit.",
            status_code=422,
        )
    if not member_user_ids:
        raise DomainError(
            code="TEAM_MEMBERS_REQUIRED",
            message="Operation teams must include at least one member.",
            status_code=422,
        )

    existing_team = session.exec(
        select(OperationTeam).where(OperationTeam.name == normalized_name)
    ).first()
    if existing_team and existing_team.id != current_team_id:
        raise DomainError(
            code="TEAM_NAME_ALREADY_EXISTS",
            message="An operation team with this name already exists.",
            status_code=409,
        )

    users = {
        user.id: user
        for user in session.exec(select(User).where(User.id.in_(member_user_ids))).all()
    }
    missing_users = sorted(set(member_user_ids) - set(users))
    if missing_users:
        raise DomainError(
            code="TEAM_MEMBER_IDS_NOT_FOUND",
            message="One or more team members do not exist.",
            details={"missing_user_ids": ",".join(missing_users)},
            status_code=404,
        )

    units = {
        unit.id: unit for unit in session.exec(select(Unit).where(Unit.id.in_(unit_ids))).all()
    }
    missing_units = sorted(set(unit_ids) - set(units))
    if missing_units:
        raise DomainError(
            code="TEAM_UNIT_IDS_NOT_FOUND",
            message="One or more team units do not exist.",
            details={"missing_unit_ids": ",".join(missing_units)},
            status_code=404,
        )

    required_permissions = TEAM_REQUIRED_PERMISSIONS[payload.operation_type]
    invalid_members = []
    for user_id in member_user_ids:
        member = users[user_id]
        if not member.is_active:
            invalid_members.append(member.email)
            continue
        access_profile = get_access_profile_for_user(session, member.id)
        if not required_permissions.issubset(set(access_profile.effective_permission_codes)):
            invalid_members.append(member.email)
    if invalid_members:
        raise DomainError(
            code="TEAM_MEMBERS_NOT_ELIGIBLE",
            message="One or more members do not have the required permissions for this team.",
            details={"invalid_members": ",".join(sorted(invalid_members))},
            status_code=422,
        )

    return normalized_name, unit_ids, member_user_ids


@router.get("/permissions-catalog", response_model=list[PermissionRead])
def list_permissions_catalog(
    _: Annotated[CurrentUser, Depends(require_permissions("users.view"))],
) -> list[PermissionRead]:
    return [
        PermissionRead(
            code=definition.code,
            name=definition.name,
            module=definition.module,
            description=definition.description,
        )
        for definition in PERMISSION_CATALOG
    ]


@router.get("/operation-teams", response_model=list[OperationTeamRead])
def list_operation_teams(
    _: Annotated[CurrentUser, Depends(require_permissions("users.view"))],
    session: Annotated[Session, Depends(get_session)],
) -> list[OperationTeamRead]:
    teams = session.exec(
        select(OperationTeam).order_by(OperationTeam.operation_type, OperationTeam.name)
    ).all()
    return [_serialize_team(session, team) for team in teams]


@router.post("/operation-teams", response_model=OperationTeamRead)
def create_operation_team(
    payload: OperationTeamUpsert,
    _: Annotated[CurrentUser, Depends(require_permissions("users.manage_access"))],
    session: Annotated[Session, Depends(get_session)],
) -> OperationTeamRead:
    normalized_name, unit_ids, member_user_ids = _validate_team_payload(session, payload=payload)
    team = OperationTeam(
        name=normalized_name,
        operation_type=payload.operation_type,
        description=payload.description.strip() if payload.description else None,
        is_active=payload.is_active,
    )
    session.add(team)
    session.flush()
    _replace_team_units(session, team.id, unit_ids)
    _replace_team_members(session, team.id, member_user_ids)
    session.commit()
    session.refresh(team)
    return _serialize_team(session, team)


@router.patch("/operation-teams/{team_id}", response_model=OperationTeamRead)
def update_operation_team(
    team_id: str,
    payload: OperationTeamUpsert,
    _: Annotated[CurrentUser, Depends(require_permissions("users.manage_access"))],
    session: Annotated[Session, Depends(get_session)],
) -> OperationTeamRead:
    team = session.get(OperationTeam, team_id)
    if team is None:
        raise DomainError(
            code="TEAM_NOT_FOUND",
            message="Operation team not found.",
            status_code=404,
        )
    normalized_name, unit_ids, member_user_ids = _validate_team_payload(
        session,
        payload=payload,
        current_team_id=team.id,
    )
    team.name = normalized_name
    team.operation_type = payload.operation_type
    team.description = payload.description.strip() if payload.description else None
    team.is_active = payload.is_active
    session.add(team)
    session.flush()
    _replace_team_units(session, team.id, unit_ids)
    _replace_team_members(session, team.id, member_user_ids)
    session.commit()
    session.refresh(team)
    return _serialize_team(session, team)