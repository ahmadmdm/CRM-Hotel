from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.core.enums import PriorityLevel, TaskStatus, TicketStatus


class AssignableUserRead(BaseModel):
    target_type: str
    id: str
    name: str
    email: str | None = None
    description: str | None = None
    assigned_unit_ids: list[str] = []
    member_user_ids: list[str] = []


class OperationAssignmentUpdate(BaseModel):
    assigned_user_id: str | None = None
    assigned_team_id: str | None = None


class HousekeepingTaskCreate(BaseModel):
    unit_id: str
    booking_id: str | None = None
    assigned_user_id: str | None = None
    assigned_team_id: str | None = None
    priority: PriorityLevel = PriorityLevel.normal
    notes: str | None = None


class HousekeepingTaskRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    unit_id: str
    unit_code: str | None = None
    unit_name: str | None = None
    booking_id: str | None = None
    assigned_user_id: str | None = None
    assigned_user_name: str | None = None
    assigned_user_email: str | None = None
    assigned_team_id: str | None = None
    assigned_team_name: str | None = None
    status: TaskStatus
    priority: PriorityLevel
    notes: str | None = None
    completed_at: datetime | None = None


class MaintenanceTicketCreate(BaseModel):
    unit_id: str
    booking_id: str | None = None
    assigned_user_id: str | None = None
    assigned_team_id: str | None = None
    title: str
    description: str | None = None
    priority: PriorityLevel = PriorityLevel.normal


class MaintenanceTicketRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    unit_id: str
    unit_code: str | None = None
    unit_name: str | None = None
    booking_id: str | None = None
    assigned_user_id: str | None = None
    assigned_user_name: str | None = None
    assigned_user_email: str | None = None
    assigned_team_id: str | None = None
    assigned_team_name: str | None = None
    title: str
    description: str | None = None
    status: TicketStatus
    priority: PriorityLevel
    resolved_at: datetime | None = None
