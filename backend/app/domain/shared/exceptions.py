from __future__ import annotations


class DomainError(Exception):
    def __init__(
        self,
        code: str,
        message: str,
        details: dict[str, str | int | float | bool | None] | None = None,
        status_code: int = 400,
    ) -> None:
        self.code = code
        self.message = message
        self.details = details or {}
        self.status_code = status_code
        super().__init__(message)
