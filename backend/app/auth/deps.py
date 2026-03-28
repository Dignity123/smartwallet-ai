import os

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError
from sqlalchemy.orm import Session

from app.auth.jwt_tokens import decode_token
from app.database import schemas
from app.database.db import get_db

security = HTTPBearer(auto_error=False)


def auth_enabled() -> bool:
    return os.getenv("AUTH_ENABLED", "false").lower() == "true"


def _demo_user(db: Session) -> schemas.User | None:
    return db.query(schemas.User).filter(schemas.User.id == 1).first()


def get_current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(security),
    db: Session = Depends(get_db),
) -> schemas.User:
    if not auth_enabled():
        u = _demo_user(db)
        if not u:
            raise HTTPException(status_code=500, detail="Demo user not seeded")
        return u

    # AUTH_ENABLED=true: accept a valid Bearer JWT when present.
    if creds and creds.scheme.lower() == "bearer" and creds.credentials:
        try:
            payload = decode_token(creds.credentials)
            uid = int(payload.get("sub", ""))
        except (JWTError, ValueError, TypeError):
            raise HTTPException(status_code=401, detail="Invalid or expired token") from None
        user = db.query(schemas.User).filter(schemas.User.id == uid).first()
        if not user:
            raise HTTPException(status_code=401, detail="User not found")
        return user

    # No Bearer token: optional fallback to demo (Flutter app has no login; physical devices often have no JWT).
    # Production: set ALLOW_ANONYMOUS_DEMO=false to require JWT whenever AUTH_ENABLED=true.
    if os.getenv("ALLOW_ANONYMOUS_DEMO", "true").lower() == "true":
        u = _demo_user(db)
        if u:
            return u

    raise HTTPException(status_code=401, detail="Not authenticated")


def require_uid_matches(user: schemas.User, path_user_id: int) -> None:
    if auth_enabled() and user.id != path_user_id:
        raise HTTPException(status_code=403, detail="Cannot access another user's data")
