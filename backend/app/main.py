from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.errors.handlers import register_exception_handlers
from app.api.routers.v1 import api_router
from app.core.config import get_settings
from app.core.db import create_db_and_tables
from app.infrastructure.storage import LocalMediaStorage


@asynccontextmanager
async def lifespan(_: FastAPI):
    settings = get_settings()
    media_storage = LocalMediaStorage(settings)
    media_storage.ensure_ready()
    media_storage.ensure_demo_assets()
    create_db_and_tables(seed=settings.seed_demo_data)
    yield


def create_application() -> FastAPI:
    settings = get_settings()
    media_storage = LocalMediaStorage(settings)
    media_storage.ensure_ready()
    app = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        lifespan=lifespan,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.allowed_origins_list,
        allow_origin_regex=settings.local_origin_regex,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    register_exception_handlers(app)
    app.mount(settings.media_url_path, StaticFiles(directory=settings.media_root), name="media")
    app.include_router(api_router, prefix=settings.api_v1_prefix)
    return app


app = create_application()
