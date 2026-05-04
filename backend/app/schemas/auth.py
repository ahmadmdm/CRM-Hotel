from __future__ import annotations

from pydantic import BaseModel, EmailStr


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class UserProfileResponse(BaseModel):
    id: str
    email: EmailStr
    full_name: str
    roles: list[str]
    assigned_unit_ids: list[str] = []


class AuthenticatedUserResponse(UserProfileResponse):
    permissions: list[str]


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str
    expires_in: int
    roles: list[str]
    permissions: list[str]
    assigned_unit_ids: list[str] = []
    user: AuthenticatedUserResponse
