from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass

from sqlmodel import Session, select

from app.core.enums import AccessOverrideEffect
from app.infrastructure.persistence.models import (
    OperationTeam,
    OperationTeamMember,
    OperationTeamUnitAssignment,
    Permission,
    Role,
    RolePermission,
    UserPermissionOverride,
    UserRole,
    UserUnitAssignment,
)


@dataclass(frozen=True)
class PermissionDefinition:
    code: str
    name: str
    module: str
    description: str


PERMISSION_CATALOG: tuple[PermissionDefinition, ...] = (
    PermissionDefinition(
        code="dashboard.view",
        name="Dashboard View",
        module="dashboard",
        description="Access the main dashboard and KPI summaries.",
    ),
    PermissionDefinition(
        code="units.view",
        name="Units View",
        module="units",
        description="View units, images, and amenity data.",
    ),
    PermissionDefinition(
        code="units.manage",
        name="Units Manage",
        module="units",
        description="Create, edit, upload images for, and deactivate units.",
    ),
    PermissionDefinition(
        code="bookings.view",
        name="Bookings View",
        module="bookings",
        description="View booking lists and booking details.",
    ),
    PermissionDefinition(
        code="bookings.manage",
        name="Bookings Manage",
        module="bookings",
        description="Create bookings and run booking lifecycle transitions.",
    ),
    PermissionDefinition(
        code="crm.view",
        name="CRM View",
        module="crm",
        description="View clients and CRM records.",
    ),
    PermissionDefinition(
        code="crm.manage",
        name="CRM Manage",
        module="crm",
        description="Create, update, and blacklist clients.",
    ),
    PermissionDefinition(
        code="finance.view",
        name="Finance View",
        module="finance",
        description="View payments and expenses.",
    ),
    PermissionDefinition(
        code="finance.manage",
        name="Finance Manage",
        module="finance",
        description="Record payments and expenses.",
    ),
    PermissionDefinition(
        code="housekeeping.view",
        name="Housekeeping View",
        module="housekeeping",
        description="View housekeeping tasks.",
    ),
    PermissionDefinition(
        code="housekeeping.complete",
        name="Housekeeping Complete",
        module="housekeeping",
        description="Complete housekeeping tasks and update unit readiness.",
    ),
    PermissionDefinition(
        code="housekeeping.manage",
        name="Housekeeping Manage",
        module="housekeeping",
        description="Create housekeeping tasks and assign them to service staff.",
    ),
    PermissionDefinition(
        code="maintenance.view",
        name="Maintenance View",
        module="maintenance",
        description="View maintenance tickets.",
    ),
    PermissionDefinition(
        code="maintenance.manage",
        name="Maintenance Manage",
        module="maintenance",
        description="Create and resolve maintenance tickets.",
    ),
    PermissionDefinition(
        code="reports.view",
        name="Reports View",
        module="reports",
        description="Access operational and financial reports.",
    ),
    PermissionDefinition(
        code="users.view",
        name="Users View",
        module="access",
        description="View users and their access assignments.",
    ),
    PermissionDefinition(
        code="users.manage_access",
        name="Users Manage Access",
        module="access",
        description="Manage user roles and per-user permission overrides.",
    ),
    PermissionDefinition(
        code="notifications.view",
        name="Notifications View",
        module="notifications",
        description="View personal and operational notifications.",
    ),
    PermissionDefinition(
        code="notifications.manage",
        name="Notifications Manage",
        module="notifications",
        description="Broadcast general notices and manage notification operations.",
    ),
)

ALL_PERMISSION_CODES = frozenset(definition.code for definition in PERMISSION_CATALOG)

ROLE_PERMISSION_CODES: dict[str, frozenset[str]] = {
    "super_admin": ALL_PERMISSION_CODES,
    "sub_admin": frozenset(
        {
            "dashboard.view",
            "units.view",
            "units.manage",
            "bookings.view",
            "bookings.manage",
            "crm.view",
            "crm.manage",
            "housekeeping.view",
            "housekeeping.complete",
            "housekeeping.manage",
            "maintenance.view",
            "maintenance.manage",
            "reports.view",
            "users.view",
            "users.manage_access",
            "notifications.view",
            "notifications.manage",
        }
    ),
    "financial": frozenset(
        {
            "dashboard.view",
            "units.view",
            "bookings.view",
            "crm.view",
            "finance.view",
            "finance.manage",
            "reports.view",
            "notifications.view",
        }
    ),
    "operations": frozenset(
        {
            "dashboard.view",
            "units.view",
            "bookings.view",
            "bookings.manage",
            "crm.view",
            "crm.manage",
            "reports.view",
            "notifications.view",
        }
    ),
    "maintenance": frozenset(
        {"maintenance.view", "maintenance.manage", "notifications.view"}
    ),
    "housekeeping": frozenset(
        {"housekeeping.view", "housekeeping.complete", "notifications.view"}
    ),
}

SYSTEM_ROLE_CODES = frozenset(ROLE_PERMISSION_CODES)

SUB_ADMIN_ASSIGNABLE_ROLE_CODES = frozenset(
    {"financial", "operations", "maintenance", "housekeeping"}
)
SUB_ADMIN_MANAGEABLE_PERMISSION_CODES = frozenset(
    permission_code
    for role_code in SUB_ADMIN_ASSIGNABLE_ROLE_CODES
    for permission_code in ROLE_PERMISSION_CODES[role_code]
)


@dataclass(frozen=True)
class PermissionOverrideSummary:
    permission_code: str
    effect: AccessOverrideEffect


@dataclass(frozen=True)
class AccessProfile:
    role_codes: list[str]
    inherited_permission_codes: list[str]
    effective_permission_codes: list[str]
    overrides: list[PermissionOverrideSummary]


def default_permission_codes_for_roles(role_codes: Iterable[str]) -> list[str]:
    permissions: set[str] = set()
    for role_code in role_codes:
        permissions.update(ROLE_PERMISSION_CODES.get(role_code, set()))
    return sorted(permissions)


def apply_permission_overrides(
    inherited_permission_codes: Iterable[str],
    overrides: dict[str, AccessOverrideEffect],
) -> list[str]:
    effective_permissions = set(inherited_permission_codes)
    for permission_code, effect in overrides.items():
        if effect == AccessOverrideEffect.allow:
            effective_permissions.add(permission_code)
        else:
            effective_permissions.discard(permission_code)
    return sorted(effective_permissions)


def get_role_codes_for_user(session: Session, user_id: str) -> list[str]:
    role_codes = session.exec(
        select(Role.code)
        .join(UserRole, UserRole.role_id == Role.id)
        .where(UserRole.user_id == user_id)
        .order_by(Role.code)
    ).all()
    return sorted(role_codes)


def get_role_permission_codes_map(
    session: Session,
    role_codes: Iterable[str] | None = None,
) -> dict[str, list[str]]:
    requested_role_codes = sorted(set(role_codes or []))
    statement = (
        select(Role.code, Permission.code)
        .join(RolePermission, RolePermission.role_id == Role.id)
        .join(Permission, Permission.id == RolePermission.permission_id)
        .order_by(Role.code, Permission.code)
    )
    if requested_role_codes:
        statement = statement.where(Role.code.in_(requested_role_codes))

    permission_map: dict[str, set[str]] = {
        role_code: set() for role_code in requested_role_codes
    }
    for role_code, permission_code in session.exec(statement).all():
        permission_map.setdefault(role_code, set()).add(permission_code)

    return {
        role_code: sorted(permission_codes)
        for role_code, permission_codes in sorted(permission_map.items())
    }


def get_inherited_permission_codes_for_user(session: Session, user_id: str) -> list[str]:
    permission_codes = session.exec(
        select(Permission.code)
        .join(RolePermission, RolePermission.permission_id == Permission.id)
        .join(Role, Role.id == RolePermission.role_id)
        .join(UserRole, UserRole.role_id == Role.id)
        .where(UserRole.user_id == user_id)
        .order_by(Permission.code)
    ).all()
    return sorted(set(permission_codes))


def get_permission_override_map_for_user(
    session: Session, user_id: str
) -> dict[str, AccessOverrideEffect]:
    rows = session.exec(
        select(Permission.code, UserPermissionOverride.effect)
        .join(UserPermissionOverride, UserPermissionOverride.permission_id == Permission.id)
        .where(UserPermissionOverride.user_id == user_id)
    ).all()
    return {permission_code: effect for permission_code, effect in rows}


def get_assigned_unit_ids_for_user(session: Session, user_id: str) -> list[str]:
    unit_ids = session.exec(
        select(UserUnitAssignment.unit_id)
        .where(UserUnitAssignment.user_id == user_id)
        .order_by(UserUnitAssignment.unit_id)
    ).all()
    return list(unit_ids)


def get_operation_team_ids_for_user(
    session: Session,
    user_id: str,
    *,
    operation_type: str | None = None,
) -> list[str]:
    statement = (
        select(OperationTeam.id)
        .join(OperationTeamMember, OperationTeamMember.team_id == OperationTeam.id)
        .where(OperationTeamMember.user_id == user_id, OperationTeam.is_active)
        .order_by(OperationTeam.name)
    )
    if operation_type is not None:
        statement = statement.where(OperationTeam.operation_type == operation_type)
    return list(dict.fromkeys(session.exec(statement).all()))


def get_effective_unit_scope_ids_for_user(session: Session, user_id: str) -> list[str]:
    direct_unit_ids = set(get_assigned_unit_ids_for_user(session, user_id))
    team_unit_ids = set(
        session.exec(
            select(OperationTeamUnitAssignment.unit_id)
            .join(OperationTeam, OperationTeam.id == OperationTeamUnitAssignment.team_id)
            .join(OperationTeamMember, OperationTeamMember.team_id == OperationTeam.id)
            .where(OperationTeamMember.user_id == user_id, OperationTeam.is_active)
            .order_by(OperationTeamUnitAssignment.unit_id)
        ).all()
    )
    return sorted(direct_unit_ids.union(team_unit_ids))


def get_access_profile_for_user(
    session: Session,
    user_id: str,
    *,
    role_codes: list[str] | None = None,
) -> AccessProfile:
    resolved_role_codes = role_codes or get_role_codes_for_user(session, user_id)
    inherited_permission_codes = get_inherited_permission_codes_for_user(session, user_id)
    overrides_map = get_permission_override_map_for_user(session, user_id)
    effective_permission_codes = apply_permission_overrides(
        inherited_permission_codes,
        overrides_map,
    )
    overrides = [
        PermissionOverrideSummary(permission_code=permission_code, effect=effect)
        for permission_code, effect in sorted(overrides_map.items())
    ]
    return AccessProfile(
        role_codes=sorted(resolved_role_codes),
        inherited_permission_codes=inherited_permission_codes,
        effective_permission_codes=effective_permission_codes,
        overrides=overrides,
    )