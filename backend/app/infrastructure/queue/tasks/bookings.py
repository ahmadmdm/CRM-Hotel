from __future__ import annotations

from app.infrastructure.queue.celery_app import celery_app


@celery_app.task(name="app.infrastructure.queue.tasks.bookings.reconcile_booking_and_unit_states")
def reconcile_booking_and_unit_states() -> dict[str, str]:
    return {"status": "scheduled"}
