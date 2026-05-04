from __future__ import annotations

from datetime import datetime, timedelta, timezone

from app.core.access_control import ROLE_PERMISSION_CODES
from app.core.security import create_access_token
from tests.conftest import create_client


def _auth_headers(*, user_id: str, email: str, full_name: str, roles: list[str]) -> dict[str, str]:
    return {
        "Authorization": "Bearer "
        + create_access_token(
            subject=email,
            user_id=user_id,
            full_name=full_name,
            roles=roles,
            expires_delta=timedelta(minutes=60),
        )
    }


SUPER_ADMIN_HEADERS = _auth_headers(
    user_id="test-super-admin",
    email="admin@crmhotel.example.com",
    full_name="Test Super Admin",
    roles=["super_admin"],
)

SUB_ADMIN_HEADERS = _auth_headers(
    user_id="test-sub-admin",
    email="subadmin@crmhotel.example.com",
    full_name="Test Sub Admin",
    roles=["sub_admin"],
)


def _login_headers(client, email: str) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": email,
            "password": "ChangeMe123!",
        },
    )
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def test_super_admin_can_update_user_access_and_login_reflects_effective_permissions() -> None:
    client = create_client(seed=True)

    initial_financial_login = client.post(
        "/api/v1/auth/login",
        json={
            "email": "financial@crmhotel.example.com",
            "password": "ChangeMe123!",
        },
    )
    assert initial_financial_login.status_code == 200
    denied_unit_create_response = client.post(
        "/api/v1/units",
        headers={
            "Authorization": f"Bearer {initial_financial_login.json()['access_token']}"
        },
        json={
            "code": "U-660",
            "name": "Restricted Unit",
            "city": "Riyadh",
        },
    )
    assert denied_unit_create_response.status_code == 403

    catalog_response = client.get(
        "/api/v1/access/permissions-catalog",
        headers=SUPER_ADMIN_HEADERS,
    )
    assert catalog_response.status_code == 200
    assert {item["code"] for item in catalog_response.json()} >= {
        "users.manage_access",
        "units.manage",
    }

    users_response = client.get("/api/v1/users", headers=SUPER_ADMIN_HEADERS)
    assert users_response.status_code == 200
    financial_user = next(
        item for item in users_response.json() if item["email"] == "financial@crmhotel.example.com"
    )
    units_response = client.get("/api/v1/units", headers=SUPER_ADMIN_HEADERS)
    assert units_response.status_code == 200
    palm_suite = next(
        item for item in units_response.json()["items"] if item["code"] == "U-101"
    )

    update_response = client.patch(
        f"/api/v1/users/{financial_user['id']}/access",
        headers=SUPER_ADMIN_HEADERS,
        json={
            "role_codes": ["financial"],
            "overrides": [
                {
                    "permission_code": "units.manage",
                    "effect": "allow",
                }
            ],
            "assigned_unit_ids": [palm_suite["id"]],
        },
    )
    assert update_response.status_code == 200
    updated_access = update_response.json()
    assert updated_access["role_codes"] == ["financial"]
    assert set(updated_access["inherited_permissions"]) == set(
        ROLE_PERMISSION_CODES["financial"]
    )
    assert "units.manage" in updated_access["effective_permissions"]
    assert updated_access["assigned_unit_ids"] == [palm_suite["id"]]
    assert [unit["code"] for unit in updated_access["assigned_units"]] == ["U-101"]

    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "financial@crmhotel.example.com",
            "password": "ChangeMe123!",
        },
    )
    assert login_response.status_code == 200
    assert "units.manage" in login_response.json()["permissions"]

    granted_unit_create_response = client.post(
        "/api/v1/units",
        headers={"Authorization": f"Bearer {login_response.json()['access_token']}"},
        json={
            "code": "U-661",
            "name": "Permitted Unit",
            "city": "Jeddah",
        },
    )
    assert granted_unit_create_response.status_code == 200


def test_unit_scoped_operations_routes_are_filtered_by_assignment() -> None:
    client = create_client(seed=True)

    users_response = client.get("/api/v1/users", headers=SUPER_ADMIN_HEADERS)
    assert users_response.status_code == 200
    operations_user = next(
        item for item in users_response.json() if item["email"] == "ops@crmhotel.example.com"
    )

    units_response = client.get("/api/v1/units", headers=SUPER_ADMIN_HEADERS)
    assert units_response.status_code == 200
    target_unit = next(item for item in units_response.json()["items"] if item["code"] == "U-203")
    blocked_unit = next(item for item in units_response.json()["items"] if item["code"] == "U-301")

    update_response = client.patch(
        f"/api/v1/users/{operations_user['id']}/access",
        headers=SUPER_ADMIN_HEADERS,
        json={
            "role_codes": ["operations"],
            "overrides": [],
            "assigned_unit_ids": [target_unit["id"]],
        },
    )
    assert update_response.status_code == 200

    operations_headers = _login_headers(client, "ops@crmhotel.example.com")
    scoped_units_response = client.get("/api/v1/units", headers=operations_headers)
    assert scoped_units_response.status_code == 200
    assert [item["code"] for item in scoped_units_response.json()["items"]] == ["U-203"]

    scoped_bookings_response = client.get("/api/v1/bookings", headers=operations_headers)
    assert scoped_bookings_response.status_code == 200
    assert len(scoped_bookings_response.json()["items"]) == 1

    dashboard_response = client.get("/api/v1/reports/dashboard", headers=operations_headers)
    assert dashboard_response.status_code == 200
    assert dashboard_response.json()["total_units"] == 1
    assert dashboard_response.json()["active_bookings"] == 1

    denied_booking_response = client.post(
        "/api/v1/bookings",
        headers=operations_headers,
        json={
            "unit_id": blocked_unit["id"],
            "client_name": "Scoped User",
            "client_phone": "+966500000001",
            "check_in_at": "2026-05-10T14:00:00Z",
            "check_out_at": "2026-05-12T11:00:00Z",
            "guest_count": 2,
            "base_amount": 500,
            "tax_amount": 75,
            "security_deposit": 0,
            "total_amount": 575,
            "outstanding_amount": 575,
        },
    )
    assert denied_booking_response.status_code == 403
    assert denied_booking_response.json()["error"]["code"] == "UNIT_ACCESS_FORBIDDEN"


def test_unit_scoped_finance_routes_are_filtered_by_assignment() -> None:
    client = create_client(seed=True)

    users_response = client.get("/api/v1/users", headers=SUPER_ADMIN_HEADERS)
    assert users_response.status_code == 200
    financial_user = next(
        item for item in users_response.json() if item["email"] == "financial@crmhotel.example.com"
    )

    units_response = client.get("/api/v1/units", headers=SUPER_ADMIN_HEADERS)
    assert units_response.status_code == 200
    allowed_unit = next(item for item in units_response.json()["items"] if item["code"] == "U-101")
    blocked_unit = next(item for item in units_response.json()["items"] if item["code"] == "U-301")

    update_response = client.patch(
        f"/api/v1/users/{financial_user['id']}/access",
        headers=SUPER_ADMIN_HEADERS,
        json={
            "role_codes": ["financial"],
            "overrides": [],
            "assigned_unit_ids": [allowed_unit["id"]],
        },
    )
    assert update_response.status_code == 200

    financial_headers = _login_headers(client, "financial@crmhotel.example.com")
    finance_payments_response = client.get(
        "/api/v1/finance/payments",
        headers=financial_headers,
    )
    assert finance_payments_response.status_code == 200
    assert len(finance_payments_response.json()) == 1

    finance_expenses_response = client.get(
        "/api/v1/finance/expenses",
        headers=financial_headers,
    )
    assert finance_expenses_response.status_code == 200
    assert len(finance_expenses_response.json()) == 0

    denied_expense_response = client.post(
        "/api/v1/finance/expenses",
        headers=financial_headers,
        json={
            "category": "out-of-scope",
            "amount": 200,
            "description": "Blocked expense",
            "unit_id": blocked_unit["id"],
        },
    )
    assert denied_expense_response.status_code == 403
    assert denied_expense_response.json()["error"]["code"] == "UNIT_ACCESS_FORBIDDEN"

    allowed_expense_response = client.post(
        "/api/v1/finance/expenses",
        headers=financial_headers,
        json={
            "category": "allowed-scope",
            "amount": 180,
            "description": "Allowed expense",
            "unit_id": allowed_unit["id"],
        },
    )
    assert allowed_expense_response.status_code == 200
    assert allowed_expense_response.json()["unit_id"] == allowed_unit["id"]


def test_unit_scoped_worker_routes_reject_out_of_scope_tasks_and_tickets() -> None:
    client = create_client(seed=True)

    users_response = client.get("/api/v1/users", headers=SUPER_ADMIN_HEADERS)
    assert users_response.status_code == 200
    users_payload = users_response.json()
    maintenance_user = next(
        item for item in users_payload if item["email"] == "maintenance@crmhotel.example.com"
    )
    housekeeping_user = next(
        item for item in users_payload if item["email"] == "housekeeping@crmhotel.example.com"
    )

    units_response = client.get("/api/v1/units", headers=SUPER_ADMIN_HEADERS)
    assert units_response.status_code == 200
    out_of_scope_unit = next(
        item for item in units_response.json()["items"] if item["code"] == "U-101"
    )

    maintenance_update = client.patch(
        f"/api/v1/users/{maintenance_user['id']}/access",
        headers=SUPER_ADMIN_HEADERS,
        json={
            "role_codes": ["maintenance"],
            "overrides": [],
            "assigned_unit_ids": [out_of_scope_unit["id"]],
        },
    )
    assert maintenance_update.status_code == 200

    housekeeping_update = client.patch(
        f"/api/v1/users/{housekeeping_user['id']}/access",
        headers=SUPER_ADMIN_HEADERS,
        json={
            "role_codes": ["housekeeping"],
            "overrides": [],
            "assigned_unit_ids": [out_of_scope_unit["id"]],
        },
    )
    assert housekeeping_update.status_code == 200

    ticket_list = client.get("/api/v1/maintenance/tickets", headers=SUPER_ADMIN_HEADERS)
    assert ticket_list.status_code == 200
    ticket_id = ticket_list.json()[0]["id"]

    task_list = client.get("/api/v1/housekeeping/tasks", headers=SUPER_ADMIN_HEADERS)
    assert task_list.status_code == 200
    task_id = task_list.json()[0]["id"]

    maintenance_headers = _login_headers(client, "maintenance@crmhotel.example.com")
    housekeeping_headers = _login_headers(client, "housekeeping@crmhotel.example.com")

    scoped_ticket_list = client.get("/api/v1/maintenance/tickets", headers=maintenance_headers)
    assert scoped_ticket_list.status_code == 200
    assert scoped_ticket_list.json() == []

    resolve_ticket_response = client.post(
        f"/api/v1/maintenance/tickets/{ticket_id}/resolve",
        headers=maintenance_headers,
    )
    assert resolve_ticket_response.status_code == 403
    assert resolve_ticket_response.json()["error"]["code"] == "UNIT_ACCESS_FORBIDDEN"

    scoped_task_list = client.get("/api/v1/housekeeping/tasks", headers=housekeeping_headers)
    assert scoped_task_list.status_code == 200
    assert scoped_task_list.json() == []

    complete_task_response = client.post(
        f"/api/v1/housekeeping/tasks/{task_id}/complete",
        headers=housekeeping_headers,
    )
    assert complete_task_response.status_code == 403
    assert complete_task_response.json()["error"]["code"] == "UNIT_ACCESS_FORBIDDEN"


def test_housekeeping_and_maintenance_assignments_support_unassigned_and_specific_staff() -> None:
    client = create_client(seed=True)

    users_response = client.get("/api/v1/users", headers=SUPER_ADMIN_HEADERS)
    assert users_response.status_code == 200
    users_by_email = {item["email"]: item for item in users_response.json()}

    units_response = client.get("/api/v1/units", headers=SUPER_ADMIN_HEADERS)
    assert units_response.status_code == 200
    units_by_code = {item["code"]: item for item in units_response.json()["items"]}

    housekeeping_assignees = client.get(
        f"/api/v1/housekeeping/assignees?unit_id={units_by_code['U-114']['id']}",
        headers=SUPER_ADMIN_HEADERS,
    )
    assert housekeeping_assignees.status_code == 200
    assert {
        item["email"]
        for item in housekeeping_assignees.json()
        if item["target_type"] == "user"
    } >= {"hk@crmhotel.example.com", "housekeeping@crmhotel.example.com"}
    assert any(
        item["target_type"] == "team" for item in housekeeping_assignees.json()
    )

    unassigned_task_response = client.post(
        "/api/v1/housekeeping/tasks",
        headers=SUPER_ADMIN_HEADERS,
        json={
            "unit_id": units_by_code["U-114"]["id"],
            "priority": "high",
            "notes": "Refresh linens for shared coverage",
        },
    )
    assert unassigned_task_response.status_code == 200

    assigned_task_response = client.post(
        "/api/v1/housekeeping/tasks",
        headers=SUPER_ADMIN_HEADERS,
        json={
            "unit_id": units_by_code["U-114"]["id"],
            "priority": "urgent",
            "notes": "VIP turnover",
            "assigned_user_id": users_by_email["housekeeping@crmhotel.example.com"]["id"],
        },
    )
    assert assigned_task_response.status_code == 200
    assert (
        assigned_task_response.json()["assigned_user_email"]
        == "housekeeping@crmhotel.example.com"
    )

    shared_housekeeping_headers = _login_headers(client, "hk@crmhotel.example.com")
    scoped_housekeeping_headers = _login_headers(client, "housekeeping@crmhotel.example.com")

    hk_tasks_response = client.get(
        "/api/v1/housekeeping/tasks",
        headers=shared_housekeeping_headers,
    )
    assert hk_tasks_response.status_code == 200
    hk_task_ids = {item["id"] for item in hk_tasks_response.json()}
    assert unassigned_task_response.json()["id"] in hk_task_ids
    assert assigned_task_response.json()["id"] not in hk_task_ids

    scoped_tasks_response = client.get(
        "/api/v1/housekeeping/tasks",
        headers=scoped_housekeeping_headers,
    )
    assert scoped_tasks_response.status_code == 200
    scoped_task_ids = {item["id"] for item in scoped_tasks_response.json()}
    assert unassigned_task_response.json()["id"] in scoped_task_ids
    assert assigned_task_response.json()["id"] in scoped_task_ids

    reassign_response = client.patch(
        f"/api/v1/housekeeping/tasks/{unassigned_task_response.json()['id']}/assignee",
        headers=SUPER_ADMIN_HEADERS,
        json={"assigned_user_id": users_by_email["hk@crmhotel.example.com"]["id"]},
    )
    assert reassign_response.status_code == 200
    assert reassign_response.json()["assigned_user_email"] == "hk@crmhotel.example.com"

    maintenance_user_update = client.patch(
        f"/api/v1/users/{users_by_email['hk@crmhotel.example.com']['id']}/access",
        headers=SUPER_ADMIN_HEADERS,
        json={
            "role_codes": ["maintenance"],
            "overrides": [],
            "assigned_unit_ids": [units_by_code["U-301"]["id"]],
        },
    )
    assert maintenance_user_update.status_code == 200

    maintenance_assignees = client.get(
        f"/api/v1/maintenance/assignees?unit_id={units_by_code['U-301']['id']}",
        headers=SUPER_ADMIN_HEADERS,
    )
    assert maintenance_assignees.status_code == 200
    assert {
        item["email"]
        for item in maintenance_assignees.json()
        if item["target_type"] == "user"
    } >= {
        "maintenance@crmhotel.example.com",
        "hk@crmhotel.example.com",
    }
    assert any(item["target_type"] == "team" for item in maintenance_assignees.json())

    unassigned_ticket_response = client.post(
        "/api/v1/maintenance/tickets",
        headers=SUPER_ADMIN_HEADERS,
        json={
            "unit_id": units_by_code["U-301"]["id"],
            "title": "Lobby sensor calibration",
            "priority": "high",
        },
    )
    assert unassigned_ticket_response.status_code == 200

    assigned_ticket_response = client.post(
        "/api/v1/maintenance/tickets",
        headers=SUPER_ADMIN_HEADERS,
        json={
            "unit_id": units_by_code["U-301"]["id"],
            "title": "Replace terrace fuse",
            "priority": "urgent",
            "assigned_user_id": users_by_email["maintenance@crmhotel.example.com"]["id"],
        },
    )
    assert assigned_ticket_response.status_code == 200
    assert (
        assigned_ticket_response.json()["assigned_user_email"]
        == "maintenance@crmhotel.example.com"
    )

    shared_maintenance_headers = _login_headers(client, "hk@crmhotel.example.com")
    scoped_maintenance_headers = _login_headers(client, "maintenance@crmhotel.example.com")

    shared_tickets_response = client.get(
        "/api/v1/maintenance/tickets",
        headers=shared_maintenance_headers,
    )
    assert shared_tickets_response.status_code == 200
    shared_ticket_ids = {item["id"] for item in shared_tickets_response.json()}
    assert unassigned_ticket_response.json()["id"] in shared_ticket_ids
    assert assigned_ticket_response.json()["id"] not in shared_ticket_ids

    scoped_tickets_response = client.get(
        "/api/v1/maintenance/tickets",
        headers=scoped_maintenance_headers,
    )
    assert scoped_tickets_response.status_code == 200
    scoped_ticket_ids = {item["id"] for item in scoped_tickets_response.json()}
    assert unassigned_ticket_response.json()["id"] in scoped_ticket_ids
    assert assigned_ticket_response.json()["id"] in scoped_ticket_ids

    blocked_resolve_response = client.post(
        f"/api/v1/maintenance/tickets/{assigned_ticket_response.json()['id']}/resolve",
        headers=shared_maintenance_headers,
    )
    assert blocked_resolve_response.status_code == 403
    assert blocked_resolve_response.json()["error"]["code"] == "TICKET_ASSIGNED_TO_ANOTHER_USER"


def test_operation_team_membership_extends_scope_and_supports_team_assignment() -> None:
    client = create_client(seed=True)

    users_response = client.get("/api/v1/users", headers=SUPER_ADMIN_HEADERS)
    assert users_response.status_code == 200
    users_by_email = {item["email"]: item for item in users_response.json()}

    units_response = client.get("/api/v1/units", headers=SUPER_ADMIN_HEADERS)
    assert units_response.status_code == 200
    units_by_code = {item["code"]: item for item in units_response.json()["items"]}

    create_team_response = client.post(
        "/api/v1/access/operation-teams",
        headers=SUPER_ADMIN_HEADERS,
        json={
            "name": "Overflow Housekeeping Team",
            "operation_type": "housekeeping",
            "description": "Support team for overflow housekeeping demand.",
            "unit_ids": [units_by_code["U-203"]["id"]],
            "member_user_ids": [users_by_email["hk@crmhotel.example.com"]["id"]],
            "is_active": True,
        },
    )
    assert create_team_response.status_code == 200
    team_id = create_team_response.json()["id"]

    hk_headers = _login_headers(client, "hk@crmhotel.example.com")
    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "hk@crmhotel.example.com",
            "password": "ChangeMe123!",
        },
    )
    assert login_response.status_code == 200
    assert units_by_code["U-203"]["id"] in login_response.json()["assigned_unit_ids"]

    housekeeping_assignees = client.get(
        f"/api/v1/housekeeping/assignees?unit_id={units_by_code['U-203']['id']}",
        headers=SUPER_ADMIN_HEADERS,
    )
    assert housekeeping_assignees.status_code == 200
    assert any(
        item["target_type"] == "team" and item["id"] == team_id
        for item in housekeeping_assignees.json()
    )

    create_task_response = client.post(
        "/api/v1/housekeeping/tasks",
        headers=SUPER_ADMIN_HEADERS,
        json={
            "unit_id": units_by_code["U-203"]["id"],
            "priority": "high",
            "notes": "Cluster handover clean",
            "assigned_team_id": team_id,
        },
    )
    assert create_task_response.status_code == 200
    assert create_task_response.json()["assigned_team_name"] == "Overflow Housekeeping Team"

    hk_tasks_response = client.get("/api/v1/housekeeping/tasks", headers=hk_headers)
    assert hk_tasks_response.status_code == 200
    assert create_task_response.json()["id"] in {
        item["id"] for item in hk_tasks_response.json()
    }

    teams_response = client.get(
        "/api/v1/access/operation-teams",
        headers=SUPER_ADMIN_HEADERS,
    )
    assert teams_response.status_code == 200
    overflow_team = next(
        item for item in teams_response.json() if item["id"] == team_id
    )
    assert overflow_team["kpis"]["open_work_items"] == 1

    complete_response = client.post(
        f"/api/v1/housekeeping/tasks/{create_task_response.json()['id']}/complete",
        headers=hk_headers,
    )
    assert complete_response.status_code == 200
    assert complete_response.json()["status"] == "completed"

    refreshed_teams_response = client.get(
        "/api/v1/access/operation-teams",
        headers=SUPER_ADMIN_HEADERS,
    )
    assert refreshed_teams_response.status_code == 200
    refreshed_team = next(
        item for item in refreshed_teams_response.json() if item["id"] == team_id
    )
    assert refreshed_team["kpis"]["open_work_items"] == 0
    assert refreshed_team["kpis"]["average_close_hours"] >= 0


def test_finance_cost_centers_include_profit_loss_and_depreciation() -> None:
    client = create_client(seed=True)

    response = client.get("/api/v1/finance/cost-centers", headers=SUPER_ADMIN_HEADERS)
    assert response.status_code == 200
    centers = {item["unit_code"]: item for item in response.json()}

    assert centers["U-114"]["revenue"] == 1380
    assert centers["U-114"]["expenses"] == 120
    assert centers["U-114"]["capital_expenditure"] == 0
    assert centers["U-114"]["depreciation"] == 950
    assert centers["U-114"]["profit_loss"] == 310
    assert centers["U-114"]["asset_count"] == 1


def test_finance_period_filters_and_asset_registration_update_cost_centers() -> None:
    client = create_client(seed=True)

    units_response = client.get("/api/v1/units", headers=SUPER_ADMIN_HEADERS)
    assert units_response.status_code == 200
    units_by_code = {item["code"]: item for item in units_response.json()["items"]}

    create_asset_response = client.post(
        "/api/v1/finance/assets",
        headers=SUPER_ADMIN_HEADERS,
        json={
            "unit_id": units_by_code["U-101"]["id"],
            "name": "Pool Pump Retrofit",
            "category": "equipment",
            "acquisition_cost": 2400,
            "residual_value": 0,
            "useful_life_months": 12,
            "commissioned_at": datetime.now(timezone.utc).isoformat(),
        },
    )
    assert create_asset_response.status_code == 200
    assert create_asset_response.json()["monthly_depreciation"] == 200

    assets_response = client.get(
        "/api/v1/finance/assets?period=month",
        headers=SUPER_ADMIN_HEADERS,
    )
    assert assets_response.status_code == 200
    assert any(item["name"] == "Pool Pump Retrofit" for item in assets_response.json())

    current_centers_response = client.get(
        "/api/v1/finance/cost-centers?period=month",
        headers=SUPER_ADMIN_HEADERS,
    )
    assert current_centers_response.status_code == 200
    current_centers = {item["unit_code"]: item for item in current_centers_response.json()}
    assert current_centers["U-101"]["capital_expenditure"] >= 2400
    assert current_centers["U-101"]["depreciation"] >= 2000

    future_centers_response = client.get(
        "/api/v1/finance/cost-centers?period=month&anchor_date=2028-01-15",
        headers=SUPER_ADMIN_HEADERS,
    )
    assert future_centers_response.status_code == 200
    future_centers = {item["unit_code"]: item for item in future_centers_response.json()}
    assert future_centers["U-101"]["revenue"] == 0
    assert future_centers["U-101"]["expenses"] == 0
    assert future_centers["U-101"]["depreciation"] == 0


def test_sub_admin_cannot_grant_admin_access_or_edit_admin_accounts() -> None:
    client = create_client(seed=True)

    users_response = client.get("/api/v1/users", headers=SUB_ADMIN_HEADERS)
    assert users_response.status_code == 200
    payload = users_response.json()
    super_admin = next(item for item in payload if item["email"] == "admin@crmhotel.example.com")
    financial_user = next(
        item for item in payload if item["email"] == "financial@crmhotel.example.com"
    )

    edit_super_admin_response = client.patch(
        f"/api/v1/users/{super_admin['id']}/access",
        headers=SUB_ADMIN_HEADERS,
        json={"role_codes": ["super_admin"], "overrides": []},
    )
    assert edit_super_admin_response.status_code == 403
    assert edit_super_admin_response.json()["error"]["code"] == "CANNOT_EDIT_ADMIN_ACCESS"

    grant_admin_permission_response = client.patch(
        f"/api/v1/users/{financial_user['id']}/access",
        headers=SUB_ADMIN_HEADERS,
        json={
            "role_codes": ["financial"],
            "overrides": [
                {
                    "permission_code": "users.manage_access",
                    "effect": "allow",
                }
            ],
        },
    )
    assert grant_admin_permission_response.status_code == 403
    assert (
        grant_admin_permission_response.json()["error"]["code"]
        == "PERMISSION_ASSIGNMENT_FORBIDDEN"
    )