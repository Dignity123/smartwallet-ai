from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.auth.deps import get_current_user, require_uid_matches
from app.database import schemas
from app.database.db import get_db
from app.services.ai_service import analyze_subscriptions, generate_recommendations
from app.services.plaid_service import get_transactions
from app.services.spending_analyzer import summarize_spending
from app.services.subscription_detector import detect_subscriptions

router = APIRouter()


class RecommendationsRequest(BaseModel):
    user_id: int = 1


@router.post("/")
def post_recommendations(
    req: RecommendationsRequest,
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    require_uid_matches(user, req.user_id)
    try:
        u = db.query(schemas.User).filter(schemas.User.id == req.user_id).first()
        income = float(u.monthly_income) if u and u.monthly_income else 3000.0
        transactions = get_transactions(req.user_id, days=45, db=db)
        summary = summarize_spending(transactions, monthly_income=income)
        subs = detect_subscriptions(transactions)
        sub_ai = analyze_subscriptions(subs)
        recs = generate_recommendations(summary, sub_ai)
        tips = "\n\n".join(f"{r.get('title', '')}: {r.get('description', '')}" for r in recs)
        return {"summary": summary, "tips": tips, "recommendations": recs}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@router.get("/{user_id}")
def get_recommendations_get(
    user_id: int,
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    return post_recommendations(RecommendationsRequest(user_id=user_id), db, user)
