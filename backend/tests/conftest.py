from __future__ import annotations

from fastapi.testclient import TestClient
from sqlalchemy import inspect, text
from sqlmodel import SQLModel

from app.core.db import create_db_and_tables, engine
from app.main import create_application


def create_client(seed: bool = False) -> TestClient:
    SQLModel.metadata.drop_all(engine)
    with engine.begin() as connection:
        inspector = inspect(connection)
        if inspector.has_table("alembic_version"):
            connection.execute(text("DROP TABLE alembic_version"))
    create_db_and_tables(seed=seed)
    app = create_application()
    return TestClient(app)
