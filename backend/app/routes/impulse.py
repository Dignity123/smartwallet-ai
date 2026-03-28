from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, field_validator
from sqlalchemy.orm import Session

from app.auth.deps import get_current_user
from app.database import schemas
from app.database.db import get_db
from app.services.ai_service import analyze_impulse_purchase
from app.services.plaid_service import get_transactions
from app.services.spending_analyzer import category_totals_last_days, summarize_spending

router = APIRouter()


class ImpulseRequest(BaseModel):
    item: str = Field(..., min_length=1, max_length=200)
    price: float = Field(..., gt=0, le=9_999_999)
    income_override: float | None = Field(default=None, gt=0, le=9_999_999)

    @field_validator("item")
    @classmethod
    def strip_item(cls, v: str) -> str:
        s = v.strip()
        if not s:
            raise ValueError("Item cannot be empty")
        return s


def _budget_map(db: Session, user_id: int) -> dict[str, float]:
    goals = db.query(schemas.BudgetGoal).filter(schemas.BudgetGoal.user_id == user_id).all()
    return {g.category: float(g.monthly_limit) for g in goals}


def _pattern_narrative(recent: dict[str, float]) -> str:
    parts: list[str] = []
    shop = recent.get("Shopping", 0) or 0
    dine = recent.get("Food & Drink", 0) or 0
    ent = recent.get("Entertainment", 0) or 0
    if shop >= 100:
        parts.append(f"Shopping is about ${shop:.0f} in the last 7 days.")
    if dine >= 120:
        parts.append(f"Dining / food & drink is about ${dine:.0f} this week.")
    if ent >= 80:
        parts.append(f"Entertainment spend is about ${ent:.0f} this week.")
    return " ".join(parts)


@router.post("/")
def check_impulse(
    body: ImpulseRequest,
    user: schemas.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        uid = user.id
        txns = get_transactions(uid, days=40, db=db)
        inc = float(body.income_override) if body.income_override is not None else 3000.0
        if user.monthly_income:
            inc = float(user.monthly_income)
        budgets = _budget_map(db, uid)
        summary = summarize_spending(
            txns,
            monthly_income=inc,
            category_budgets=budgets if budgets else None,
        )
        recent = category_totals_last_days(txns, 7)
        user_spending = {
            "groceries": summary.get("groceries", 0),
            "dining": summary.get("dining", 0),
            "income": inc,
            "savings_rate": summary.get("savings_rate", 0),
            "last_7_days_by_category": recent,
            "shopping_last_7_days": float(recent.get("Shopping", 0) or 0),
            "dining_last_7_days": float(recent.get("Food & Drink", 0) or 0),
            "pattern_narrative": _pattern_narrative(recent),
        }
        analysis = analyze_impulse_purchase(body.item, body.price, user_spending)
        msg = analysis.get("emotional_insight") or analysis.get("comparison") or ""
        return {
            "message": msg,
            "analysis": analysis,
            "spending_context": {
                "last_7_days_by_category": recent,
                "shopping_last_7_days": user_spending["shopping_last_7_days"],
                "dining_last_7_days": user_spending["dining_last_7_days"],
                "pattern_narrative": user_spending["pattern_narrative"],
            },
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e
