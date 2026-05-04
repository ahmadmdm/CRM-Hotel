from __future__ import annotations

from typing import Annotated

from fastapi import Depends, Header, HTTPException, status

from app.core.access_control import default_permission_codes_for_roles
from app.core.config import Settings, get_settings
from app.core.security import decode_token


class CurrentUser(dict):
    @property
    def roles(self) -> set[str]:
        return set(self.get("roles", []))

    @property
    def permissions(self) -> set[str]:
        return set(self.get("permissions", []))


def get_settings_dependency() -> Settings:
    return get_settings()


def get_current_user(
    authorization: Annotated[str | None, Header()] = None,
) -> CurrentUser:
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header",
        )
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization scheme",
        )

    token = authorization.removeprefix("Bearer ").strip()
    try:
        payload = decode_token(token)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(exc),
        ) from exc

    user_id = payload.get("uid")
    email = payload.get("sub")
    full_name = payload.get("name")
    roles = payload.get("roles", [])
    permissions = payload.get("permissions", [])

    if not user_id or not email or not isinstance(roles, list):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token payload is invalid",
        )

    if not isinstance(permissions, list):
        permissions = default_permission_codes_for_roles(roles)

    return CurrentUser(
        id=str(user_id),
        email=str(email),
        full_name=str(full_name or email),
        roles=roles,
        permissions=[str(permission_code) for permission_code in permissions],
    )


CurrentAuthenticatedUser = Annotated[CurrentUser, Depends(get_current_user)]


def require_roles(*required_roles: str):
    def dependency(user: CurrentAuthenticatedUser) -> CurrentUser:
        if not user.roles.intersection(required_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions",
            )
        return user

    return dependency


def require_permissions(*required_permissions: str):
    def dependency(user: CurrentAuthenticatedUser) -> CurrentUser:
        if not user.permissions.intersection(required_permissions):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions",
            )
        return user

    return dependency
