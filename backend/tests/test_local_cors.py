from __future__ import annotations

from fastapi.testclient import TestClient

from app.core.config import get_settings
from app.main import create_application


def test_loopback_origin_is_allowed_for_local_cors_preflight(monkeypatch) -> None:
    monkeypatch.setenv("ALLOWED_ORIGINS", "http://app.example.com")
    get_settings.cache_clear()

    try:
        with TestClient(create_application()) as client:
            response = client.options(
                "/api/v1/auth/login",
                headers={
                    "Origin": "http://127.0.0.1:3002",
                    "Access-Control-Request-Method": "POST",
                    "Access-Control-Request-Headers": "content-type",
                },
            )
    finally:
        get_settings.cache_clear()

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://127.0.0.1:3002"