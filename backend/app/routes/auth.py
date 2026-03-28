from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy.orm import Session

from app.auth.deps import auth_enabled as server_auth_enabled
from app.auth.deps import get_current_user
from app.auth.google_verify import verify_google_id_token
from app.auth.jwt_tokens import create_access_token
from app.auth.passwords import hash_password, verify_password
from app.database import schemas
from app.database.db import get_db

router = APIRouter()


class RegisterBody(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=6, max_length=256)
    name: str = Field(default="Member", max_length=120)


class LoginBody(BaseModel):
    email: EmailStr
    password: str


class GoogleAuthBody(BaseModel):
    id_token: str = Field(..., min_length=10)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    email: str | None = None
    name: str | None = None
    auth_enabled: bool = False


@router.post("/register", response_model=TokenResponse)
def register(body: RegisterBody, db: Session = Depends(get_db)):
    if db.query(schemas.User).filter(schemas.User.email == body.email.lower()).first():
        raise HTTPException(status_code=400, detail="Email already registered")
    user = schemas.User(
        email=body.email.lower().strip(),
        name=body.name.strip() or "Member",
        monthly_income=0.0,
        hashed_password=hash_password(body.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return TokenResponse(
        access_token=create_access_token(user.id),
        user_id=user.id,
        email=user.email,
        name=user.name,
        auth_enabled=server_auth_enabled(),
    )


@router.post("/login", response_model=TokenResponse)
def login(body: LoginBody, db: Session = Depends(get_db)):
    user = db.query(schemas.User).filter(schemas.User.email == body.email.lower()).first()
    if not user or not verify_password(body.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    return TokenResponse(
        access_token=create_access_token(user.id),
        user_id=user.id,
        email=user.email,
        name=user.name,
        auth_enabled=server_auth_enabled(),
    )


@router.post("/google", response_model=TokenResponse)
def google_auth(body: GoogleAuthBody, db: Session = Depends(get_db)):
    try:
        claims = verify_google_id_token(body.id_token)
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e

    sub = claims.get("sub")
    email = (claims.get("email") or "").lower().strip()
    name = claims.get("name") or email.split("@")[0] if email else "Member"
    if not sub:
        raise HTTPException(status_code=401, detail="Invalid Google token")

    user = db.query(schemas.User).filter(schemas.User.google_sub == sub).first()
    if user is None and email:
        user = db.query(schemas.User).filter(schemas.User.email == email).first()
        if user:
            user.google_sub = sub
            db.commit()
            db.refresh(user)
    if user is None:
        user = schemas.User(
            email=email or f"{sub}@google.local",
            name=str(name)[:120],
            monthly_income=0.0,
            google_sub=sub,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    return TokenResponse(
        access_token=create_access_token(user.id),
        user_id=user.id,
        email=user.email,
        name=user.name,
        auth_enabled=server_auth_enabled(),
    )


@router.get("/me")
def me(user: schemas.User = Depends(get_current_user)):
    return {
        "id": user.id,
        "email": user.email,
        "name": user.name,
        "monthly_income": user.monthly_income,
        "auth_enabled": server_auth_enabled(),
    }
