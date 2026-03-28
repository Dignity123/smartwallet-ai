from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.auth.deps import get_current_user, require_uid_matches
from app.database import schemas
from app.database.db import get_db
from app.services.ai_service import analyze_subscriptions
from app.services.plaid_service import get_transactions
from app.services.subscription_detector import detect_subscriptions, find_duplicate_subscriptions

router = APIRouter()


class CancelIntentBody(BaseModel):
    merchant: str = Field(..., min_length=1, max_length=200)
    amount_snapshot: float | None = Field(default=None, ge=0)


@router.post("/scan")
def scan_subscriptions(
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    try:
        transactions = get_transactions(user.id, days=90, db=db)
        subscriptions = detect_subscriptions(transactions)
        duplicates = find_duplicate_subscriptions(subscriptions)
        ai_analysis = analyze_subscriptions(subscriptions)
        return {
            "subscriptions": subscriptions,
            "duplicates": duplicates,
            "ai_analysis": ai_analysis,
            "total_monthly_cost": sum(s["amount"] for s in subscriptions),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@router.post("/cancel-intent")
def mark_cancel_intent(
    body: CancelIntentBody,
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    key = body.merchant.lower().strip()
    row = schemas.SubscriptionCancellation(
        user_id=user.id,
        merchant_key=key,
        amount_snapshot=body.amount_snapshot,
        marked_at=datetime.utcnow(),
        active=True,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id, "merchant_key": key, "marked_at": row.marked_at.isoformat()}


@router.get("/cancel-intents")
def list_cancel_intents(
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    rows = (
        db.query(schemas.SubscriptionCancellation)
        .filter(schemas.SubscriptionCancellation.user_id == user.id)
        .order_by(schemas.SubscriptionCancellation.marked_at.desc())
        .all()
    )
    return {
        "intents": [
            {
                "id": r.id,
                "merchant_key": r.merchant_key,
                "amount_snapshot": r.amount_snapshot,
                "marked_at": r.marked_at.isoformat() if r.marked_at else None,
                "active": r.active,
            }
            for r in rows
        ]
    }


@router.patch("/cancel-intents/by-id/{intent_id}/deactivate")
def deactivate_cancel_intent(
    intent_id: int,
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    row = (
        db.query(schemas.SubscriptionCancellation)
        .filter(
            schemas.SubscriptionCancellation.id == intent_id,
            schemas.SubscriptionCancellation.user_id == user.id,
        )
        .first()
    )
    if not row:
        raise HTTPException(status_code=404, detail="Not found")
    row.active = False
    db.commit()
    return {"status": "ok"}


@router.get("/{user_id}")
def get_subscriptions(
    user_id: int,
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    require_uid_matches(user, user_id)
    transactions = get_transactions(user_id, days=90, db=db)
    subscriptions = detect_subscriptions(transactions)
    return {"subscriptions": subscriptions}
