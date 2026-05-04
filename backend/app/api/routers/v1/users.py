from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends
from sqlmodel import Session, select

from app.api.dependencies.auth import CurrentUser, require_permissions
from app.core.access_control import (
    SUB_ADMIN_ASSIGNABLE_ROLE_CODES,
    SUB_ADMIN_MANAGEABLE_PERMISSION_CODES,
    get_access_profile_for_user,
    get_assigned_unit_ids_for_user,
    get_role_codes_for_user,
)
from app.core.db import get_session
from app.domain.shared.exceptions import DomainError
from app.infrastructure.persistence.models import (
    Permission,
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

    if not set(requested_role_codes).issubset(SUB_ADMIN_ASSIGNABLE_ROLE_CODES):
        raise DomainError(
            code="ROLE_ASSIGNMENT_FORBIDDEN",
            message="Sub-admin users can assign only operational roles.",
            status_code=403,
        )

    if not set(override_permission_codes).issubset(SUB_ADMIN_MANAGEABLE_PERMISSION_CODES):
        raise DomainError(
            code="PERMISSION_ASSIGNMENT_FORBIDDEN",
            message="Sub-admin users can grant only operational permissions.",
            status_code=403,
        )


@router.get("", response_model=list[UserListItemRead])
def list_users(
    _: Annotated[CurrentUser, Depends(require_permissions("users.view"))],
    session: Annotated[Session, Depends(get_session)],
) -> list[UserListItemRead]:
    users = session.exec(select(User).order_by(User.full_name)).all()
    return [_serialize_user(session, user) for user in users]


@router.get("/{user_id}/access", response_model=UserAccessRead)
def get_user_access(
    user_id: str,
    _: Annotated[CurrentUser, Depends(require_permissions("users.view"))],
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