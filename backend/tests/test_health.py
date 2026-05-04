from __future__ import annotations

from tests.conftest import create_client


def test_healthcheck() -> None:
    client = create_client()
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
