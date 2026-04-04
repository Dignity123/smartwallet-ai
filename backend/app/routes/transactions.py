from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.auth.deps import get_current_user, require_uid_matches
from app.database import schemas
from app.database.db import get_db
from app.services.expense_categories import STANDARD_CATEGORIES, suggest_category
from app.services.plaid_service import get_account_balance, get_transactions
from app.services.spending_analyzer import summarize_spending
from app.services.spending_trends import trend_buckets

router = APIRouter()


def _category_budget_map(db: Session, user_id: int) -> dict[str, float]:
    goals = db.query(schemas.BudgetGoal).filter(schemas.BudgetGoal.user_id == user_id).all()
    return {g.category: float(g.monthly_limit) for g in goals}


class ManualExpenseIn(BaseModel):
    amount: float = Field(..., gt=0)
    merchant: str = Field(..., min_length=1, max_length=200)
    category: str | None = Field(default=None, max_length=80)
    date: datetime | None = None
    notes: str | None = Field(default=None, max_length=500)


class CategoryPatch(BaseModel):
    category: str = Field(..., min_length=1, max_length=80)


@router.get("/categories")
def list_standard_categories():
    return {"categories": STANDARD_CATEGORIES}


@router.get("/summary/{user_id}")
def transaction_summary(
    user_id: int,
    days: int = 30,
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    require_uid_matches(user, user_id)
    try:
        urow = db.query(schemas.User).filter(schemas.User.id == user_id).first()
        income = float(urow.monthly_income) if urow and urow.monthly_income else 3000.0
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


@router.get("/{user_id}/history")
def transaction_history(
    user_id: int,
    days: int = 90,
    limit: int = 200,
    offset: int = 0,
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    require_uid_matches(user, user_id)
    txns = get_transactions(user_id, days=days, db=db)
    slice_tx = txns[offset : offset + max(1, min(limit, 500))]
    return {"total": len(txns), "offset": offset, "limit": limit, "transactions": slice_tx}


@router.post("/{user_id}/manual")
def add_manual_expense(
    user_id: int,
    body: ManualExpenseIn,
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    require_uid_matches(user, user_id)
    cat = suggest_category(body.merchant, body.category)
    when = body.date or datetime.utcnow()
    row = schemas.Transaction(
        user_id=user_id,
        amount=-abs(float(body.amount)),
        merchant=body.merchant.strip(),
        category=cat,
        date=when,
        is_recurring=False,
        plaid_id=None,
        account_id=None,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    from app.services.plaid_service import _row_to_dict

    return {"transaction": _row_to_dict(row, user_id)}


@router.patch("/{user_id}/{transaction_id}/category")
def recategorize(
    user_id: int,
    transaction_id: int,
    body: CategoryPatch,
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    require_uid_matches(user, user_id)
    row = (
        db.query(schemas.Transaction)
        .filter(schemas.Transaction.id == transaction_id, schemas.Transaction.user_id == user_id)
        .first()
    )
    if not row:
        raise HTTPException(status_code=404, detail="Transaction not found")
    row.category = body.category.strip()
    db.commit()
    db.refresh(row)
    from app.services.plaid_service import _row_to_dict

    return {"transaction": _row_to_dict(row, user_id)}


@router.get("/{user_id}/analytics")
def spending_analytics(
    user_id: int,
    days: int = 90,
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    require_uid_matches(user, user_id)
    urow = db.query(schemas.User).filter(schemas.User.id == user_id).first()
    income = float(urow.monthly_income) if urow and urow.monthly_income else 3000.0
    txns = get_transactions(user_id, days=days, db=db)
    budgets = _category_budget_map(db, user_id)
    summary = summarize_spending(
        txns,
        monthly_income=income,
        category_budgets=budgets if budgets else None,
    )
    trends = trend_buckets(txns, weeks=8, months=6)
    return {
        "summary": summary,
        "trends": trends,
        "period_days": days,
    }
