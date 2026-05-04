from __future__ import annotations

from datetime import datetime, timedelta, timezone

from app.core.security import create_access_token
from tests.conftest import create_client

AUTH_HEADERS = {
    "Authorization": "Bearer "
    + create_access_token(
        subject="admin@crmhotel.example.com",
        user_id="test-super-admin",
        full_name="Test Super Admin",
        roles=["super_admin"],
        expires_delta=timedelta(minutes=60),
    )
}


def test_booking_check_in_and_check_out_drive_unit_status() -> None:
    client = create_client()

    unit_response = client.post(
        "/api/v1/units",
        headers=AUTH_HEADERS,
        json={
            "code": "U-101",
            "name": "Unit 101",
            "city": "Riyadh",
        },
    )
    assert unit_response.status_code == 200
    unit = unit_response.json()

    check_in_at = datetime.now(timezone.utc) + timedelta(days=1)
    check_out_at = check_in_at + timedelta(days=2)
    booking_response = client.post(
        "/api/v1/bookings",
        headers=AUTH_HEADERS,
        json={
            "unit_id": unit["id"],
            "client_name": "Test Client",
            "client_phone": "+966500000000",
            "check_in_at": check_in_at.isoformat(),
            "check_out_at": check_out_at.isoformat(),
            "base_amount": 1000,
            "total_amount": 1150,
            "outstanding_amount": 1150,
        },
    )
    assert booking_response.status_code == 200
    booking = booking_response.json()

    check_in_response = client.post(
        f"/api/v1/bookings/{booking['id']}/check-in", headers=AUTH_HEADERS
    )
    assert check_in_response.status_code == 200
    assert check_in_response.json()["unit_status"] == "occupied"

    check_out_response = client.post(
        f"/api/v1/bookings/{booking['id']}/check-out", headers=AUTH_HEADERS
    )
    assert check_out_response.status_code == 200
    assert check_out_response.json()["unit_status"] == "pending_cleaning"
