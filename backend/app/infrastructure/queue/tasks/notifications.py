from __future__ import annotations

import json
from datetime import datetime, timezone

import httpx
from sqlmodel import Session, select

from app.core.config import get_settings
from app.core.db import engine
from app.infrastructure.persistence.models import OutboxEvent
from app.infrastructure.queue.celery_app import celery_app


@celery_app.task(name="app.infrastructure.queue.tasks.notifications.deliver_pending_notification_pushes")
def deliver_pending_notification_pushes(batch_size: int = 100) -> dict[str, int | str]:
    settings = get_settings()
    if not settings.onesignal_ready:
        return {"status": "skipped", "processed": 0, "sent": 0, "failed": 0}

    now = datetime.now(timezone.utc)
    with Session(engine) as session:
        events = session.exec(
            select(OutboxEvent)
            .where(
                OutboxEvent.event_type == "notification.push.requested",
                OutboxEvent.processed_at.is_(None),
                OutboxEvent.available_at <= now,
            )
            .order_by(OutboxEvent.available_at)
            .limit(max(1, min(batch_size, 500)))
        ).all()

        if not events:
            return {"status": "ok", "processed": 0, "sent": 0, "failed": 0}

        sent = 0
        failed = 0
        headers = {
            "Authorization": f"Key {settings.onesignal_api_key}",
            "Content-Type": "application/json",
        }
        notifications_url = f"{settings.onesignal_api_base_url.rstrip('/')}/notifications?c=push"

        with httpx.Client(timeout=15.0) as client:
            for event in events:
                event.attempts += 1
                try:
                    payload = json.loads(event.payload)
                    response = client.post(
                        notifications_url,
                        headers=headers,
                        json={
                            "app_id": settings.onesignal_app_id,
                            "target_channel": "push",
                            "include_aliases": {
                                "external_id": [payload["recipient_user_id"]],
                            },
                            "headings": {"en": payload["title"]},
                            "contents": {"en": payload["body"]},
                            "web_url": (
                                f"{settings.normalized_frontend_public_base_url}/#/app/notifications"
                            ),
                            "data": {
                                "notificationId": payload["notification_id"],
                                "kind": payload["kind"],
                                "resourceType": payload.get("resource_type"),
                                "resourceId": payload.get("resource_id"),
                            },
                        },
                    )
                    response.raise_for_status()
                    event.processed_at = datetime.now(timezone.utc)
                    event.last_error = None
                    sent += 1
                except Exception as exc:
                    event.last_error = str(exc)[:500]
                    failed += 1
                session.add(event)

        session.commit()
    return {
        "status": "ok",
        "processed": sent + failed,
        "sent": sent,
        "failed": failed,
    }