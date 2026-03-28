from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import schemas
from app.database.db import get_db
from app.services.plaid_service import get_transactions

router = APIRouter()


class BudgetGoalIn(BaseModel):
    category: str
    monthly_limit: float
    alert_threshold_pct: float = 0.8


class BudgetBulkUpsert(BaseModel):
    goals: list[BudgetGoalIn]


def _month_start():
    from datetime import datetime

    now = datetime.utcnow()
    return datetime(now.year, now.month, 1)


@router.get("/{user_id}")
def list_budgets_with_progress(user_id: int, db: Session = Depends(get_db)):
    user = db.query(schemas.User).filter(schemas.User.id == user_id).first()
    income = float(user.monthly_income) if user and user.monthly_income else 3000.0
    goals = db.query(schemas.BudgetGoal).filter(schemas.BudgetGoal.user_id == user_id).all()
    txns = get_transactions(user_id, days=365, db=db)
    start = _month_start()
    from collections import defaultdict

    spent_mtd: dict[str, float] = defaultdict(float)
    for t in txns:
        from datetime import datetime as dt

        try:
            d = dt.fromisoformat(t["date"].replace("Z", "+00:00"))
            if d.tzinfo:
                d = d.replace(tzinfo=None)
        except Exception:
            continue
        if d >= start:
            spent_mtd[t.get("category") or "Uncategorized"] += float(t.get("amount", 0))

    out = []
    for g in goals:
        spent = spent_mtd.get(g.category, 0.0)
        limit = float(g.monthly_limit)
        pct = (spent / limit * 100) if limit else 0.0
        thr = float(g.alert_threshold_pct) * limit
        out.append(
            {
                "id": g.id,
                "category": g.category,
                "monthly_limit": limit,
                "alert_threshold_pct": float(g.alert_threshold_pct),
                "spent_this_month": round(spent, 2),
                "percent_used": round(pct, 1),
                "alert_at_amount": round(thr, 2),
                "is_over": spent > limit,
                "is_near_limit": spent >= thr and spent <= limit,
            }
        )
    return {"user_id": user_id, "monthly_income": income, "goals": out}


@router.put("/{user_id}")
def upsert_budgets(user_id: int, body: BudgetBulkUpsert, db: Session = Depends(get_db)):
    db.query(schemas.BudgetGoal).filter(schemas.BudgetGoal.user_id == user_id).delete()
    for g in body.goals:
        if g.monthly_limit <= 0:
            continue
        db.add(
            schemas.BudgetGoal(
                user_id=user_id,
                category=g.category.strip(),
                monthly_limit=g.monthly_limit,
                alert_threshold_pct=max(0.1, min(1.0, g.alert_threshold_pct)),
            )
        )
    db.commit()
    from app.services.alert_engine import evaluate_alerts

    evaluate_alerts(db, user_id)
    return list_budgets_with_progress(user_id, db)


@router.post("/{user_id}/single")
def add_single_goal(user_id: int, goal: BudgetGoalIn, db: Session = Depends(get_db)):
    db.add(
        schemas.BudgetGoal(
            user_id=user_id,
            category=goal.category.strip(),
            monthly_limit=goal.monthly_limit,
            alert_threshold_pct=max(0.1, min(1.0, goal.alert_threshold_pct)),
        )
    )
    db.commit()
    from app.services.alert_engine import evaluate_alerts

    evaluate_alerts(db, user_id)
    return list_budgets_with_progress(user_id, db)


@router.delete("/{user_id}/{goal_id}")
def delete_goal(user_id: int, goal_id: int, db: Session = Depends(get_db)):
    row = (
        db.query(schemas.BudgetGoal)
        .filter(schemas.BudgetGoal.id == goal_id, schemas.BudgetGoal.user_id == user_id)
        .first()
    )
    if not row:
        raise HTTPException(status_code=404, detail="Not found")
    db.delete(row)
    db.commit()
    return {"status": "deleted"}
