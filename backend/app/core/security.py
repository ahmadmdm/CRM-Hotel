from __future__ import annotations

from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.access_control import default_permission_codes_for_roles
from app.core.config import get_settings

pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def create_access_token(
    subject: str,
    user_id: str,
    full_name: str,
    roles: list[str],
    expires_delta: timedelta,
    permissions: list[str] | None = None,
) -> str:
    settings = get_settings()
    expires_at = datetime.now(timezone.utc) + expires_delta
    resolved_permissions = sorted(permissions or default_permission_codes_for_roles(roles))
    payload = {
        "sub": subject,
        "uid": user_id,
        "name": full_name,
        "roles": roles,
        "permissions": resolved_permissions,
        "exp": expires_at,
    }
    return jwt.encode(payload, settings.secret_key, algorithm="HS256")


def decode_token(token: str) -> dict[str, object]:
    settings = get_settings()
    try:
        return jwt.decode(token, settings.secret_key, algorithms=["HS256"])
    except JWTError as exc:
        raise ValueError("Token could not be decoded") from exc
