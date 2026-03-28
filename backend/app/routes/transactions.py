from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database.db import get_db
from app.database import schemas
from app.services.plaid_service import get_account_balance, get_transactions
from app.services.spending_analyzer import summarize_spending

router = APIRouter()


def _category_budget_map(db: Session, user_id: int) -> dict[str, float]:
    goals = db.query(schemas.BudgetGoal).filter(schemas.BudgetGoal.user_id == user_id).all()
    return {g.category: float(g.monthly_limit) for g in goals}


@router.get("/summary/{user_id}")
def transaction_summary(user_id: int, days: int = 30, db: Session = Depends(get_db)):
    try:
        user = db.query(schemas.User).filter(schemas.User.id == user_id).first()
        income = float(user.monthly_income) if user and user.monthly_income else 3000.0
        txns = get_transactions(user_id, days, db=db)
        budgets = _category_budget_map(db, user_id)
        summary = summarize_spending(
            txns,
            monthly_income=income,
            category_budgets=budgets if budgets else None,
        )
        balance = get_account_balance(user_id, db=db)
        return {
            "transactions": txns,
            "summary": summary,
            "balance": balance,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e
