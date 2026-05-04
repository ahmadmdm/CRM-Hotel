from __future__ import annotations

from app.core.access_control import default_permission_codes_for_roles
from tests.conftest import create_client


def test_login_and_me_return_seeded_user_profile() -> None:
    client = create_client(seed=True)

    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "admin@crmhotel.example.com",
            "password": "ChangeMe123!",
        },
    )

    assert login_response.status_code == 200
    payload = login_response.json()
    assert payload["roles"] == ["super_admin"]
    assert payload["permissions"] == default_permission_codes_for_roles(["super_admin"])
    assert payload["user"]["email"] == "admin@crmhotel.example.com"
    assert payload["user"]["permissions"] == default_permission_codes_for_roles([
        "super_admin"
    ])

    me_response = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {payload['access_token']}"},
    )
    assert me_response.status_code == 200
    assert me_response.json()["full_name"] == "Super Admin"
    assert me_response.json()["permissions"] == default_permission_codes_for_roles([
        "super_admin"
    ])
    assert me_response.json()["assigned_unit_ids"] == []


def test_scoped_user_auth_responses_include_assigned_units() -> None:
    client = create_client(seed=True)

    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "operations@crmhotel.example.com",
            "password": "ChangeMe123!",
        },
    )

    assert login_response.status_code == 200
    payload = login_response.json()
    assert payload["roles"] == ["operations"]
    assert len(payload["assigned_unit_ids"]) == 3
    assert payload["assigned_unit_ids"] == payload["user"]["assigned_unit_ids"]

    me_response = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {payload['access_token']}"},
    )
    assert me_response.status_code == 200
    assert me_response.json()["assigned_unit_ids"] == payload["assigned_unit_ids"]

    refresh_response = client.post(
        "/api/v1/auth/refresh",
        headers={"Authorization": f"Bearer {payload['access_token']}"},
    )
    assert refresh_response.status_code == 200
    assert refresh_response.json()["assigned_unit_ids"] == payload["assigned_unit_ids"]
