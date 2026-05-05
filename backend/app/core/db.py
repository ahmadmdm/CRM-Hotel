from __future__ import annotations

from collections.abc import Generator
from pathlib import Path

from alembic.config import Config
from sqlmodel import Session, SQLModel, create_engine

from alembic import command
from app.core.config import get_settings

settings = get_settings()
connect_args = {"check_same_thread": False} if settings.database_url.startswith("sqlite") else {}
engine = create_engine(settings.database_url, echo=False, connect_args=connect_args)


def _run_migrations() -> None:
    backend_root = Path(__file__).resolve().parents[2]
    alembic_config = Config(str(backend_root / 'alembic.ini'))
    alembic_config.set_main_option('script_location', str(backend_root / 'alembic'))
    alembic_config.set_main_option('sqlalchemy.url', settings.database_url)
    command.upgrade(alembic_config, 'head')


def create_db_and_tables(seed: bool = True) -> None:
    from app.infrastructure.persistence import models  # noqa: F401
    from app.core.seed import ensure_access_control_baseline

    _run_migrations()
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        ensure_access_control_baseline(session)
        if seed:
            from app.core.seed import seed_database

            seed_database(session)



def get_session() -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session
