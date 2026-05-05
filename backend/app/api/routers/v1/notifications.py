from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlmodel import Session

from app.api.dependencies.auth import CurrentUser, require_permissions
from app.core.config import get_settings
from app.core.db import get_session
from app.core.enums import NotificationKind
from app.core.notifications import (
    active_user_ids,
    create_notifications,
    list_notifications_for_user,
    mark_all_notifications_read,
    mark_notification_read,
    unread_notification_count,
)
from app.schemas.notifications import (
    NotificationBroadcastCreate,
    NotificationDeliveryConfigRead,
    NotificationRead,
    NotificationStatsRead,
)

router = APIRouter()


@router.get("/delivery-config", response_model=NotificationDeliveryConfigRead)
def get_delivery_config(
    _: Annotated[
        CurrentUser,
        Depends(require_permissions("notifications.view", "notifications.manage")),
    ],
) -> NotificationDeliveryConfigRead:
    settings = get_settings()
    return NotificationDeliveryConfigRead(
        enabled=bool(settings.onesignal_enabled and settings.onesignal_app_id),
        app_id=settings.onesignal_app_id if settings.onesignal_enabled else None,
        service_worker_path=settings.onesignal_service_worker_path,
        service_worker_scope=settings.onesignal_service_worker_scope,
    )


@router.get("", response_model=list[NotificationRead])
def list_notifications(
    user: Annotated[
        CurrentUser,
        Depends(require_permissions("notifications.view", "notifications.manage")),
    ],
    session: Annotated[Session, Depends(get_session)],
    limit: int = Query(default=50, ge=1, le=200),
) -> list[NotificationRead]:
    return list_notifications_for_user(session, user_id=user["id"], limit=limit)


@router.get("/stats", response_model=NotificationStatsRead)
def get_notification_stats(
    user: Annotated[
        CurrentUser,
        Depends(require_permissions("notifications.view", "notifications.manage")),
    ],
    session: Annotated[Session, Depends(get_session)],
) -> NotificationStatsRead:
    return NotificationStatsRead(
        unread_count=unread_notification_count(session, user_id=user["id"])
    )


@router.post("/broadcast", response_model=list[NotificationRead])
def broadcast_notification(
    payload: NotificationBroadcastCreate,
    actor: Annotated[CurrentUser, Depends(require_permissions("notifications.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> list[NotificationRead]:
    recipients = payload.target_user_ids or active_user_ids(session)
    notifications = create_notifications(
        session,
        recipient_user_ids=recipients,
        actor_user_id=actor["id"],
        kind=NotificationKind.broadcast,
        title=payload.title.strip(),
        body=payload.body.strip(),
        resource_type="notifications",
    )
    session.commit()
    for notification in notifications:
        session.refresh(notification)
    return notifications


@router.post("/{notification_id}/read", response_model=NotificationRead)
def read_notification(
    notification_id: str,
    user: Annotated[
        CurrentUser,
        Depends(require_permissions("notifications.view", "notifications.manage")),
    ],
    session: Annotated[Session, Depends(get_session)],
) -> NotificationRead:
    return mark_notification_read(session, notification_id=notification_id, user_id=user["id"])


@router.post("/read-all")
def read_all_notifications(
    user: Annotated[
        CurrentUser,
        Depends(require_permissions("notifications.view", "notifications.manage")),
    ],
    session: Annotated[Session, Depends(get_session)],
) -> dict[str, int | bool]:
    updated = mark_all_notifications_read(session, user_id=user["id"])
    return {"ok": True, "updated": updated}