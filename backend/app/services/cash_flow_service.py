"""Forecast next-month spend from recurring + variable history; rough overdraft risk."""

from __future__ import annotations

from collections import defaultdict
from statistics import mean
from typing import Any

from sqlalchemy.orm import Session

from app.services.plaid_service import get_account_balance, get_transactions


def forecast_cash_flow(user_id: int, db: Session) -> dict[str, Any]:
    txns = get_transactions(user_id, days=90, db=db)
    rec_by_merchant: dict[str, list[float]] = defaultdict(list)
    variable_by_month: dict[str, float] = defaultdict(float)

    for t in txns:
        amt = float(t.get("amount", 0))
        dstr = (t.get("date") or "")[:7]
        is_rec = bool(t.get("is_recurring"))
        if is_rec:
            m = t.get("merchant") or "?"
            rec_by_merchant[m].append(amt)
        elif dstr and len(dstr) >= 7:
            variable_by_month[dstr] += amt

    recurring_monthly = round(sum(max(v) for v in rec_by_merchant.values() if v), 2)
    var_vals = list(variable_by_month.values())
    variable_monthly = round(mean(var_vals), 2) if var_vals else 0.0

    projected_spend = round(recurring_monthly + variable_monthly, 2)
    balance = get_account_balance(user_id, db=db)
    available = float(balance.get("available") or 0)

    days_ahead = 30
    daily_burn = projected_spend / 30 if projected_spend else 0
    projected_end = available - (daily_burn * days_ahead)

    risk = "low"
    if projected_end < 0:
        risk = "high"
    elif projected_end < max(available * 0.1, 50):
        risk = "medium"

    return {
        "recurring_monthly_estimate": recurring_monthly,
        "variable_monthly_estimate": variable_monthly,
        "projected_next_month_spend": projected_spend,
        "current_available_balance": available,
        "projected_balance_in_30d": round(projected_end, 2),
        "overdraft_risk": risk,
        "assumptions": "Recurring = sum of max observed charge per merchant (90d). Variable = average of monthly non-recurring totals.",
    }
