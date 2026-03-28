from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database.db import get_db
from app.database import schemas
from app.services.ai_service import analyze_subscriptions, generate_recommendations
from app.services.plaid_service import get_transactions
from app.services.spending_analyzer import summarize_spending
from app.services.subscription_detector import detect_subscriptions

router = APIRouter()


class RecommendationsRequest(BaseModel):
    user_id: int = 1


@router.post("/")
def get_recommendations(req: RecommendationsRequest, db: Session = Depends(get_db)):
    try:
        user = db.query(schemas.User).filter(schemas.User.id == req.user_id).first()
        income = float(user.monthly_income) if user and user.monthly_income else 3000.0
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
def get_recommendations_get(user_id: int, db: Session = Depends(get_db)):
    return get_recommendations(RecommendationsRequest(user_id=user_id), db)
