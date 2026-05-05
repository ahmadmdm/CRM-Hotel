from fastapi import APIRouter

from app.api.routers.v1 import (
    access,
    auth,
    bookings,
    clients,
    finance,
    health,
    housekeeping,
    maintenance,
    notifications,
    reports,
    units,
    users,
)

api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(access.router, prefix="/access", tags=["access"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(units.router, prefix="/units", tags=["units"])
api_router.include_router(bookings.router, prefix="/bookings", tags=["bookings"])
api_router.include_router(clients.router, prefix="/clients", tags=["clients"])
api_router.include_router(housekeeping.router, prefix="/housekeeping", tags=["housekeeping"])
api_router.include_router(maintenance.router, prefix="/maintenance", tags=["maintenance"])
api_router.include_router(notifications.router, prefix="/notifications", tags=["notifications"])
api_router.include_router(finance.router, prefix="/finance", tags=["finance"])
api_router.include_router(reports.router, prefix="/reports", tags=["reports"])
