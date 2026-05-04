from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlmodel import Session, select

from app.core.access_control import PERMISSION_CATALOG, ROLE_PERMISSION_CODES
from app.core.config import get_settings
from app.core.enums import (
    BookingStatus,
    OperationTeamType,
    PaymentStatus,
    PriorityLevel,
    TaskStatus,
    TicketStatus,
    UnitStatus,
)
from app.core.security import hash_password
from app.infrastructure.persistence.models import (
    Amenity,
    Booking,
    Client,
    Expense,
    HousekeepingTask,
    LedgerEntry,
    MaintenanceTicket,
    OperationTeam,
    OperationTeamMember,
    OperationTeamUnitAssignment,
    Payment,
    Permission,
    Role,
    RolePermission,
    Unit,
    UnitAmenity,
    UnitAsset,
    UnitImage,
    User,
    UserPermissionOverride,
    UserRole,
    UserUnitAssignment,
)

ROLE_NAMES = {
    "super_admin": "Super Admin",
    "sub_admin": "Sub-Admin",
    "financial": "Financial",
    "operations": "Operations",
    "maintenance": "Maintenance",
    "housekeeping": "Housekeeping",
}


DEMO_USERS = [
    ("admin@crmhotel.example.com", "Super Admin", "super_admin"),
    ("subadmin@crmhotel.example.com", "Sub Admin", "sub_admin"),
    ("financial@crmhotel.example.com", "Financial Officer", "financial"),
    ("ops@crmhotel.example.com", "Operations Officer", "operations"),
    ("operations@crmhotel.example.com", "Operations Officer", "operations"),
    ("maintenance@crmhotel.example.com", "Maintenance Technician", "maintenance"),
    ("hk@crmhotel.example.com", "Housekeeping Staff", "housekeeping"),
    ("housekeeping@crmhotel.example.com", "Housekeeping Staff", "housekeeping"),
]

DEMO_UNIT_ASSIGNMENTS = {
    "ops@crmhotel.example.com": ("U-101", "U-203", "U-114"),
    "operations@crmhotel.example.com": ("U-101", "U-203", "U-114"),
    "maintenance@crmhotel.example.com": ("U-301", "U-101"),
    "hk@crmhotel.example.com": ("U-114", "U-101"),
    "housekeeping@crmhotel.example.com": ("U-114", "U-203"),
}

DEMO_OPERATION_TEAMS = (
    {
        "name": "Riyadh Housekeeping Team",
        "operation_type": OperationTeamType.housekeeping,
        "description": "Cluster coverage for the Riyadh housekeeping workload.",
        "unit_codes": ("U-101", "U-203"),
        "member_emails": ("subadmin@crmhotel.example.com",),
    },
    {
        "name": "Jeddah Housekeeping Team",
        "operation_type": OperationTeamType.housekeeping,
        "description": "Dedicated turnover coverage for Jeddah units.",
        "unit_codes": ("U-114",),
        "member_emails": ("subadmin@crmhotel.example.com",),
    },
    {
        "name": "Core Maintenance Team",
        "operation_type": OperationTeamType.maintenance,
        "description": "Primary response crew for occupied and premium units.",
        "unit_codes": ("U-101", "U-301"),
        "member_emails": ("subadmin@crmhotel.example.com",),
    },
    {
        "name": "Escalation Maintenance Team",
        "operation_type": OperationTeamType.maintenance,
        "description": "Escalation backup for overflow and remote sites.",
        "unit_codes": ("U-114", "U-203"),
        "member_emails": ("subadmin@crmhotel.example.com",),
    },
)

DEMO_UNIT_ASSETS = (
    {
        "unit_code": "U-101",
        "name": "Palm Suite Furnishing",
        "category": "fitout",
        "acquisition_cost": 21600,
        "useful_life_months": 12,
        "offset_days": 90,
    },
    {
        "unit_code": "U-203",
        "name": "Sky Loft Appliances",
        "category": "appliance",
        "acquisition_cost": 26400,
        "useful_life_months": 12,
        "offset_days": 120,
    },
    {
        "unit_code": "U-114",
        "name": "Garden Room Inventory",
        "category": "inventory_fitout",
        "acquisition_cost": 11400,
        "useful_life_months": 12,
        "offset_days": 75,
    },
    {
        "unit_code": "U-301",
        "name": "Sun Deck Equipment",
        "category": "equipment",
        "acquisition_cost": 31200,
        "useful_life_months": 12,
        "offset_days": 150,
    },
)

PERMISSION_AUDIT_USERS = tuple(
    (
        definition.code,
        f"perm-{definition.code.replace('.', '-')}@crmhotel.example.com",
        f"Permission Audit · {definition.name}",
    )
    for definition in PERMISSION_CATALOG
)


def _ensure_permissions_and_role_mappings(
    session: Session,
    *,
    roles_by_code: dict[str, Role],
) -> None:
    permissions_by_code = {
        permission.code: permission for permission in session.exec(select(Permission)).all()
    }
    created_permissions = False
    for definition in PERMISSION_CATALOG:
        if definition.code in permissions_by_code:
            continue
        session.add(
            Permission(
                code=definition.code,
                name=definition.name,
                module=definition.module,
                description=definition.description,
            )
        )
        created_permissions = True
    if created_permissions:
        session.commit()
        permissions_by_code = {
            permission.code: permission for permission in session.exec(select(Permission)).all()
        }

    existing_pairs = {
        (mapping.role_id, mapping.permission_id)
        for mapping in session.exec(select(RolePermission)).all()
    }
    created_pairs = False
    for role_code, permission_codes in ROLE_PERMISSION_CODES.items():
        role = roles_by_code[role_code]
        for permission_code in permission_codes:
            permission = permissions_by_code[permission_code]
            pair = (role.id, permission.id)
            if pair in existing_pairs:
                continue
            session.add(RolePermission(role_id=role.id, permission_id=permission.id))
            created_pairs = True
    if created_pairs:
        session.commit()


def _ensure_demo_users(
    session: Session,
    *,
    roles_by_code: dict[str, Role],
    password_hash: str,
) -> None:
    users_by_email = {user.email: user for user in session.exec(select(User)).all()}
    created_users = False
    for email, full_name, _ in DEMO_USERS:
        if email in users_by_email:
            continue
        session.add(User(email=email, full_name=full_name, password_hash=password_hash))
        created_users = True
    if created_users:
        session.commit()
        users_by_email = {user.email: user for user in session.exec(select(User)).all()}

    existing_links = {(link.user_id, link.role_id) for link in session.exec(select(UserRole)).all()}
    created_links = False
    for email, _, role_code in DEMO_USERS:
        pair = (users_by_email[email].id, roles_by_code[role_code].id)
        if pair in existing_links:
            continue
        session.add(UserRole(user_id=pair[0], role_id=pair[1]))
        created_links = True
    if created_links:
        session.commit()


def _ensure_permission_audit_users(
    session: Session,
    *,
    password_hash: str,
) -> None:
    users_by_email = {user.email: user for user in session.exec(select(User)).all()}
    created_users = False
    for _, email, full_name in PERMISSION_AUDIT_USERS:
        user = users_by_email.get(email)
        if user is None:
            session.add(User(email=email, full_name=full_name, password_hash=password_hash))
            created_users = True
            continue
        if user.full_name != full_name:
            user.full_name = full_name
            session.add(user)
            created_users = True
    if created_users:
        session.commit()
        users_by_email = {user.email: user for user in session.exec(select(User)).all()}

    permissions_by_code = {
        permission.code: permission for permission in session.exec(select(Permission)).all()
    }
    audit_user_ids = [users_by_email[email].id for _, email, _ in PERMISSION_AUDIT_USERS]

    existing_role_links = session.exec(
        select(UserRole).where(UserRole.user_id.in_(audit_user_ids))
    ).all()
    for link in existing_role_links:
        session.delete(link)
    if existing_role_links:
        session.flush()

    existing_overrides = session.exec(
        select(UserPermissionOverride).where(UserPermissionOverride.user_id.in_(audit_user_ids))
    ).all()
    for override in existing_overrides:
        session.delete(override)
    if existing_overrides:
        session.flush()

    for permission_code, email, _ in PERMISSION_AUDIT_USERS:
        session.add(
            UserPermissionOverride(
                user_id=users_by_email[email].id,
                permission_id=permissions_by_code[permission_code].id,
            )
        )
    session.commit()


def _ensure_demo_unit_assignments(session: Session) -> None:
    users_by_email = {user.email: user for user in session.exec(select(User)).all()}
    units_by_code = {unit.code: unit for unit in session.exec(select(Unit)).all()}
    target_user_ids = [
        users_by_email[email].id
        for email in DEMO_UNIT_ASSIGNMENTS
        if email in users_by_email
    ]
    existing_assignments = session.exec(
        select(UserUnitAssignment).where(UserUnitAssignment.user_id.in_(target_user_ids))
    ).all()
    for assignment in existing_assignments:
        session.delete(assignment)
    if existing_assignments:
        session.flush()

    for email, unit_codes in DEMO_UNIT_ASSIGNMENTS.items():
        user = users_by_email.get(email)
        if user is None:
            continue
        for unit_code in unit_codes:
            unit = units_by_code.get(unit_code)
            if unit is None:
                continue
            session.add(UserUnitAssignment(user_id=user.id, unit_id=unit.id))
    session.commit()


def _ensure_demo_operation_teams(session: Session) -> None:
    users_by_email = {user.email: user for user in session.exec(select(User)).all()}
    units_by_code = {unit.code: unit for unit in session.exec(select(Unit)).all()}
    teams_by_name = {team.name: team for team in session.exec(select(OperationTeam)).all()}

    for config in DEMO_OPERATION_TEAMS:
        team = teams_by_name.get(config["name"])
        if team is None:
            team = OperationTeam(
                name=config["name"],
                operation_type=config["operation_type"],
                description=config["description"],
                is_active=True,
            )
            session.add(team)
            session.flush()
        else:
            team.operation_type = config["operation_type"]
            team.description = config["description"]
            team.is_active = True
            session.add(team)
            session.flush()

        existing_members = session.exec(
            select(OperationTeamMember).where(OperationTeamMember.team_id == team.id)
        ).all()
        for member in existing_members:
            session.delete(member)
        existing_units = session.exec(
            select(OperationTeamUnitAssignment).where(
                OperationTeamUnitAssignment.team_id == team.id
            )
        ).all()
        for assignment in existing_units:
            session.delete(assignment)
        session.flush()

        for email in config["member_emails"]:
            user = users_by_email.get(email)
            if user is not None:
                session.add(OperationTeamMember(team_id=team.id, user_id=user.id))
        for unit_code in config["unit_codes"]:
            unit = units_by_code.get(unit_code)
            if unit is not None:
                session.add(OperationTeamUnitAssignment(team_id=team.id, unit_id=unit.id))

    session.commit()


def seed_database(session: Session) -> None:
    settings = get_settings()
    password_hash = hash_password(settings.demo_user_password)
    if session.exec(select(Role)).first() is None:
        roles = [Role(code=code, name=name) for code, name in ROLE_NAMES.items()]
        session.add_all(roles)
        session.commit()

    roles_by_code = {role.code: role for role in session.exec(select(Role)).all()}
    _ensure_permissions_and_role_mappings(session, roles_by_code=roles_by_code)

    _ensure_demo_users(session, roles_by_code=roles_by_code, password_hash=password_hash)
    _ensure_permission_audit_users(session, password_hash=password_hash)

    if session.exec(select(Unit)).first() is None:
        units = [
            Unit(
                code="U-101",
                name="Palm Suite",
                city="Riyadh",
                status=UnitStatus.ready,
                nightly_rate=700,
                monthly_rate=12000,
                monthly_depreciation=1800,
                capacity=4,
                bedrooms=2,
                bathrooms=2,
            ),
            Unit(
                code="U-203",
                name="Sky Loft",
                city="Riyadh",
                status=UnitStatus.occupied,
                nightly_rate=850,
                monthly_rate=14500,
                monthly_depreciation=2200,
                capacity=3,
                bedrooms=2,
                bathrooms=2,
            ),
            Unit(
                code="U-114",
                name="Garden Room",
                city="Jeddah",
                status=UnitStatus.pending_cleaning,
                nightly_rate=560,
                monthly_rate=9800,
                monthly_depreciation=950,
                capacity=2,
                bedrooms=1,
                bathrooms=1,
            ),
            Unit(
                code="U-301",
                name="Sun Deck",
                city="Khobar",
                status=UnitStatus.maintenance,
                nightly_rate=930,
                monthly_rate=15000,
                monthly_depreciation=2600,
                capacity=5,
                bedrooms=3,
                bathrooms=2,
            ),
        ]
        session.add_all(units)
        session.commit()

    units = session.exec(select(Unit)).all()
    units_by_code = {unit.code: unit for unit in units}

    if session.exec(select(UnitImage)).first() is None:
        images = [
            UnitImage(
                unit_id=units_by_code["U-101"].id,
                file_path="demo/palm-suite-cover.jpg",
                original_filename="palm-suite-cover.jpg",
                content_type="image/jpeg",
                size_bytes=631,
                is_cover=True,
                sort_order=1,
            ),
            UnitImage(
                unit_id=units_by_code["U-203"].id,
                file_path="demo/sky-loft-cover.jpg",
                original_filename="sky-loft-cover.jpg",
                content_type="image/jpeg",
                size_bytes=631,
                is_cover=True,
                sort_order=1,
            ),
            UnitImage(
                unit_id=units_by_code["U-114"].id,
                file_path="demo/garden-room-cover.jpg",
                original_filename="garden-room-cover.jpg",
                content_type="image/jpeg",
                size_bytes=631,
                is_cover=True,
                sort_order=1,
            ),
            UnitImage(
                unit_id=units_by_code["U-301"].id,
                file_path="demo/sun-deck-cover.jpg",
                original_filename="sun-deck-cover.jpg",
                content_type="image/jpeg",
                size_bytes=631,
                is_cover=True,
                sort_order=1,
            ),
        ]
        session.add_all(images)
        session.commit()

    if session.exec(select(Amenity)).first() is None:
        amenities = [
            Amenity(code="wifi", name="Wi-Fi"),
            Amenity(code="smart_lock", name="Smart Lock"),
            Amenity(code="parking", name="Parking"),
            Amenity(code="balcony", name="Balcony"),
        ]
        session.add_all(amenities)
        session.commit()
        amenities_by_code = {
            amenity.code: amenity for amenity in session.exec(select(Amenity)).all()
        }
        session.add_all(
            [
                UnitAmenity(
                    unit_id=units_by_code["U-101"].id, amenity_id=amenities_by_code["wifi"].id
                ),
                UnitAmenity(
                    unit_id=units_by_code["U-101"].id, amenity_id=amenities_by_code["smart_lock"].id
                ),
                UnitAmenity(
                    unit_id=units_by_code["U-203"].id, amenity_id=amenities_by_code["wifi"].id
                ),
                UnitAmenity(
                    unit_id=units_by_code["U-301"].id, amenity_id=amenities_by_code["parking"].id
                ),
            ]
        )
        session.commit()

    if session.exec(select(Client)).first() is None:
        clients = [
            Client(full_name="Alya Ahmed", email="alya@example.com", phone="+966500000001"),
            Client(full_name="Noor Salem", email="noor@example.com", phone="+966500000002"),
            Client(
                full_name="Fahad Omar",
                email="fahad@example.com",
                phone="+966500000003",
                is_blacklisted=True,
                blacklist_reason="Repeated damage complaints",
            ),
        ]
        session.add_all(clients)
        session.commit()

    clients = session.exec(select(Client)).all()
    clients_by_name = {client.full_name: client for client in clients}
    users_by_email = {user.email: user for user in session.exec(select(User)).all()}

    if session.exec(select(Booking)).first() is None:
        now = datetime.now(timezone.utc)
        bookings = [
            Booking(
                unit_id=units_by_code["U-101"].id,
                client_id=clients_by_name["Alya Ahmed"].id,
                client_name="Alya Ahmed",
                client_phone="+966500000001",
                status=BookingStatus.confirmed,
                payment_status=PaymentStatus.partial,
                check_in_at=now + timedelta(days=1),
                check_out_at=now + timedelta(days=3),
                guest_count=2,
                base_amount=1400,
                tax_amount=210,
                total_amount=1610,
                outstanding_amount=610,
                created_by=users_by_email["ops@crmhotel.example.com"].id,
            ),
            Booking(
                unit_id=units_by_code["U-203"].id,
                client_id=clients_by_name["Noor Salem"].id,
                client_name="Noor Salem",
                client_phone="+966500000002",
                status=BookingStatus.checked_in,
                payment_status=PaymentStatus.paid,
                check_in_at=now - timedelta(days=1),
                check_out_at=now + timedelta(days=1),
                checked_in_at=now - timedelta(days=1),
                guest_count=2,
                base_amount=1700,
                tax_amount=255,
                total_amount=1955,
                outstanding_amount=0,
                created_by=users_by_email["ops@crmhotel.example.com"].id,
            ),
            Booking(
                unit_id=units_by_code["U-114"].id,
                client_id=clients_by_name["Alya Ahmed"].id,
                client_name="Alya Ahmed",
                client_phone="+966500000001",
                status=BookingStatus.checked_out,
                payment_status=PaymentStatus.paid,
                check_in_at=now - timedelta(days=4),
                check_out_at=now - timedelta(days=1),
                checked_in_at=now - timedelta(days=4),
                checked_out_at=now - timedelta(days=1),
                guest_count=1,
                base_amount=1200,
                tax_amount=180,
                total_amount=1380,
                outstanding_amount=0,
                created_by=users_by_email["ops@crmhotel.example.com"].id,
            ),
        ]
        session.add_all(bookings)
        session.commit()

    bookings = session.exec(select(Booking)).all()
    if session.exec(select(HousekeepingTask)).first() is None:
        checked_out_booking = next(
            booking for booking in bookings if booking.status == BookingStatus.checked_out
        )
        session.add(
            HousekeepingTask(
                unit_id=checked_out_booking.unit_id,
                booking_id=checked_out_booking.id,
                assigned_user_id=users_by_email["housekeeping@crmhotel.example.com"].id,
                priority=PriorityLevel.urgent,
                status=TaskStatus.open,
                notes="Deep cleaning after long stay",
            )
        )
        session.commit()

    if session.exec(select(MaintenanceTicket)).first() is None:
        session.add(
            MaintenanceTicket(
                unit_id=units_by_code["U-301"].id,
                assigned_user_id=users_by_email["maintenance@crmhotel.example.com"].id,
                title="AC cooling issue",
                description="Guest reported weak cooling before arrival",
                priority=PriorityLevel.urgent,
                status=TicketStatus.open,
            )
        )
        session.commit()

    if session.exec(select(Payment)).first() is None:
        payment_rows = [
            Payment(
                booking_id=bookings[0].id,
                amount=1000,
                method="card",
                status=PaymentStatus.partial,
                reference_no="PAY-1000",
            ),
            Payment(
                booking_id=bookings[1].id,
                amount=1955,
                method="bank_transfer",
                status=PaymentStatus.paid,
                reference_no="PAY-1001",
            ),
            Payment(
                booking_id=bookings[2].id,
                amount=1380,
                method="cash",
                status=PaymentStatus.paid,
                reference_no="PAY-1002",
            ),
        ]
        session.add_all(payment_rows)
        session.commit()

    if session.exec(select(Expense)).first() is None:
        expense_rows = [
            Expense(
                unit_id=units_by_code["U-301"].id,
                category="maintenance",
                description="AC inspection visit",
                amount=850,
            ),
            Expense(
                unit_id=units_by_code["U-114"].id,
                category="housekeeping",
                description="Cleaning supplies",
                amount=120,
            ),
        ]
        session.add_all(expense_rows)
        session.commit()

    if session.exec(select(UnitAsset)).first() is None:
        asset_now = datetime.now(timezone.utc)
        asset_rows = [
            UnitAsset(
                unit_id=units_by_code[config["unit_code"]].id,
                name=config["name"],
                category=config["category"],
                acquisition_cost=config["acquisition_cost"],
                useful_life_months=config["useful_life_months"],
                commissioned_at=asset_now - timedelta(days=config["offset_days"]),
            )
            for config in DEMO_UNIT_ASSETS
        ]
        session.add_all(asset_rows)
        session.commit()

    payments = session.exec(select(Payment)).all()
    expenses = session.exec(select(Expense)).all()
    if session.exec(select(LedgerEntry)).first() is None:
        ledger_rows = [
            LedgerEntry(
                unit_id=bookings[0].unit_id,
                booking_id=bookings[0].id,
                payment_id=payments[0].id,
                entry_type="booking_revenue",
                direction="credit",
                amount=payments[0].amount,
                notes="Advance payment",
            ),
            LedgerEntry(
                unit_id=bookings[1].unit_id,
                booking_id=bookings[1].id,
                payment_id=payments[1].id,
                entry_type="booking_revenue",
                direction="credit",
                amount=payments[1].amount,
                notes="Settled stay",
            ),
            LedgerEntry(
                unit_id=expenses[0].unit_id,
                expense_id=expenses[0].id,
                entry_type="expense",
                direction="debit",
                amount=expenses[0].amount,
                notes=expenses[0].description,
            ),
        ]
        session.add_all(ledger_rows)
        session.commit()

    _ensure_demo_unit_assignments(session)
    _ensure_demo_operation_teams(session)
