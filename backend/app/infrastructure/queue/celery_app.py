from __future__ import annotations

from celery import Celery

from app.core.config import get_settings

settings = get_settings()

celery_app = Celery("crmhotel", broker=settings.redis_url, backend=settings.redis_url)
celery_app.conf.task_default_queue = "operations"
celery_app.conf.beat_schedule = {
    "reconcile-booking-and-unit-states": {
        "task": "app.infrastructure.queue.tasks.bookings.reconcile_booking_and_unit_states",
        "schedule": 300.0,
    }
}
