from __future__ import annotations

from math import ceil
from typing import Generic, TypeVar

from pydantic import BaseModel

T = TypeVar("T")


class PaginationMeta(BaseModel):
    page: int
    page_size: int
    total_items: int
    total_pages: int


class PaginatedResponse(BaseModel, Generic[T]):
    items: list[T]
    pagination: PaginationMeta

    @classmethod
    def create(
        cls, items: list[T], page: int, page_size: int, total_items: int
    ) -> PaginatedResponse[T]:
        return cls(
            items=items,
            pagination=PaginationMeta(
                page=page,
                page_size=page_size,
                total_items=total_items,
                total_pages=max(1, ceil(total_items / page_size)) if page_size else 1,
            ),
        )
