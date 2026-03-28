from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database.db import get_db
from app.database import schemas
from app.services.ai_service import analyze_impulse_purchase
from app.services.plaid_service import get_transactions
from app.services.spending_analyzer import summarize_spending

router = APIRouter()


class ImpulseRequest(BaseModel):
    user_id: int = 1
    income: float = 3000.0
    item: str
    price: float


@router.post("/")
def check_impulse(body: ImpulseRequest, db: Session = Depends(get_db)):
    try:
        user = db.query(schemas.User).filter(schemas.User.id == body.user_id).first()
        uid = body.user_id
        txns = get_transactions(uid, days=30, db=db)
        inc = float(body.income)
        if user and user.monthly_income:
            inc = float(user.monthly_income)
        summary = summarize_spending(txns, monthly_income=inc)
        user_spending = {
            "groceries": summary.get("groceries", 0),
            "dining": summary.get("dining", 0),
            "income": inc,
            "savings_rate": summary.get("savings_rate", 0),
        }
        analysis = analyze_impulse_purchase(body.item, body.price, user_spending)
        msg = analysis.get("emotional_insight") or analysis.get("comparison") or ""
        return {"message": msg, "analysis": analysis}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e
