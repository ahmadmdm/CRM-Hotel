from __future__ import annotations

from pydantic import BaseModel, ConfigDict, EmailStr


class ClientCreate(BaseModel):
    full_name: str
    email: EmailStr | None = None
    phone: str
    nationality: str | None = None
    id_type: str | None = None
    id_number: str | None = None
    notes: str | None = None


class ClientUpdate(BaseModel):
    full_name: str | None = None
    email: EmailStr | None = None
    phone: str | None = None
    nationality: str | None = None
    id_type: str | None = None
    id_number: str | None = None
    notes: str | None = None


class ClientRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    full_name: str
    email: EmailStr | None = None
    phone: str
    nationality: str | None = None
    id_type: str | None = None
    id_number: str | None = None
    is_blacklisted: bool
    blacklist_reason: str | None = None
    notes: str | None = None
