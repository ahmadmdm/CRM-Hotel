from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Iterable

from sqlmodel import Session, select

from app.core.access_control import get_access_profile_for_user
from app.core.config import get_settings
from app.core.enums import NotificationKind
from app.domain.shared.exceptions import DomainError
from app.infrastructure.persistence.models import Notification, OperationTeamMember, OutboxEvent, User


def create_notifications(
    session: Session,
    *,
    recipient_user_ids: Iterable[str],
    kind: NotificationKind,
    title: str,
    body: str,
    actor_user_id: str | None = None,
    resource_type: str | None = None,
    resource_id: str | None = None,
    metadata_json: str | None = None,
) -> list[Notification]:
    settings = get_settings()
    target_ids = sorted({user_id for user_id in recipient_user_ids if user_id})
    if not target_ids:
        return []

    active_user_ids = set(
        session.exec(
            select(User.id).where(User.is_active, User.id.in_(target_ids))
        ).all()
    )

    notifications: list[Notification] = []
    for recipient_user_id in target_ids:
        if recipient_user_id not in active_user_ids:
            continue
        notification = Notification(
            recipient_user_id=recipient_user_id,
            actor_user_id=actor_user_id,
            kind=kind,
            title=title,
            body=body,
            resource_type=resource_type,
            resource_id=resource_id,
            metadata_json=metadata_json,
        )
        session.add(notification)
        if settings.onesignal_ready:
            session.add(
                OutboxEvent(
                    aggregate_type="notification",
                    aggregate_id=notification.id,
                    event_type="notification.push.requested",
                    payload=json.dumps(
                        {
                            "notification_id": notification.id,
                            "recipient_user_id": recipient_user_id,
                            "title": title,
                            "body": body,
                            "kind": kind.value,
                            "resource_type": resource_type,
                            "resource_id": resource_id,
                        }
                    ),
                )
            )
        notifications.append(notification)
    return notifications


def list_notifications_for_user(
    session: Session,
    *,
    user_id: str,
    limit: int = 50,
) -> list[Notification]:
    safe_limit = max(1, min(limit, 200))
    return session.exec(
        select(Notification)
        .where(Notification.recipient_user_id == user_id)
        .order_by(Notification.created_at.desc())
        .limit(safe_limit)
    ).all()


def unread_notification_count(session: Session, *, user_id: str) -> int:
    return len(
        session.exec(
            select(Notification.id).where(
                Notification.recipient_user_id == user_id,
                Notification.is_read.is_(False),
            )
        ).all()
    )


def mark_notification_read(
    session: Session,
    *,
    notification_id: str,
    user_id: str,
) -> Notification:
    notification = session.get(Notification, notification_id)
    if not notification or notification.recipient_user_id != user_id:
        raise DomainError(
            code="NOTIFICATION_NOT_FOUND",
            message="Notification not found.",
            status_code=404,
        )
    if not notification.is_read:
        notification.is_read = True
        notification.read_at = datetime.now(timezone.utc)
        session.add(notification)
        session.commit()
        session.refresh(notification)
    return notification


def mark_all_notifications_read(session: Session, *, user_id: str) -> int:
    notifications = session.exec(
        select(Notification).where(
            Notification.recipient_user_id == user_id,
            Notification.is_read.is_(False),
        )
    ).all()
    now = datetime.now(timezone.utc)
    for notification in notifications:
        notification.is_read = True
        notification.read_at = now
        session.add(notification)
    if notifications:
        session.commit()
    return len(notifications)


def active_user_ids(session: Session) -> list[str]:
    return session.exec(select(User.id).where(User.is_active).order_by(User.full_name)).all()


def user_ids_with_permissions(
    session: Session,
    permission_codes: set[str],
    *,
    exclude_user_ids: set[str] | None = None,
) -> list[str]:
    excluded = exclude_user_ids or set()
    users = session.exec(select(User).where(User.is_active).order_by(User.full_name)).all()
    matches: list[str] = []
    for user in users:
        if user.id in excluded:
            continue
        access_profile = get_access_profile_for_user(session, user.id)
        if permission_codes.issubset(set(access_profile.effective_permission_codes)):
            matches.append(user.id)
    return matches


def assignment_recipient_user_ids(
    session: Session,
    *,
    assigned_user_id: str | None,
    assigned_team_id: str | None,
) -> list[str]:
    recipient_ids: set[str] = set()
    if assigned_user_id:
        recipient_ids.add(assigned_user_id)
    if assigned_team_id:
        recipient_ids.update(
            session.exec(
                select(OperationTeamMember.user_id).where(
                    OperationTeamMember.team_id == assigned_team_id
                )
            ).all()
        )
    return sorted(recipient_ids)