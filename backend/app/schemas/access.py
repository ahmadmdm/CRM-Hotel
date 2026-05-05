from __future__ import annotations

from pydantic import BaseModel, EmailStr, Field

from app.core.enums import AccessOverrideEffect, OperationTeamType


class PermissionRead(BaseModel):
    code: str
    name: str
    module: str
    description: str


class PermissionGroupRead(BaseModel):
    code: str
    name: str
    permission_codes: list[str]
    is_system: bool
    member_count: int


class PermissionGroupUpsert(BaseModel):
    name: str = Field(min_length=2)
    permission_codes: list[str] = []


class PermissionOverrideRead(BaseModel):
    permission_code: str
    effect: AccessOverrideEffect


class AssignedUnitRead(BaseModel):
    id: str
    code: str
    name: str
    city: str


class UserListItemRead(BaseModel):
    id: str
    email: EmailStr
    full_name: str
    is_active: bool
    role_codes: list[str]


class UserAccessRead(UserListItemRead):
    inherited_permissions: list[str]
    effective_permissions: list[str]
    overrides: list[PermissionOverrideRead]
    assigned_unit_ids: list[str]
    assigned_units: list[AssignedUnitRead]


class UserAccessUpdate(BaseModel):
    role_codes: list[str]
    overrides: list[PermissionOverrideRead] = []
    assigned_unit_ids: list[str] = []


class UserCreate(BaseModel):
    full_name: str = Field(min_length=2)
    email: EmailStr
    password: str = Field(min_length=8)
    is_active: bool = True
    role_codes: list[str] = []
    overrides: list[PermissionOverrideRead] = []
    assigned_unit_ids: list[str] = []


class OperationTeamMemberRead(BaseModel):
    id: str
    email: EmailStr
    full_name: str
    role_codes: list[str]


class OperationTeamKpiRead(BaseModel):
    open_work_items: int
    overdue_work_items: int
    average_close_hours: float


class OperationTeamRead(BaseModel):
    id: str
    name: str
    operation_type: OperationTeamType
    description: str | None = None
    is_active: bool
    unit_ids: list[str]
    member_user_ids: list[str]
    units: list[AssignedUnitRead]
    members: list[OperationTeamMemberRead]
    kpis: OperationTeamKpiRead


class OperationTeamUpsert(BaseModel):
    name: str
    operation_type: OperationTeamType
    description: str | None = None
    is_active: bool = True
    unit_ids: list[str] = []
    member_user_ids: list[str] = []