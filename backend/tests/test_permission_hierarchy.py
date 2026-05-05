from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from sqlmodel import Session, select

from app.core.access_control import (
    PERMISSION_CATALOG,
    ROLE_PERMISSION_CODES,
    get_access_profile_for_user,
)
from app.core.db import engine
from app.infrastructure.persistence.models import Booking, HousekeepingTask, Unit, User
from tests.conftest import create_client


def _auth_headers_for_login(client, email: str) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "ChangeMe123!"},
    )
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def _permission_audit_email(permission_code: str) -> str:
    return f"perm-{permission_code.replace('.', '-')}@crmhotel.example.com"


def _seeded_resource_ids() -> dict[str, str]:
    with Session(engine) as session:
        confirmed_booking = session.exec(
            select(Booking).where(Booking.status == "confirmed")
        ).first()
        first_unit = session.exec(select(Unit).order_by(Unit.code)).first()
        housekeeping_unit = session.exec(
            select(Unit).where(Unit.code == "U-114")
        ).first()
        housekeeping_task = session.exec(
            select(HousekeepingTask)
            .where(
                HousekeepingTask.assigned_user_id.is_(None),
                HousekeepingTask.unit_id
                == (
                    housekeeping_unit.id if housekeeping_unit else first_unit.id
                ),
            )
            .order_by(HousekeepingTask.created_at.desc())
        ).first()
        financial_user = session.exec(
            select(User).where(User.email == "financial@crmhotel.example.com")
        ).first()
        access_audit_user = session.exec(
            select(User).where(User.email == _permission_audit_email("dashboard.view"))
        ).first()
        assert confirmed_booking is not None
        assert first_unit is not None
        assert financial_user is not None
        assert access_audit_user is not None
        housekeeping_target_unit = housekeeping_unit or first_unit
        if housekeeping_task is None:
            housekeeping_task = HousekeepingTask(
                unit_id=housekeeping_target_unit.id,
                booking_id=confirmed_booking.id,
            )
            session.add(housekeeping_task)
            session.commit()
        return {
            "confirmed_booking_id": confirmed_booking.id,
            "housekeeping_task_id": housekeeping_task.id,
            "unit_id": first_unit.id,
            "financial_user_id": financial_user.id,
            "access_audit_user_id": access_audit_user.id,
        }


def _request_json(
    client,
    method: str,
    path: str,
    *,
    headers: dict[str, str],
    json: dict | None = None,
):
    return client.request(method, path, headers=headers, json=json)


def test_seed_creates_single_permission_audit_users() -> None:
    create_client(seed=True)

    with Session(engine) as session:
        for definition in PERMISSION_CATALOG:
            user = session.exec(
                select(User).where(User.email == _permission_audit_email(definition.code))
            ).first()
            assert user is not None
            access_profile = get_access_profile_for_user(session, user.id)
            assert access_profile.role_codes == []
            assert access_profile.inherited_permission_codes == []
            assert access_profile.effective_permission_codes == [definition.code]


@dataclass(frozen=True)
class PermissionScenario:
    permission_code: str
    allowed_method: str
    allowed_path: str
    denied_method: str
    denied_path: str
    allowed_payload: dict | None = None
    denied_payload: dict | None = None


def test_permission_audit_users_can_only_access_their_assigned_slice() -> None:
    client = create_client(seed=True)
    seeded_ids = _seeded_resource_ids()
    check_in_at = datetime.now(timezone.utc) + timedelta(days=30)
    check_out_at = check_in_at + timedelta(days=2)

    scenarios = [
        PermissionScenario(
            permission_code="dashboard.view",
            allowed_method="GET",
            allowed_path="/api/v1/reports/dashboard",
            denied_method="GET",
            denied_path="/api/v1/users",
        ),
        PermissionScenario(
            permission_code="units.view",
            allowed_method="GET",
            allowed_path="/api/v1/units",
            denied_method="POST",
            denied_path="/api/v1/units",
            denied_payload={"code": "U-950", "name": "Blocked Unit", "city": "Riyadh"},
        ),
        PermissionScenario(
            permission_code="units.manage",
            allowed_method="POST",
            allowed_path="/api/v1/units",
            allowed_payload={"code": "U-951", "name": "Managed Unit", "city": "Riyadh"},
            denied_method="GET",
            denied_path="/api/v1/bookings",
        ),
        PermissionScenario(
            permission_code="bookings.view",
            allowed_method="GET",
            allowed_path="/api/v1/bookings",
            denied_method="GET",
            denied_path="/api/v1/units",
        ),
        PermissionScenario(
            permission_code="bookings.manage",
            allowed_method="POST",
            allowed_path="/api/v1/bookings",
            allowed_payload={
                "unit_id": seeded_ids["unit_id"],
                "client_name": "Permission Booking",
                "client_phone": "+966500001111",
                "check_in_at": check_in_at.isoformat(),
                "check_out_at": check_out_at.isoformat(),
                "base_amount": 1000,
                "total_amount": 1150,
                "outstanding_amount": 1150,
            },
            denied_method="GET",
            denied_path="/api/v1/clients",
        ),
        PermissionScenario(
            permission_code="crm.view",
            allowed_method="GET",
            allowed_path="/api/v1/clients",
            denied_method="GET",
            denied_path="/api/v1/finance/payments",
        ),
        PermissionScenario(
            permission_code="crm.manage",
            allowed_method="POST",
            allowed_path="/api/v1/clients",
            allowed_payload={"full_name": "Audit Client", "phone": "+966500002222"},
            denied_method="GET",
            denied_path="/api/v1/finance/payments",
        ),
        PermissionScenario(
            permission_code="finance.view",
            allowed_method="GET",
            allowed_path="/api/v1/finance/payments",
            denied_method="POST",
            denied_path="/api/v1/finance/payments",
            denied_payload={"amount": 100, "method": "cash"},
        ),
        PermissionScenario(
            permission_code="finance.manage",
            allowed_method="POST",
            allowed_path="/api/v1/finance/expenses",
            allowed_payload={"category": "audit", "amount": 90, "description": "Audit expense"},
            denied_method="GET",
            denied_path="/api/v1/users",
        ),
        PermissionScenario(
            permission_code="housekeeping.view",
            allowed_method="GET",
            allowed_path="/api/v1/housekeeping/tasks",
            denied_method="POST",
            denied_path=f"/api/v1/housekeeping/tasks/{seeded_ids['housekeeping_task_id']}/complete",
        ),
        PermissionScenario(
            permission_code="housekeeping.complete",
            allowed_method="POST",
            allowed_path=f"/api/v1/housekeeping/tasks/{seeded_ids['housekeeping_task_id']}/complete",
            denied_method="GET",
            denied_path="/api/v1/maintenance/tickets",
        ),
        PermissionScenario(
            permission_code="maintenance.view",
            allowed_method="GET",
            allowed_path="/api/v1/maintenance/tickets",
            denied_method="POST",
            denied_path="/api/v1/maintenance/tickets",
            denied_payload={"unit_id": seeded_ids["unit_id"], "title": "Blocked Ticket"},
        ),
        PermissionScenario(
            permission_code="maintenance.manage",
            allowed_method="POST",
            allowed_path="/api/v1/maintenance/tickets",
            allowed_payload={"unit_id": seeded_ids["unit_id"], "title": "Audit Ticket"},
            denied_method="GET",
            denied_path="/api/v1/clients",
        ),
        PermissionScenario(
            permission_code="reports.view",
            allowed_method="GET",
            allowed_path="/api/v1/reports/summary",
            denied_method="GET",
            denied_path="/api/v1/users",
        ),
        PermissionScenario(
            permission_code="users.view",
            allowed_method="GET",
            allowed_path="/api/v1/users",
            denied_method="POST",
            denied_path="/api/v1/finance/expenses",
            denied_payload={"category": "blocked", "amount": 33},
        ),
        PermissionScenario(
            permission_code="users.manage_access",
            allowed_method="PATCH",
            allowed_path=f"/api/v1/users/{seeded_ids['financial_user_id']}/access",
            allowed_payload={
                "role_codes": ["financial"],
                "overrides": [{"permission_code": "units.view", "effect": "allow"}],
            },
            denied_method="GET",
            denied_path="/api/v1/finance/payments",
        ),
    ]

    for scenario in scenarios:
        headers = _auth_headers_for_login(client, _permission_audit_email(scenario.permission_code))
        allowed_response = _request_json(
            client,
            scenario.allowed_method,
            scenario.allowed_path,
            headers=headers,
            json=scenario.allowed_payload,
        )
        assert allowed_response.status_code == 200, scenario.permission_code

        denied_response = _request_json(
            client,
            scenario.denied_method,
            scenario.denied_path,
            headers=headers,
            json=scenario.denied_payload,
        )
        assert denied_response.status_code == 403, scenario.permission_code


def test_manage_and_complete_permissions_can_load_their_primary_lists() -> None:
    client = create_client(seed=True)

    scenarios = [
        ("units.manage", "GET", "/api/v1/units"),
        ("bookings.manage", "GET", "/api/v1/bookings"),
        ("crm.manage", "GET", "/api/v1/clients"),
        ("finance.manage", "GET", "/api/v1/finance/payments"),
        ("maintenance.manage", "GET", "/api/v1/maintenance/tickets"),
        ("housekeeping.complete", "GET", "/api/v1/housekeeping/tasks"),
        ("housekeeping.manage", "GET", "/api/v1/housekeeping/tasks"),
        ("users.manage_access", "GET", "/api/v1/users"),
        ("users.manage_access", "GET", "/api/v1/access/permissions-catalog"),
        ("users.manage_access", "GET", "/api/v1/access/operation-teams"),
    ]

    for permission_code, method, path in scenarios:
        headers = _auth_headers_for_login(client, _permission_audit_email(permission_code))
        response = client.request(method, path, headers=headers)
        assert response.status_code == 200, (permission_code, path, response.text)


def test_role_hierarchy_stays_within_expected_boundaries() -> None:
    client = create_client(seed=True)
    seeded_ids = _seeded_resource_ids()

    super_admin_headers = _auth_headers_for_login(client, "admin@crmhotel.example.com")
    sub_admin_headers = _auth_headers_for_login(client, "subadmin@crmhotel.example.com")
    financial_headers = _auth_headers_for_login(client, "financial@crmhotel.example.com")
    operations_headers = _auth_headers_for_login(client, "ops@crmhotel.example.com")
    maintenance_headers = _auth_headers_for_login(client, "maintenance@crmhotel.example.com")
    housekeeping_headers = _auth_headers_for_login(client, "hk@crmhotel.example.com")

    assert client.get("/api/v1/users", headers=super_admin_headers).status_code == 200
    assert client.get("/api/v1/reports/summary", headers=super_admin_headers).status_code == 200

    sub_admin_update_response = client.patch(
        f"/api/v1/users/{seeded_ids['financial_user_id']}/access",
        headers=sub_admin_headers,
        json={
            "role_codes": ["financial"],
            "overrides": [{"permission_code": "crm.manage", "effect": "allow"}],
        },
    )
    assert sub_admin_update_response.status_code == 200
    assert client.get("/api/v1/finance/payments", headers=sub_admin_headers).status_code == 403

    assert client.get("/api/v1/finance/payments", headers=financial_headers).status_code == 200
    assert client.post(
        "/api/v1/units",
        headers=financial_headers,
        json={"code": "U-952", "name": "Finance Blocked", "city": "Jeddah"},
    ).status_code == 403

    assert client.get("/api/v1/bookings", headers=operations_headers).status_code == 200
    assert client.get("/api/v1/users", headers=operations_headers).status_code == 403

    assert client.get("/api/v1/maintenance/tickets", headers=maintenance_headers).status_code == 200
    assert client.get("/api/v1/housekeeping/tasks", headers=maintenance_headers).status_code == 403

    assert client.get("/api/v1/housekeeping/tasks", headers=housekeeping_headers).status_code == 200
    assert (
        client.get(
            "/api/v1/maintenance/tickets",
            headers=housekeeping_headers,
        ).status_code
        == 403
    )


def test_seeded_demo_users_match_expected_role_profiles() -> None:
    create_client(seed=True)

    expected_roles = {
        "admin@crmhotel.example.com": "super_admin",
        "subadmin@crmhotel.example.com": "sub_admin",
        "financial@crmhotel.example.com": "financial",
        "ops@crmhotel.example.com": "operations",
        "operations@crmhotel.example.com": "operations",
        "maintenance@crmhotel.example.com": "maintenance",
        "hk@crmhotel.example.com": "housekeeping",
        "housekeeping@crmhotel.example.com": "housekeeping",
    }

    with Session(engine) as session:
        for email, expected_role in expected_roles.items():
            user = session.exec(select(User).where(User.email == email)).first()
            assert user is not None, email

            access_profile = get_access_profile_for_user(session, user.id)
            expected_permissions = sorted(ROLE_PERMISSION_CODES[expected_role])

            assert access_profile.role_codes == [expected_role], email
            assert access_profile.inherited_permission_codes == expected_permissions, email
            assert access_profile.effective_permission_codes == expected_permissions, email


def test_demo_users_can_complete_their_primary_role_actions() -> None:
    client = create_client(seed=True)
    seeded_ids = _seeded_resource_ids()
    check_in_at = datetime.now(timezone.utc) + timedelta(days=45)
    check_out_at = check_in_at + timedelta(days=2)

    admin_headers = _auth_headers_for_login(client, "admin@crmhotel.example.com")
    admin_response = client.get("/api/v1/users", headers=admin_headers)
    assert admin_response.status_code == 200
    assert any(
        user["email"] == "subadmin@crmhotel.example.com"
        for user in admin_response.json()
    )

    sub_admin_headers = _auth_headers_for_login(client, "subadmin@crmhotel.example.com")
    sub_admin_response = client.patch(
        f"/api/v1/users/{seeded_ids['access_audit_user_id']}/access",
        headers=sub_admin_headers,
        json={
            "role_codes": ["housekeeping"],
            "overrides": [{"permission_code": "bookings.view", "effect": "allow"}],
        },
    )
    assert sub_admin_response.status_code == 200
    assert sub_admin_response.json()["role_codes"] == ["housekeeping"]

    financial_headers = _auth_headers_for_login(client, "financial@crmhotel.example.com")
    expense_response = client.post(
        "/api/v1/finance/expenses",
        headers=financial_headers,
        json={
            "category": "audit",
            "amount": 120,
            "description": "Lifecycle expense",
            "unit_id": seeded_ids["unit_id"],
        },
    )
    assert expense_response.status_code == 200
    assert expense_response.json()["category"] == "audit"

    operations_headers = _auth_headers_for_login(client, "operations@crmhotel.example.com")
    booking_response = client.post(
        "/api/v1/bookings",
        headers=operations_headers,
        json={
            "unit_id": seeded_ids["unit_id"],
            "client_name": "Lifecycle Guest",
            "client_phone": "+966500003333",
            "check_in_at": check_in_at.isoformat(),
            "check_out_at": check_out_at.isoformat(),
            "base_amount": 1600,
            "total_amount": 1840,
            "outstanding_amount": 1840,
        },
    )
    assert booking_response.status_code == 200
    assert booking_response.json()["client_name"] == "Lifecycle Guest"

    maintenance_headers = _auth_headers_for_login(client, "maintenance@crmhotel.example.com")
    maintenance_response = client.post(
        "/api/v1/maintenance/tickets",
        headers=maintenance_headers,
        json={
            "unit_id": seeded_ids["unit_id"],
            "title": "Lifecycle AC Issue",
            "description": "Generated during lifecycle regression coverage.",
        },
    )
    assert maintenance_response.status_code == 200
    assert maintenance_response.json()["title"] == "Lifecycle AC Issue"

    housekeeping_headers = _auth_headers_for_login(client, "housekeeping@crmhotel.example.com")
    housekeeping_response = client.post(
        f"/api/v1/housekeeping/tasks/{seeded_ids['housekeeping_task_id']}/complete",
        headers=housekeeping_headers,
    )
    assert housekeeping_response.status_code == 200
    assert housekeeping_response.json()["status"] == "completed"