from __future__ import annotations

from datetime import timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select

from app.api.dependencies.auth import CurrentAuthenticatedUser
from app.core.access_control import (
    get_access_profile_for_user,
    get_effective_unit_scope_ids_for_user,
)
from app.core.config import get_settings
from app.core.db import get_session
from app.core.security import create_access_token, verify_password
from app.infrastructure.persistence.models import Role, User, UserRole
from app.schemas.auth import AuthenticatedUserResponse, LoginRequest, TokenResponse

router = APIRouter()


def _build_authenticated_user_response(
    session: Session,
    *,
    user_id: str,
    email: str,
    full_name: str,
) -> AuthenticatedUserResponse:
    access_profile = get_access_profile_for_user(session, user_id)
    assigned_unit_ids = get_effective_unit_scope_ids_for_user(session, user_id)
    return AuthenticatedUserResponse(
        id=user_id,
        email=email,
        full_name=full_name,
        roles=access_profile.role_codes,
        permissions=access_profile.effective_permission_codes,
        assigned_unit_ids=assigned_unit_ids,
    )


@router.post("/login", response_model=TokenResponse)
def login(
    payload: LoginRequest,
    session: Annotated[Session, Depends(get_session)],
) -> TokenResponse:
    settings = get_settings()
    user = session.exec(select(User).where(User.email == payload.email, User.is_active)).first()
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    roles = session.exec(
        select(Role.code)
        .join(UserRole, UserRole.role_id == Role.id)
        .where(UserRole.user_id == user.id)
    ).all()
    access_profile = get_access_profile_for_user(session, user.id, role_codes=list(roles))
    assigned_unit_ids = get_effective_unit_scope_ids_for_user(session, user.id)

    access_token = create_access_token(
        subject=user.email,
        user_id=user.id,
        full_name=user.full_name,
        roles=access_profile.role_codes,
        permissions=access_profile.effective_permission_codes,
        expires_delta=timedelta(minutes=settings.access_token_expire_minutes),
    )
    return TokenResponse(
        access_token=access_token,
        refresh_token="scaffold-refresh-token",
        token_type="bearer",
        expires_in=settings.access_token_expire_minutes * 60,
        roles=access_profile.role_codes,
        permissions=access_profile.effective_permission_codes,
        assigned_unit_ids=assigned_unit_ids,
        user=AuthenticatedUserResponse(
            id=user.id,
            email=user.email,
            full_name=user.full_name,
            roles=access_profile.role_codes,
            permissions=access_profile.effective_permission_codes,
            assigned_unit_ids=assigned_unit_ids,
        ),
    )


@router.get("/me", response_model=AuthenticatedUserResponse)
def me(
    user: CurrentAuthenticatedUser,
    session: Annotated[Session, Depends(get_session)],
) -> AuthenticatedUserResponse:
    db_user = session.get(User, user["id"])
    if db_user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User no longer exists",
        )
    return _build_authenticated_user_response(
        session,
        user_id=db_user.id,
        email=db_user.email,
        full_name=db_user.full_name,
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh(
    user: CurrentAuthenticatedUser,
    session: Annotated[Session, Depends(get_session)],
) -> TokenResponse:
    settings = get_settings()
    db_user = session.get(User, user["id"])
    if db_user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User no longer exists",
        )
    access_profile = get_access_profile_for_user(session, db_user.id)
    assigned_unit_ids = get_effective_unit_scope_ids_for_user(session, db_user.id)
    access_token = create_access_token(
        subject=db_user.email,
        user_id=db_user.id,
        full_name=db_user.full_name,
        roles=access_profile.role_codes,
        permissions=access_profile.effective_permission_codes,
        expires_delta=timedelta(minutes=settings.access_token_expire_minutes),
    )
    return TokenResponse(
        access_token=access_token,
        refresh_token="scaffold-refresh-token",
        token_type="bearer",
        expires_in=settings.access_token_expire_minutes * 60,
        roles=access_profile.role_codes,
        permissions=access_profile.effective_permission_codes,
        assigned_unit_ids=assigned_unit_ids,
        user=AuthenticatedUserResponse(
            id=db_user.id,
            email=db_user.email,
            full_name=db_user.full_name,
            roles=access_profile.role_codes,
            permissions=access_profile.effective_permission_codes,
            assigned_unit_ids=assigned_unit_ids,
        ),
    )


@router.post("/logout")
def logout(_: CurrentAuthenticatedUser) -> dict[str, str]:
    return {"status": "logged_out"}
