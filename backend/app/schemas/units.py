from __future__ import annotations

from pydantic import BaseModel, ConfigDict

from app.core.enums import UnitStatus


class AmenityRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    code: str
    name: str


class UnitImageCreate(BaseModel):
    file_path: str
    original_filename: str | None = None
    content_type: str | None = None
    size_bytes: int | None = None
    is_cover: bool = False
    sort_order: int = 0


class UnitImageRead(UnitImageCreate):
    model_config = ConfigDict(from_attributes=True)

    id: str
    public_url: str | None = None


class UnitBase(BaseModel):
    code: str
    name: str
    city: str
    country: str = "Saudi Arabia"
    nightly_rate: float = 0
    monthly_rate: float = 0
    monthly_depreciation: float = 0
    currency: str = "SAR"
    capacity: int = 1
    bedrooms: int = 1
    bathrooms: int = 1


class UnitCreate(UnitBase):
    smart_lock_code_encrypted: str | None = None
    amenity_codes: list[str] = []
    images: list[UnitImageCreate] = []


class UnitUpdate(BaseModel):
    code: str | None = None
    name: str | None = None
    city: str | None = None
    country: str | None = None
    status: UnitStatus | None = None
    nightly_rate: float | None = None
    monthly_rate: float | None = None
    monthly_depreciation: float | None = None
    currency: str | None = None
    capacity: int | None = None
    bedrooms: int | None = None
    bathrooms: int | None = None
    smart_lock_code_encrypted: str | None = None
    is_active: bool | None = None


class UnitRead(UnitBase):
    model_config = ConfigDict(from_attributes=True)

    id: str
    status: UnitStatus
    is_active: bool


class UnitListItem(UnitRead):
    cover_image_path: str | None = None
    cover_image_url: str | None = None
    amenity_codes: list[str] = []


class UnitDetailRead(UnitRead):
    images: list[UnitImageRead] = []
    amenities: list[AmenityRead] = []


class UnitAmenitiesUpdate(BaseModel):
    amenity_codes: list[str]
