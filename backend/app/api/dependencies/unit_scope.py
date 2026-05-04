from __future__ import annotations

from collections.abc import Iterable

from sqlmodel import Session

from app.api.dependencies.auth import CurrentUser
from app.core.access_control import get_effective_unit_scope_ids_for_user
from app.domain.shared.exceptions import DomainError

ADMIN_ROLE_CODES = frozenset({"super_admin", "sub_admin"})


def resolve_unit_scope_ids(session: Session, user: CurrentUser) -> list[str]:
    if set(user.roles).intersection(ADMIN_ROLE_CODES):
        return []
    return get_effective_unit_scope_ids_for_user(session, user["id"])


def apply_unit_scope(statement, unit_ids: Iterable[str], column):
    scoped_unit_ids = list(unit_ids)
    if not scoped_unit_ids:
        return statement
    return statement.where(column.in_(scoped_unit_ids))


def ensure_unit_in_scope(unit_id: str, unit_ids: Iterable[str]) -> None:
    scoped_unit_ids = set(unit_ids)
    if scoped_unit_ids and unit_id not in scoped_unit_ids:
        raise DomainError(
            code="UNIT_ACCESS_FORBIDDEN",
            message="This unit is outside the user's assignment scope.",
            details={"unit_id": unit_id},
            status_code=403,
        )