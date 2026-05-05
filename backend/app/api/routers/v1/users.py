from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends
from sqlmodel import Session, select

from app.api.dependencies.auth import CurrentUser, require_permissions
from app.core.access_control import (
    SUB_ADMIN_MANAGEABLE_PERMISSION_CODES,
    get_access_profile_for_user,
    get_assigned_unit_ids_for_user,
    get_role_permission_codes_map,
    get_role_codes_for_user,
)
from app.core.db import get_session
from app.core.security import hash_password
from app.domain.shared.exceptions import DomainError
from app.infrastructure.persistence.models import (
    AuditLog,
    HousekeepingTask,
    MaintenanceTicket,
    OperationTeamMember,
    Permission,
    RefreshToken,
    Role,
    Unit,
    User,
    UserPermissionOverride,
    UserRole,
    UserUnitAssignment,
)
from app.schemas.access import (
    AssignedUnitRead,
    PermissionOverrideRead,
    UserCreate,
    UserAccessRead,
    UserAccessUpdate,
    UserListItemRead,
)

router = APIRouter()


def _resolve_role_map(session: Session) -> dict[str, Role]:
    return {role.code: role for role in session.exec(select(Role)).all()}


def _resolve_permission_map(session: Session) -> dict[str, Permission]:
    return {permission.code: permission for permission in session.exec(select(Permission)).all()}


def _resolve_unit_map(session: Session) -> dict[str, Unit]:
    return {unit.id: unit for unit in session.exec(select(Unit).where(Unit.is_active)).all()}


def _serialize_user(session: Session, user: User) -> UserListItemRead:
    role_codes = get_role_codes_for_user(session, user.id)
    return UserListItemRead(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        is_active=user.is_active,
        role_codes=role_codes,
    )


def _serialize_user_access(session: Session, user: User) -> UserAccessRead:
    access_profile = get_access_profile_for_user(session, user.id)
    assigned_unit_ids = get_assigned_unit_ids_for_user(session, user.id)
    assigned_units = session.exec(
        select(Unit)
        .join(UserUnitAssignment, UserUnitAssignment.unit_id == Unit.id)
        .where(UserUnitAssignment.user_id == user.id)
        .order_by(Unit.code)
    ).all()
    return UserAccessRead(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        is_active=user.is_active,
        role_codes=access_profile.role_codes,
        inherited_permissions=access_profile.inherited_permission_codes,
        effective_permissions=access_profile.effective_permission_codes,
        overrides=[
            PermissionOverrideRead(
                permission_code=override.permission_code,
                effect=override.effect,
            )
            for override in access_profile.overrides
        ],
        assigned_unit_ids=assigned_unit_ids,
        assigned_units=[
            AssignedUnitRead(
                id=unit.id,
                code=unit.code,
                name=unit.name,
                city=unit.city,
            )
            for unit in assigned_units
        ],
    )


def _ensure_valid_codes(
    *,
    role_codes: list[str],
    permission_codes: list[str],
    unit_ids: list[str],
    role_map: dict[str, Role],
    permission_map: dict[str, Permission],
    unit_map: dict[str, Unit],
) -> None:
    missing_roles = sorted(set(role_codes) - set(role_map))
    if missing_roles:
        raise DomainError(
            code="ROLE_CODES_NOT_FOUND",
            message="One or more role codes do not exist.",
            details={"missing_roles": ",".join(missing_roles)},
            status_code=404,
        )

    missing_permissions = sorted(set(permission_codes) - set(permission_map))
    if missing_permissions:
        raise DomainError(
            code="PERMISSION_CODES_NOT_FOUND",
            message="One or more permission codes do not exist.",
            details={"missing_permissions": ",".join(missing_permissions)},
            status_code=404,
        )

    missing_units = sorted(set(unit_ids) - set(unit_map))
    if missing_units:
        raise DomainError(
            code="UNIT_IDS_NOT_FOUND",
            message="One or more assigned units do not exist.",
            details={"missing_unit_ids": ",".join(missing_units)},
            status_code=404,
        )


def _enforce_access_update_scope(
    *,
    actor: CurrentUser,
    target_user: User,
    current_role_codes: list[str],
    requested_role_codes: list[str],
    requested_role_permission_codes: dict[str, list[str]],
    override_permission_codes: list[str],
) -> None:
    if "super_admin" in actor.roles:
        return

    if actor["id"] == target_user.id:
        raise DomainError(
            code="CANNOT_EDIT_SELF_ACCESS",
            message="Sub-admin users cannot edit their own access.",
            status_code=403,
        )

    current_admin_roles = {"super_admin", "sub_admin"}.intersection(current_role_codes)
    if current_admin_roles:
        raise DomainError(
            code="CANNOT_EDIT_ADMIN_ACCESS",
            message="Sub-admin users cannot edit admin accounts.",
            status_code=403,
        )

    if any(
        not set(requested_role_permission_codes.get(role_code, [])).issubset(
            SUB_ADMIN_MANAGEABLE_PERMISSION_CODES
        )
        for role_code in requested_role_codes
    ):
        raise DomainError(
            code="ROLE_ASSIGNMENT_FORBIDDEN",
            message="Sub-admin users can assign only operational permission groups.",
            status_code=403,
        )

    if not set(override_permission_codes).issubset(SUB_ADMIN_MANAGEABLE_PERMISSION_CODES):
        raise DomainError(
            code="PERMISSION_ASSIGNMENT_FORBIDDEN",
            message="Sub-admin users can grant only operational permissions.",
            status_code=403,
        )


def _enforce_access_create_scope(
    *,
    actor: CurrentUser,
    requested_role_codes: list[str],
    requested_role_permission_codes: dict[str, list[str]],
    override_permission_codes: list[str],
) -> None:
    if "super_admin" in actor.roles:
        return

    if any(
        not set(requested_role_permission_codes.get(role_code, [])).issubset(
            SUB_ADMIN_MANAGEABLE_PERMISSION_CODES
        )
        for role_code in requested_role_codes
    ):
        raise DomainError(
            code="ROLE_ASSIGNMENT_FORBIDDEN",
            message="Sub-admin users can assign only operational permission groups.",
            status_code=403,
        )

    if not set(override_permission_codes).issubset(
        SUB_ADMIN_MANAGEABLE_PERMISSION_CODES
    ):
        raise DomainError(
            code="PERMISSION_ASSIGNMENT_FORBIDDEN",
            message="Sub-admin users can grant only operational permissions.",
            status_code=403,
        )


def _enforce_user_delete_scope(
    *,
    actor: CurrentUser,
    target_user: User,
    current_role_codes: list[str],
    current_role_permission_codes: dict[str, list[str]],
) -> None:
    if actor["id"] == target_user.id:
        raise DomainError(
            code="CANNOT_DELETE_SELF",
            message="Users cannot delete their own account.",
            status_code=403,
        )

    if "super_admin" in current_role_codes:
        raise DomainError(
            code="CANNOT_DELETE_SUPER_ADMIN",
            message="Super admin accounts cannot be deleted.",
            status_code=403,
        )

    if "super_admin" in actor.roles:
        return

    current_admin_roles = {"sub_admin"}.intersection(current_role_codes)
    if current_admin_roles:
        raise DomainError(
            code="CANNOT_DELETE_ADMIN_ACCESS",
            message="Sub-admin users cannot delete admin accounts.",
            status_code=403,
        )

    if any(
        not set(current_role_permission_codes.get(role_code, [])).issubset(
            SUB_ADMIN_MANAGEABLE_PERMISSION_CODES
        )
        for role_code in current_role_codes
    ):
        raise DomainError(
            code="USER_DELETE_FORBIDDEN",
            message="Sub-admin users can delete only operational user accounts.",
            status_code=403,
        )


def _delete_user_and_dependencies(session: Session, user: User) -> None:
    session.exec(
        select(OperationTeamMember).where(OperationTeamMember.user_id == user.id)
    ).all()
    team_memberships = session.exec(
        select(OperationTeamMember).where(OperationTeamMember.user_id == user.id)
    ).all()
    for membership in team_memberships:
        session.delete(membership)

    assigned_housekeeping_tasks = session.exec(
        select(HousekeepingTask).where(HousekeepingTask.assigned_user_id == user.id)
    ).all()
    for task in assigned_housekeeping_tasks:
        task.assigned_user_id = None
        session.add(task)

    assigned_maintenance_tickets = session.exec(
        select(MaintenanceTicket).where(MaintenanceTicket.assigned_user_id == user.id)
    ).all()
    for ticket in assigned_maintenance_tickets:
        ticket.assigned_user_id = None
        session.add(ticket)

    audit_logs = session.exec(
        select(AuditLog).where(AuditLog.actor_user_id == user.id)
    ).all()
    for log in audit_logs:
        log.actor_user_id = None
        session.add(log)

    refresh_tokens = session.exec(
        select(RefreshToken).where(RefreshToken.user_id == user.id)
    ).all()
    for token in refresh_tokens:
        session.delete(token)

    unit_assignments = session.exec(
        select(UserUnitAssignment).where(UserUnitAssignment.user_id == user.id)
    ).all()
    for assignment in unit_assignments:
        session.delete(assignment)

    permission_overrides = session.exec(
        select(UserPermissionOverride).where(UserPermissionOverride.user_id == user.id)
    ).all()
    for override in permission_overrides:
        session.delete(override)

    role_links = session.exec(
        select(UserRole).where(UserRole.user_id == user.id)
    ).all()
    for link in role_links:
        session.delete(link)

    session.flush()
    session.delete(user)
    session.commit()


@router.get("", response_model=list[UserListItemRead])
def list_users(
    _: Annotated[
        CurrentUser,
        Depends(require_permissions("users.view", "users.manage_access")),
    ],
    session: Annotated[Session, Depends(get_session)],
) -> list[UserListItemRead]:
    users = session.exec(select(User).order_by(User.full_name)).all()
    return [_serialize_user(session, user) for user in users]


@router.post("", response_model=UserAccessRead)
def create_user(
    payload: UserCreate,
    actor: Annotated[CurrentUser, Depends(require_permissions("users.manage_access"))],
    session: Annotated[Session, Depends(get_session)],
) -> UserAccessRead:
    full_name = payload.full_name.strip()
    email = payload.email.strip().lower()
    if not full_name:
        raise DomainError(
            code="USER_FULL_NAME_REQUIRED",
            message="Full name is required.",
            status_code=400,
        )

    existing_user = session.exec(select(User).where(User.email == email)).first()
    if existing_user is not None:
        raise DomainError(
            code="USER_EMAIL_ALREADY_EXISTS",
            message="A user with this email already exists.",
            status_code=409,
        )

    role_map = _resolve_role_map(session)
    requested_role_permission_codes = get_role_permission_codes_map(
        session,
        payload.role_codes,
    )
    permission_map = _resolve_permission_map(session)
    unit_map = _resolve_unit_map(session)
    permission_codes = [override.permission_code for override in payload.overrides]
    assigned_unit_ids = list(dict.fromkeys(payload.assigned_unit_ids))
    _ensure_valid_codes(
        role_codes=payload.role_codes,
        permission_codes=permission_codes,
        unit_ids=assigned_unit_ids,
        role_map=role_map,
        permission_map=permission_map,
        unit_map=unit_map,
    )
    _enforce_access_create_scope(
        actor=actor,
        requested_role_codes=payload.role_codes,
        requested_role_permission_codes=requested_role_permission_codes,
        override_permission_codes=permission_codes,
    )

    user = User(
        full_name=full_name,
        email=email,
        password_hash=hash_password(payload.password),
        is_active=payload.is_active,
    )
    session.add(user)
    session.flush()

    for role_code in sorted(set(payload.role_codes)):
        session.add(UserRole(user_id=user.id, role_id=role_map[role_code].id))

    for override in payload.overrides:
        session.add(
            UserPermissionOverride(
                user_id=user.id,
                permission_id=permission_map[override.permission_code].id,
                effect=override.effect,
            )
        )

    for unit_id in assigned_unit_ids:
        session.add(UserUnitAssignment(user_id=user.id, unit_id=unit_id))

    session.commit()
    session.refresh(user)
    return _serialize_user_access(session, user)


@router.get("/{user_id}/access", response_model=UserAccessRead)
def get_user_access(
    user_id: str,
    _: Annotated[
        CurrentUser,
        Depends(require_permissions("users.view", "users.manage_access")),
    ],
    session: Annotated[Session, Depends(get_session)],
) -> UserAccessRead:
    user = session.get(User, user_id)
    if user is None:
        raise DomainError(
            code="USER_NOT_FOUND",
            message="User not found.",
            status_code=404,
        )
    return _serialize_user_access(session, user)


@router.patch("/{user_id}/access", response_model=UserAccessRead)
def update_user_access(
    user_id: str,
    payload: UserAccessUpdate,
    actor: Annotated[CurrentUser, Depends(require_permissions("users.manage_access"))],
    session: Annotated[Session, Depends(get_session)],
) -> UserAccessRead:
    user = session.get(User, user_id)
    if user is None:
        raise DomainError(
            code="USER_NOT_FOUND",
            message="User not found.",
            status_code=404,
        )

    role_map = _resolve_role_map(session)
    requested_role_permission_codes = get_role_permission_codes_map(
        session,
        payload.role_codes,
    )
    permission_map = _resolve_permission_map(session)
    unit_map = _resolve_unit_map(session)
    permission_codes = [override.permission_code for override in payload.overrides]
    assigned_unit_ids = list(dict.fromkeys(payload.assigned_unit_ids))
    _ensure_valid_codes(
        role_codes=payload.role_codes,
        permission_codes=permission_codes,
        unit_ids=assigned_unit_ids,
        role_map=role_map,
        permission_map=permission_map,
        unit_map=unit_map,
    )

    current_role_codes = get_role_codes_for_user(session, user.id)
    _enforce_access_update_scope(
        actor=actor,
        target_user=user,
        current_role_codes=current_role_codes,
        requested_role_codes=payload.role_codes,
        requested_role_permission_codes=requested_role_permission_codes,
        override_permission_codes=permission_codes,
    )

    existing_role_links = session.exec(select(UserRole).where(UserRole.user_id == user.id)).all()
    for link in existing_role_links:
        session.delete(link)
    session.flush()
    for role_code in sorted(set(payload.role_codes)):
        session.add(UserRole(user_id=user.id, role_id=role_map[role_code].id))

    existing_overrides = session.exec(
        select(UserPermissionOverride).where(UserPermissionOverride.user_id == user.id)
    ).all()
    for override in existing_overrides:
        session.delete(override)
    session.flush()
    for override in payload.overrides:
        session.add(
            UserPermissionOverride(
                user_id=user.id,
                permission_id=permission_map[override.permission_code].id,
                effect=override.effect,
            )
        )

    existing_unit_assignments = session.exec(
        select(UserUnitAssignment).where(UserUnitAssignment.user_id == user.id)
    ).all()
    for assignment in existing_unit_assignments:
        session.delete(assignment)
    session.flush()
    for unit_id in assigned_unit_ids:
        session.add(UserUnitAssignment(user_id=user.id, unit_id=unit_id))

    session.commit()
    return _serialize_user_access(session, user)


@router.delete("/{user_id}")
def delete_user(
    user_id: str,
    actor: Annotated[CurrentUser, Depends(require_permissions("users.manage_access"))],
    session: Annotated[Session, Depends(get_session)],
) -> dict[str, bool]:
    user = session.get(User, user_id)
    if user is None:
        raise DomainError(
            code="USER_NOT_FOUND",
            message="User not found.",
            status_code=404,
        )

    current_role_codes = get_role_codes_for_user(session, user.id)
    current_role_permission_codes = get_role_permission_codes_map(
        session,
        current_role_codes,
    )
    _enforce_user_delete_scope(
        actor=actor,
        target_user=user,
        current_role_codes=current_role_codes,
        current_role_permission_codes=current_role_permission_codes,
    )
    _delete_user_and_dependencies(session, user)
    return {"ok": True}