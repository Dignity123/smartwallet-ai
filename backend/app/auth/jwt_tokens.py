from datetime import datetime, timedelta, timezone
from typing import Any

import os

from jose import jwt

JWT_ALG = "HS256"


def _secret() -> str:
    return os.getenv("JWT_SECRET", "dev-only-change-me").strip()


def create_access_token(user_id: int, expires_minutes: int | None = None) -> str:
    if expires_minutes is None:
        expires_minutes = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "10080"))
    now = datetime.now(timezone.utc)
    exp = now + timedelta(minutes=max(5, expires_minutes))
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "iat": int(now.timestamp()),
        "exp": int(exp.timestamp()),
    }
    return jwt.encode(payload, _secret(), algorithm=JWT_ALG)


def decode_token(token: str) -> dict[str, Any]:
    return jwt.decode(token, _secret(), algorithms=[JWT_ALG])
