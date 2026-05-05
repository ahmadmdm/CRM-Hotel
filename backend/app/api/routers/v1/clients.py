from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlmodel import Session, or_, select

from app.api.dependencies.auth import CurrentUser, require_permissions
from app.api.dependencies.pagination import PaginationParams, pagination_params
from app.core.db import get_session
from app.infrastructure.persistence.models import Client
from app.schemas.clients import ClientCreate, ClientRead, ClientUpdate
from app.schemas.common import PaginatedResponse

router = APIRouter()


@router.get("", response_model=PaginatedResponse[ClientRead])
def list_clients(
    _: Annotated[
        CurrentUser,
        Depends(require_permissions("crm.view", "crm.manage")),
    ],
    pagination: Annotated[PaginationParams, Depends(pagination_params)],
    session: Annotated[Session, Depends(get_session)],
    q: Annotated[str | None, Query()] = None,
    blacklisted: Annotated[bool | None, Query()] = None,
) -> PaginatedResponse[ClientRead]:
    statement = select(Client)
    if q:
        term = f"%{q}%"
        statement = statement.where(or_(Client.full_name.ilike(term), Client.phone.ilike(term)))
    if blacklisted is not None:
        statement = statement.where(Client.is_blacklisted == blacklisted)
    total_items = len(session.exec(statement).all())
    offset = (pagination.page - 1) * pagination.page_size
    items = session.exec(statement.offset(offset).limit(pagination.page_size)).all()
    return PaginatedResponse.create(
        items=items, page=pagination.page, page_size=pagination.page_size, total_items=total_items
    )


@router.post("", response_model=ClientRead)
def create_client(
    payload: ClientCreate,
    _: Annotated[CurrentUser, Depends(require_permissions("crm.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> ClientRead:
    client = Client.model_validate(payload)
    session.add(client)
    session.commit()
    session.refresh(client)
    return ClientRead.model_validate(client)


@router.get("/{client_id}", response_model=ClientRead)
def get_client(
    client_id: str,
    _: Annotated[
        CurrentUser,
        Depends(require_permissions("crm.view", "crm.manage")),
    ],
    session: Annotated[Session, Depends(get_session)],
) -> ClientRead:
    client = session.get(Client, client_id)
    if not client:
        raise ValueError("Client not found")
    return ClientRead.model_validate(client)


@router.patch("/{client_id}", response_model=ClientRead)
def update_client(
    client_id: str,
    payload: ClientUpdate,
    _: Annotated[CurrentUser, Depends(require_permissions("crm.manage"))],
    session: Annotated[Session, Depends(get_session)],
) -> ClientRead:
    client = session.get(Client, client_id)
    if not client:
        raise ValueError("Client not found")
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(client, field, value)
    session.add(client)
    session.commit()
    session.refresh(client)
    return ClientRead.model_validate(client)


@router.post("/{client_id}/blacklist", response_model=ClientRead)
def blacklist_client(
    client_id: str,
    _: Annotated[CurrentUser, Depends(require_permissions("crm.manage"))],
    session: Annotated[Session, Depends(get_session)],
    reason: Annotated[str, Query()] = "Manual blacklist",
) -> ClientRead:
    client = session.get(Client, client_id)
    if not client:
        raise ValueError("Client not found")
    client.is_blacklisted = True
    client.blacklist_reason = reason
    session.add(client)
    session.commit()
    session.refresh(client)
    return ClientRead.model_validate(client)
