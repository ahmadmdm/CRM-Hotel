from __future__ import annotations

import os

from fastapi.testclient import TestClient
from sqlalchemy import inspect, text
from sqlmodel import SQLModel

os.environ["APP_ENV"] = "test"
os.environ["DATABASE_URL"] = "sqlite:///./crmhotel_test.db"
os.environ["DEMO_USER_PASSWORD"] = "ChangeMe123!"
os.environ["SUPER_ADMIN_EMAIL"] = "admin@crmhotel.example.com"
os.environ["SUPER_ADMIN_PASSWORD"] = "ChangeMe123!"
os.environ["SECRET_KEY"] = "change-me"
os.environ["ALLOWED_ORIGINS"] = "http://localhost"

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
