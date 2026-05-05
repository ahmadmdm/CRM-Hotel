from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.core.enums import NotificationKind


class NotificationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    recipient_user_id: str
    actor_user_id: str | None = None
    kind: NotificationKind
    title: str
    body: str
    resource_type: str | None = None
    resource_id: str | None = None
    metadata_json: str | None = None
    is_read: bool
    read_at: datetime | None = None
    created_at: datetime


class NotificationBroadcastCreate(BaseModel):
    title: str = Field(min_length=3, max_length=140)
    body: str = Field(min_length=3, max_length=2000)
    target_user_ids: list[str] | None = None


class NotificationStatsRead(BaseModel):
    unread_count: int


class NotificationDeliveryConfigRead(BaseModel):
    enabled: bool
    app_id: str | None = None
    service_worker_path: str | None = None
    service_worker_scope: str | None = None