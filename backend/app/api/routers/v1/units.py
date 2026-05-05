from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, Query, UploadFile
from sqlmodel import Session, select

from app.api.dependencies.auth import CurrentUser, require_permissions
from app.api.dependencies.pagination import PaginationParams, pagination_params
from app.api.dependencies.unit_scope import (
    apply_unit_scope,
    ensure_unit_in_scope,
    resolve_unit_scope_ids,
)
from app.core.config import get_settings
from app.core.db import get_session
from app.core.enums import UnitStatus
from app.domain.shared.exceptions import DomainError
from app.infrastructure.persistence.models import Amenity, Unit, UnitAmenity, UnitImage
from app.infrastructure.storage import LocalMediaStorage
from app.schemas.common import PaginatedResponse
from app.schemas.units import (
    AmenityRead,
    UnitAmenitiesUpdate,
    UnitCreate,
    UnitDetailRead,
    UnitImageCreate,
    UnitImageRead,
    UnitListItem,
    UnitRead,
    UnitUpdate,
)

router = APIRouter()


def _media_storage() -> LocalMediaStorage:
    return LocalMediaStorage(get_settings())


def _load_unit_images(session: Session, unit_id: str) -> list[UnitImage]:
    return session.exec(
        select(UnitImage)
        .where(UnitImage.unit_id == unit_id)
        .order_by(UnitImage.sort_order, UnitImage.created_at)
    ).all()


def _load_unit_amenities(session: Session, unit_id: str) -> list[Amenity]:
    return session.exec(
        select(Amenity)
        .join(UnitAmenity, UnitAmenity.amenity_id == Amenity.id)
        .where(UnitAmenity.unit_id == unit_id)
        .order_by(Amenity.name)
    ).all()


def _build_unit_list_item(session: Session, unit: Unit) -> UnitListItem:
    images = _load_unit_images(session, unit.id)
    amenities = _load_unit_amenities(session, unit.id)
    cover = next((image for image in images if image.is_cover), None)
    media_storage = _media_storage()
    return UnitListItem(
        **UnitRead.model_validate(unit).model_dump(),
        cover_image_path=cover.file_path if cover else None,
        cover_image_url=media_storage.public_url(cover.file_path) if cover else None,
        amenity_codes=[amenity.code for amenity in amenities],
    )


def _build_unit_image(image: UnitImage) -> UnitImageRead:
    media_storage = _media_storage()
    return UnitImageRead(
        id=image.id,
        file_path=image.file_path,
        original_filename=image.original_filename,
        content_type=image.content_type,
        size_bytes=image.size_bytes,
        is_cover=image.is_cover,
        sort_order=image.sort_order,
        public_url=media_storage.public_url(image.file_path),
    )


def _build_unit_detail(session: Session, unit: Unit) -> UnitDetailRead:
    images = _load_unit_images(session, unit.id)
    amenities = _load_unit_amenities(session, unit.id)
    return UnitDetailRead(
        **UnitRead.model_validate(unit).model_dump(),
        images=[_build_unit_image(image) for image in images],
        amenities=[AmenityRead.model_validate(amenity) for amenity in amenities],
    )


def _resolve_amenities(session: Session, amenity_codes: list[str]) -> list[Amenity]:
    if not amenity_codes:
        return []
    amenities = session.exec(select(Amenity).where(Amenity.code.in_(amenity_codes))).all()
    found_codes = {amenity.code for amenity in amenities}
    missing_codes = sorted(set(amenity_codes) - found_codes)
    if missing_codes:
        raise DomainError(
            code="AMENITY_CODES_NOT_FOUND",
            message="One or more amenity codes do not exist.",
            details={"missing_codes": ",".join(missing_codes)},
            status_code=404,
        )
    return amenities


def _set_unit_amenities(session: Session, unit_id: str, amenity_codes: list[str]) -> None:
    amenities = _resolve_amenities(session, amenity_codes)
    existing_links = session.exec(select(UnitAmenity).where(UnitAmenity.unit_id == unit_id)).all()
    for link in existing_links:
        session.delete(link)
    session.flush()
    for amenity in amenities:
        session.add(UnitAmenity(unit_id=unit_id, amenity_id=amenity.id))


def _add_unit_images(session: Session, unit_id: str, images: list[UnitImageCreate]) -> None:
    if not images:
        return
    if any(image.is_cover for image in images):
        existing_cover = session.exec(
            select(UnitImage).where(UnitImage.unit_id == unit_id, UnitImage.is_cover)
        ).all()
        for image in existing_cover:
            image.is_cover = False
            session.add(image)
    for image in images:
        session.add(UnitImage(unit_id=unit_id, **image.model_dump()))


@router.get("/amenities/catalog", response_model=list[AmenityRead])
def list_amenity_catalog(
    _: Annotated[CurrentUser, Depends(require_permissions("units.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> list[AmenityRead]:
    amenities = session.exec(select(Amenity).order_by(Amenity.name)).all()
    return [AmenityRead.model_validate(amenity) for amenity in amenities]


@router.get("", response_model=PaginatedResponse[UnitListItem])
def list_units(
    user: Annotated[
        CurrentUser,
        Depends(require_permissions("units.view", "units.manage")),
    ],
    pagination: Annotated[PaginationParams, Depends(pagination_params)],
    session: Annotated[Session, Depends(get_session)],
    status: Annotated[UnitStatus | None, Query()] = None,
) -> PaginatedResponse[UnitListItem]:
    statement = select(Unit).where(Unit.is_active)
    statement = apply_unit_scope(statement, resolve_unit_scope_ids(session, user), Unit.id)
    if status:
        statement = statement.where(Unit.status == status)
    total_items = len(session.exec(statement).all())
    offset = (pagination.page - 1) * pagination.page_size
    items = session.exec(statement.offset(offset).limit(pagination.page_size)).all()
    return PaginatedResponse.create(
        items=[_build_unit_list_item(session, item) for item in items],
        page=pagination.page,
        page_size=pagination.page_size,
        total_items=total_items,
    )


@router.post("", response_model=UnitDetailRead)
def create_unit(
    payload: UnitCreate,
    _: Annotated[CurrentUser, Depends(require_permissions("units.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> UnitDetailRead:
    unit = Unit.model_validate(payload, update={"status": UnitStatus.ready})
    session.add(unit)
    session.flush()
    _set_unit_amenities(session, unit.id, payload.amenity_codes)
    _add_unit_images(session, unit.id, payload.images)
    session.commit()
    session.refresh(unit)
    return _build_unit_detail(session, unit)


@router.get("/{unit_id}", response_model=UnitDetailRead)
def get_unit(
    unit_id: str,
    user: Annotated[
        CurrentUser,
        Depends(require_permissions("units.view", "units.manage")),
    ],
    session: Annotated[Session, Depends(get_session)],
) -> UnitDetailRead:
    ensure_unit_in_scope(unit_id, resolve_unit_scope_ids(session, user))
    unit = session.get(Unit, unit_id)
    if not unit:
        raise ValueError("Unit not found")
    return _build_unit_detail(session, unit)


@router.patch("/{unit_id}", response_model=UnitDetailRead)
def update_unit(
    unit_id: str,
    payload: UnitUpdate,
    _: Annotated[CurrentUser, Depends(require_permissions("units.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> UnitDetailRead:
    unit = session.get(Unit, unit_id)
    if not unit:
        raise ValueError("Unit not found")
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(unit, field, value)
    session.add(unit)
    session.commit()
    session.refresh(unit)
    return _build_unit_detail(session, unit)


@router.put("/{unit_id}/amenities", response_model=UnitDetailRead)
def update_unit_amenities(
    unit_id: str,
    payload: UnitAmenitiesUpdate,
    _: Annotated[CurrentUser, Depends(require_permissions("units.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> UnitDetailRead:
    unit = session.get(Unit, unit_id)
    if not unit:
        raise ValueError("Unit not found")
    _set_unit_amenities(session, unit.id, payload.amenity_codes)
    session.commit()
    return _build_unit_detail(session, unit)


@router.post("/{unit_id}/images", response_model=UnitDetailRead)
def add_unit_image(
    unit_id: str,
    file: Annotated[UploadFile, File()],
    _: Annotated[CurrentUser, Depends(require_permissions("units.manage"))],
    session: Annotated[Session, Depends(get_session)],
    is_cover: Annotated[bool, Form()] = False,
    sort_order: Annotated[int, Form()] = 0,
) -> UnitDetailRead:
    unit = session.get(Unit, unit_id)
    if not unit:
        raise ValueError("Unit not found")
    media_storage = _media_storage()
    stored_file = media_storage.save_upload(
        namespace="unit-images", owner_id=unit.id, upload_file=file
    )
    try:
        _add_unit_images(
            session,
            unit.id,
            [
                UnitImageCreate(
                    file_path=stored_file.relative_path,
                    original_filename=stored_file.original_filename,
                    content_type=stored_file.content_type,
                    size_bytes=stored_file.size_bytes,
                    is_cover=is_cover,
                    sort_order=sort_order,
                )
            ],
        )
        session.commit()
    except Exception:
        media_storage.delete_file(stored_file.relative_path)
        raise
    return _build_unit_detail(session, unit)


@router.delete("/{unit_id}/images/{image_id}", response_model=UnitDetailRead)
def delete_unit_image(
    unit_id: str,
    image_id: str,
    _: Annotated[CurrentUser, Depends(require_permissions("units.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> UnitDetailRead:
    unit = session.get(Unit, unit_id)
    if not unit:
        raise ValueError("Unit not found")
    image = session.get(UnitImage, image_id)
    if not image or image.unit_id != unit_id:
        raise ValueError("Image not found")
    file_path = image.file_path
    session.delete(image)
    session.commit()
    _media_storage().delete_file(file_path)
    return _build_unit_detail(session, unit)


@router.delete("/{unit_id}", response_model=UnitRead)
def deactivate_unit(
    unit_id: str,
    _: Annotated[CurrentUser, Depends(require_permissions("units.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> UnitRead:
    unit = session.get(Unit, unit_id)
    if not unit:
        raise ValueError("Unit not found")
    unit.is_active = False
    session.add(unit)
    session.commit()
    session.refresh(unit)
    return UnitRead.model_validate(unit)
