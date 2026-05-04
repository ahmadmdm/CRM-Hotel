from __future__ import annotations

from datetime import timedelta

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


def test_unit_detail_supports_amenities_images_and_soft_delete() -> None:
    client = create_client(seed=True)

    catalog_response = client.get("/api/v1/units/amenities/catalog", headers=AUTH_HEADERS)
    assert catalog_response.status_code == 200
    assert {item["code"] for item in catalog_response.json()} >= {"wifi", "smart_lock"}

    create_response = client.post(
        "/api/v1/units",
        headers=AUTH_HEADERS,
        json={
            "code": "U-909",
            "name": "Harbor Edge",
            "city": "Jeddah",
            "nightly_rate": 1234,
            "amenity_codes": ["wifi", "smart_lock"],
            "images": [
                {
                    "file_path": "demo/harbor-edge-cover.jpg",
                    "original_filename": "harbor-edge-cover.jpg",
                    "content_type": "image/jpeg",
                    "size_bytes": 631,
                    "is_cover": True,
                    "sort_order": 1,
                },
                {
                    "file_path": "demo/harbor-edge-lounge.jpg",
                    "original_filename": "harbor-edge-lounge.jpg",
                    "content_type": "image/jpeg",
                    "size_bytes": 631,
                    "is_cover": False,
                    "sort_order": 2,
                },
            ],
        },
    )

    assert create_response.status_code == 200
    created_unit = create_response.json()
    assert len(created_unit["images"]) == 2
    assert {amenity["code"] for amenity in created_unit["amenities"]} == {"wifi", "smart_lock"}

    detail_response = client.get(f"/api/v1/units/{created_unit['id']}", headers=AUTH_HEADERS)
    assert detail_response.status_code == 200
    detail = detail_response.json()
    assert detail["images"][0]["file_path"] == "demo/harbor-edge-cover.jpg"
    assert detail["images"][0]["public_url"].endswith("/demo/harbor-edge-cover.jpg")

    update_amenities_response = client.put(
        f"/api/v1/units/{created_unit['id']}/amenities",
        headers=AUTH_HEADERS,
        json={"amenity_codes": ["parking"]},
    )
    assert update_amenities_response.status_code == 200
    assert [amenity["code"] for amenity in update_amenities_response.json()["amenities"]] == [
        "parking"
    ]

    delete_response = client.delete(f"/api/v1/units/{created_unit['id']}", headers=AUTH_HEADERS)
    assert delete_response.status_code == 200
    assert delete_response.json()["is_active"] is False
