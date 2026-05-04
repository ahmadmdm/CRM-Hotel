from __future__ import annotations

import os
from datetime import timedelta
from pathlib import Path

from app.core.config import get_settings
from app.core.security import create_access_token
from tests.conftest import create_client

AUTH_HEADERS = {
    "Authorization": "Bearer "
    + create_access_token(
        subject="admin@crmhotel.example.com",
        user_id="test-super-admin",
        full_name="Test Super Admin",
        roles=["super_admin"],
        expires_delta=timedelta(minutes=60),
    )
}


def test_unit_image_upload_persists_file_and_deletes_it(tmp_path: Path) -> None:
    original_media_root = os.environ.get("MEDIA_ROOT")
    original_media_base_url = os.environ.get("MEDIA_PUBLIC_BASE_URL")
    try:
        os.environ["MEDIA_ROOT"] = str(tmp_path)
        os.environ["MEDIA_PUBLIC_BASE_URL"] = "http://testserver/media"
        get_settings.cache_clear()

        client = create_client(seed=True)
        units_response = client.get("/api/v1/units", headers=AUTH_HEADERS)
        assert units_response.status_code == 200
        unit_id = units_response.json()["items"][0]["id"]

        upload_response = client.post(
            f"/api/v1/units/{unit_id}/images",
            headers=AUTH_HEADERS,
            files={"file": ("floorplan.png", b"fake-png-content", "image/png")},
            data={"is_cover": "true", "sort_order": "9"},
        )

        assert upload_response.status_code == 200
        payload = upload_response.json()
        uploaded_image = next(
            image for image in payload["images"] if image["original_filename"] == "floorplan.png"
        )
        relative_path = uploaded_image["file_path"]
        saved_file = tmp_path / relative_path

        assert saved_file.exists()
        assert saved_file.read_bytes() == b"fake-png-content"
        assert uploaded_image["public_url"] == f"http://testserver/media/{relative_path}"

        served_response = client.get(f"/media/{relative_path}")
        assert served_response.status_code == 200
        assert served_response.content == b"fake-png-content"

        delete_response = client.delete(
            f"/api/v1/units/{unit_id}/images/{uploaded_image['id']}", headers=AUTH_HEADERS
        )
        assert delete_response.status_code == 200
        assert not saved_file.exists()
    finally:
        if original_media_root is None:
            os.environ.pop("MEDIA_ROOT", None)
        else:
            os.environ["MEDIA_ROOT"] = original_media_root

        if original_media_base_url is None:
            os.environ.pop("MEDIA_PUBLIC_BASE_URL", None)
        else:
            os.environ["MEDIA_PUBLIC_BASE_URL"] = original_media_base_url

        get_settings.cache_clear()
