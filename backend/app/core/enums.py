from enum import Enum


class UnitStatus(str, Enum):
    vacant = "vacant"
    reserved = "reserved"
    occupied = "occupied"
    pending_cleaning = "pending_cleaning"
    ready = "ready"
    maintenance = "maintenance"


class BookingStatus(str, Enum):
    pending = "pending"
    confirmed = "confirmed"
    checked_in = "checked_in"
    checked_out = "checked_out"
    cancelled = "cancelled"
    no_show = "no_show"


class PaymentStatus(str, Enum):
    unpaid = "unpaid"
    partial = "partial"
    paid = "paid"
    refunded = "refunded"


class FinancePeriod(str, Enum):
    month = "month"
    quarter = "quarter"
    year = "year"


class TaskStatus(str, Enum):
    open = "open"
    in_progress = "in_progress"
    completed = "completed"
    blocked = "blocked"


class TicketStatus(str, Enum):
    open = "open"
    in_progress = "in_progress"
    resolved = "resolved"
    closed = "closed"


class PriorityLevel(str, Enum):
    low = "low"
    normal = "normal"
    high = "high"
    urgent = "urgent"


class AccessOverrideEffect(str, Enum):
    allow = "allow"
    deny = "deny"


class OperationTeamType(str, Enum):
    housekeeping = "housekeeping"
    maintenance = "maintenance"


class NotificationKind(str, Enum):
    broadcast = "broadcast"
    housekeeping = "housekeeping"
    maintenance = "maintenance"
    auth = "auth"
