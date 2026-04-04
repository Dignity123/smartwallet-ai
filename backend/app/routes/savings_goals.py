from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.auth.deps import get_current_user, require_uid_matches
from app.database import schemas
from app.database.db import get_db

router = APIRouter()


class SavingsGoalBody(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    target_amount: float = Field(..., gt=0)
    saved_amount: float = Field(default=0.0, ge=0)
    icon_code_point: int | None = None


class SavingsGoalPatch(BaseModel):
    name: str | None = Field(default=None, max_length=120)
    target_amount: float | None = Field(default=None, gt=0)
    saved_amount: float | None = Field(default=None, ge=0)
    icon_code_point: int | None = None


def _to_out(g: schemas.SavingsTarget) -> dict:
    return {
        "id": g.id,
        "name": g.name,
        "target_amount": float(g.target_amount),
        "saved_amount": float(g.saved_amount or 0),
        "icon_code_point": g.icon_code_point,
        "progress_pct": min(
            100.0,
            round(100.0 * float(g.saved_amount or 0) / float(g.target_amount), 1) if g.target_amount else 0.0,
        ),
        "created_at": g.created_at.isoformat() if g.created_at else None,
    }


@router.get("/{user_id}")
def list_goals(
    user_id: int,
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    require_uid_matches(user, user_id)
    rows = (
        db.query(schemas.SavingsTarget)
        .filter(schemas.SavingsTarget.user_id == user_id)
        .order_by(schemas.SavingsTarget.created_at.desc())
        .all()
    )
    return {"goals": [_to_out(g) for g in rows]}


@router.post("/{user_id}")
def create_goal(
    user_id: int,
    body: SavingsGoalBody,
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    require_uid_matches(user, user_id)
    g = schemas.SavingsTarget(
        user_id=user_id,
        name=body.name.strip(),
        target_amount=body.target_amount,
        saved_amount=min(body.saved_amount, body.target_amount),
        icon_code_point=body.icon_code_point,
    )
    db.add(g)
    db.commit()
    db.refresh(g)
    return _to_out(g)


@router.patch("/{user_id}/{goal_id}")
def patch_goal(
    user_id: int,
    goal_id: int,
    body: SavingsGoalPatch,
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    require_uid_matches(user, user_id)
    g = (
        db.query(schemas.SavingsTarget)
        .filter(schemas.SavingsTarget.id == goal_id, schemas.SavingsTarget.user_id == user_id)
        .first()
    )
    if not g:
        raise HTTPException(status_code=404, detail="Goal not found")
    if body.name is not None:
        g.name = body.name.strip()
    if body.target_amount is not None:
        g.target_amount = body.target_amount
    if body.saved_amount is not None:
        g.saved_amount = body.saved_amount
    if body.icon_code_point is not None:
        g.icon_code_point = body.icon_code_point
    db.commit()
    db.refresh(g)
    return _to_out(g)


@router.delete("/{user_id}/{goal_id}")
def delete_goal(
    user_id: int,
    goal_id: int,
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    require_uid_matches(user, user_id)
    g = (
        db.query(schemas.SavingsTarget)
        .filter(schemas.SavingsTarget.id == goal_id, schemas.SavingsTarget.user_id == user_id)
        .first()
    )
    if not g:
        raise HTTPException(status_code=404, detail="Goal not found")
    db.delete(g)
    db.commit()
    return {"ok": True}
