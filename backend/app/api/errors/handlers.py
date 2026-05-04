from __future__ import annotations

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse

from app.api.errors.schemas import ErrorBody, ErrorResponse
from app.domain.shared.exceptions import DomainError


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(DomainError)
    async def handle_domain_error(_: Request, exc: DomainError) -> JSONResponse:
        body = ErrorResponse(
            error=ErrorBody(
                code=exc.code,
                message=exc.message,
                details=exc.details,
            )
        )
        return JSONResponse(status_code=exc.status_code, content=body.model_dump())

    @app.exception_handler(ValueError)
    async def handle_value_error(_: Request, exc: ValueError) -> JSONResponse:
        body = ErrorResponse(
            error=ErrorBody(
                code="VALIDATION_ERROR",
                message=str(exc),
            )
        )
        return JSONResponse(status_code=status.HTTP_400_BAD_REQUEST, content=body.model_dump())
