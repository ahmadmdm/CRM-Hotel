from __future__ import annotations

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "CrmHotel API"
    app_env: str = "local"
    api_v1_prefix: str = "/api/v1"
    secret_key: str = "change-me"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 14
    seed_demo_data: bool = True
    demo_user_password: str = "ChangeMe123!"
    database_url: str = "sqlite:///./crmhotel.db"
    redis_url: str = "redis://localhost:6379/0"
    media_root: str = "./media"
    media_url_path: str = "/media"
    media_public_base_url: str = "http://127.0.0.1:8000/media"
    allowed_origins: str = "http://localhost:3000,http://localhost:3001,http://localhost:3004,http://localhost:3005,http://localhost:5173,http://localhost:8080,http://127.0.0.1:3000,http://127.0.0.1:3001,http://127.0.0.1:3004,http://127.0.0.1:3005,http://127.0.0.1:5173,http://127.0.0.1:8080"
    local_origin_regex: str = r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"
    super_admin_email: str = "admin@crmhotel.example.com"
    super_admin_password: str = "ChangeMe123!"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    @property
    def allowed_origins_list(self) -> list[str]:
        if self.allowed_origins == "*":
            return ["*"]
        return [item.strip() for item in self.allowed_origins.split(",") if item.strip()]

    @property
    def normalized_media_public_base_url(self) -> str:
        return self.media_public_base_url.rstrip("/")


@lru_cache
def get_settings() -> Settings:
    return Settings()
