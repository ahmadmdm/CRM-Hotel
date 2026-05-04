from __future__ import annotations

from pydantic import BaseModel


class DashboardKpis(BaseModel):
    total_units: int
    occupied_units: int
    active_bookings: int
    pending_cleaning: int
    open_tickets: int
    total_revenue: float
    total_expenses: float
    occupancy_rate: float
