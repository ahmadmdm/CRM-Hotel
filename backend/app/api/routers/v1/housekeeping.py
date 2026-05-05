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
from app.core.enums import NotificationKind, OperationTeamType, TaskStatus, UnitStatus
from app.core.notifications import (
    assignment_recipient_user_ids,
    create_notifications,
    user_ids_with_permissions,
)
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
from app.schemas.operations import (
    AssignableUserRead,
    HousekeepingTaskCreate,
    HousekeepingTaskRead,
    OperationAssignmentUpdate,
)

router = APIRouter()

HOUSEKEEPING_ASSIGNEE_PERMISSIONS = frozenset({"housekeeping.view", "housekeeping.complete"})


def _notify_housekeeping_event(
    session: Session,
    *,
    actor_user_id: str,
    task: HousekeepingTask,
    title: str,
    body: str,
) -> None:
    manager_ids = set(
        user_ids_with_permissions(session, {"notifications.manage"}, exclude_user_ids={actor_user_id})
    )
    assignment_ids = set(
        assignment_recipient_user_ids(
            session,
            assigned_user_id=task.assigned_user_id,
            assigned_team_id=task.assigned_team_id,
        )
    )
    assignment_ids.discard(actor_user_id)
    create_notifications(
        session,
        recipient_user_ids=manager_ids | assignment_ids,
        actor_user_id=actor_user_id,
        kind=NotificationKind.housekeeping,
        title=title,
        body=body,
        resource_type="housekeeping_task",
        resource_id=task.id,
    )


def _actor_can_manage_assignments(user: CurrentUser) -> bool:
    return "users.manage_access" in user.permissions or "housekeeping.manage" in user.permissions


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
            OperationTeam.operation_type == OperationTeamType.housekeeping,
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
            if not HOUSEKEEPING_ASSIGNEE_PERMISSIONS.issubset(effective_permissions):
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
        if not HOUSEKEEPING_ASSIGNEE_PERMISSIONS.issubset(effective_permissions):
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
            message="The selected assignee is not eligible for this housekeeping task.",
            status_code=422,
        )
    if assigned_team_id and ("team", assigned_team_id) not in assignable_targets:
        raise DomainError(
            code="ASSIGNEE_NOT_ELIGIBLE",
            message="The selected team is not eligible for this housekeeping task.",
            status_code=422,
        )
    return assigned_user_id, assigned_team_id


def _apply_assignee_scope(statement, *, session: Session, user: CurrentUser):
    if _actor_can_manage_assignments(user):
        return statement
    team_ids = get_operation_team_ids_for_user(
        session,
        user["id"],
        operation_type=OperationTeamType.housekeeping,
    )
    conditions = [
        and_(
            HousekeepingTask.assigned_user_id.is_(None),
            HousekeepingTask.assigned_team_id.is_(None),
        ),
        HousekeepingTask.assigned_user_id == user["id"],
    ]
    if team_ids:
        conditions.append(HousekeepingTask.assigned_team_id.in_(team_ids))
    return statement.where(or_(*conditions))


def _serialize_task(session: Session, task: HousekeepingTask) -> HousekeepingTaskRead:
    unit = session.get(Unit, task.unit_id)
    assignee = session.get(User, task.assigned_user_id) if task.assigned_user_id else None
    team = session.get(OperationTeam, task.assigned_team_id) if task.assigned_team_id else None
    return HousekeepingTaskRead(
        id=task.id,
        unit_id=task.unit_id,
        unit_code=unit.code if unit else None,
        unit_name=unit.name if unit else None,
        booking_id=task.booking_id,
        assigned_user_id=task.assigned_user_id,
        assigned_user_name=assignee.full_name if assignee else None,
        assigned_user_email=assignee.email if assignee else None,
        assigned_team_id=task.assigned_team_id,
        assigned_team_name=team.name if team else None,
        status=task.status,
        priority=task.priority,
        notes=task.notes,
        completed_at=task.completed_at,
    )


@router.get("/assignees", response_model=list[AssignableUserRead])
def list_assignable_users(
    _: Annotated[CurrentUser, Depends(require_permissions("housekeeping.manage"))],
    session: Annotated[Session, Depends(get_session)],
    unit_id: str | None = None,
) -> list[AssignableUserRead]:
    return _resolve_assignable_users(session, unit_id=unit_id)


@router.get("/tasks", response_model=list[HousekeepingTaskRead])
def list_tasks(
    user: Annotated[
        CurrentUser,
        Depends(
            require_permissions(
                "housekeeping.view",
                "housekeeping.complete",
                "housekeeping.manage",
            )
        ),
    ],
    session: Annotated[Session, Depends(get_session)],
) -> list[HousekeepingTaskRead]:
    unit_scope_ids = resolve_unit_scope_ids(session, user)
    statement = select(HousekeepingTask).order_by(HousekeepingTask.created_at.desc())
    statement = apply_unit_scope(statement, unit_scope_ids, HousekeepingTask.unit_id)
    statement = _apply_assignee_scope(statement, session=session, user=user)
    tasks = session.exec(statement).all()
    return [_serialize_task(session, task) for task in tasks]


@router.post("/tasks", response_model=HousekeepingTaskRead)
def create_task(
    payload: HousekeepingTaskCreate,
    user: Annotated[CurrentUser, Depends(require_permissions("housekeeping.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> HousekeepingTaskRead:
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
    task = HousekeepingTask.model_validate(
        payload.model_dump(exclude={"assigned_user_id", "assigned_team_id"}),
        update={
            "assigned_user_id": assigned_user_id,
            "assigned_team_id": assigned_team_id,
        },
    )
    if unit.status != UnitStatus.maintenance:
        unit.status = UnitStatus.pending_cleaning
        session.add(unit)
    session.add(task)
    _notify_housekeeping_event(
        session,
        actor_user_id=user["id"],
        task=task,
        title="Housekeeping task created",
        body=f"A housekeeping task was created for unit {unit.code}.",
    )
    session.commit()
    session.refresh(task)
    return _serialize_task(session, task)


@router.patch("/tasks/{task_id}/assignee", response_model=HousekeepingTaskRead)
def assign_task(
    task_id: str,
    payload: OperationAssignmentUpdate,
    user: Annotated[CurrentUser, Depends(require_permissions("housekeeping.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> HousekeepingTaskRead:
    task = session.get(HousekeepingTask, task_id)
    if not task:
        raise DomainError(code="TASK_NOT_FOUND", message="Task not found.", status_code=404)
    ensure_unit_in_scope(task.unit_id, resolve_unit_scope_ids(session, user))
    task.assigned_user_id, task.assigned_team_id = _resolve_assignment(
        session,
        unit_id=task.unit_id,
        assigned_user_id=payload.assigned_user_id,
        assigned_team_id=payload.assigned_team_id,
    )
    session.add(task)
    unit = session.get(Unit, task.unit_id)
    _notify_housekeeping_event(
        session,
        actor_user_id=user["id"],
        task=task,
        title="Housekeeping task assigned",
        body=(
            f"Housekeeping task for unit {unit.code if unit else task.unit_id} was reassigned."
        ),
    )
    session.commit()
    session.refresh(task)
    return _serialize_task(session, task)


@router.post("/tasks/{task_id}/complete", response_model=HousekeepingTaskRead)
def complete_task(
    task_id: str,
    user: Annotated[CurrentUser, Depends(require_permissions("housekeeping.complete"))],
    session: Annotated[Session, Depends(get_session)],
) -> HousekeepingTaskRead:
    task = session.get(HousekeepingTask, task_id)
    if not task:
        raise DomainError(code="TASK_NOT_FOUND", message="Task not found.", status_code=404)
    ensure_unit_in_scope(task.unit_id, resolve_unit_scope_ids(session, user))
    user_team_ids = set(
        get_operation_team_ids_for_user(
            session,
            user["id"],
            operation_type=OperationTeamType.housekeeping,
        )
    )
    if not _actor_can_manage_assignments(user) and (
        (task.assigned_user_id and task.assigned_user_id != user["id"])
        or (task.assigned_team_id and task.assigned_team_id not in user_team_ids)
    ):
        raise DomainError(
            code="TASK_ASSIGNED_TO_ANOTHER_USER",
            message="This housekeeping task is assigned to another user.",
            status_code=403,
        )
    task.status = TaskStatus.completed
    task.completed_at = datetime.now(timezone.utc)
    unit = session.get(Unit, task.unit_id)
    open_maintenance = session.exec(
        select(MaintenanceTicket).where(
            MaintenanceTicket.unit_id == task.unit_id,
            MaintenanceTicket.status.in_(["open", "in_progress"]),
        )
    ).first()
    if unit and not open_maintenance:
        unit.status = UnitStatus.ready
        session.add(unit)
    session.add(task)
    _notify_housekeeping_event(
        session,
        actor_user_id=user["id"],
        task=task,
        title="Housekeeping task completed",
        body=f"Housekeeping task for unit {unit.code if unit else task.unit_id} is complete.",
    )
    session.commit()
    session.refresh(task)
    return _serialize_task(session, task)
