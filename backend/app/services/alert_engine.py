"""Proactive alerts: budgets, unusual charges, subscription price, cancel tracking."""

from __future__ import annotations

import json
import statistics
from collections import defaultdict
from datetime import datetime, timedelta
from typing import Any

from sqlalchemy.orm import Session

from app.database import schemas


def _create_alert(
    db: Session,
    user_id: int,
    alert_type: str,
    title: str,
    body: str,
    payload: dict[str, Any] | None = None,
) -> None:
    db.add(
        schemas.Alert(
            user_id=user_id,
            alert_type=alert_type,
            title=title,
            body=body,
            payload_json=json.dumps(payload) if payload else None,
        )
    )


def _already_alerted(db: Session, user_id: int, dedupe: str, hours: int = 72) -> bool:
    cutoff = datetime.utcnow() - timedelta(hours=hours)
    rows = (
        db.query(schemas.Alert)
        .filter(schemas.Alert.user_id == user_id, schemas.Alert.created_at >= cutoff)
        .all()
    )
    for a in rows:
        if not a.payload_json:
            continue
        try:
            if json.loads(a.payload_json).get("dedupe") == dedupe:
                return True
        except json.JSONDecodeError:
            continue
    return False


def maybe_alert_subscription_price_change(
    db: Session, user_id: int, merchant: str, old_amount: float, new_amount: float
) -> None:
    if new_amount <= 0 or old_amount <= 0:
        return
    if new_amount < old_amount * 1.08:
        return
    key = merchant.lower().strip()
    dedupe = f"price:{key}:{datetime.utcnow().strftime('%Y-%m')}"
    if _already_alerted(db, user_id, dedupe, hours=24 * 32):
        return
    _create_alert(
        db,
        user_id,
        "subscription_price_increase",
        f"Price change: {merchant}",
        f"Latest charge ${new_amount:.2f} is up from ${old_amount:.2f}. Review your plan or negotiate.",
        {"dedupe": dedupe, "merchant": merchant, "old": old_amount, "new": new_amount},
    )


def maybe_alert_cancellation_charge(
    db: Session, user_id: int, merchant: str, amount: float, txn_date: datetime
) -> None:
    key = merchant.lower().strip()
    pending = (
        db.query(schemas.SubscriptionCancellation)
        .filter(
            schemas.SubscriptionCancellation.user_id == user_id,
            schemas.SubscriptionCancellation.active.is_(True),
            schemas.SubscriptionCancellation.merchant_key == key,
        )
        .all()
    )
    for c in pending:
        if txn_date < c.marked_at:
            continue
        snap = c.amount_snapshot
        if snap is not None and abs(amount - snap) > snap * 0.25 and snap > 0:
            continue
        dedupe = f"cancel_hit:{key}:{txn_date.date().isoformat()}"
        if _already_alerted(db, user_id, dedupe, hours=24 * 35):
            continue
        _create_alert(
            db,
            user_id,
            "cancellation_charge",
            f"Still charged: {merchant}",
            f"We saw a ${amount:.2f} charge after you marked this subscription for cancellation on {c.marked_at.date()}.",
            {"dedupe": dedupe, "merchant": merchant, "amount": amount},
        )


def _budget_alerts(db: Session, user_id: int) -> int:
    goals = db.query(schemas.BudgetGoal).filter(schemas.BudgetGoal.user_id == user_id).all()
    if not goals:
        return 0
    start = datetime.utcnow().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    txns = (
        db.query(schemas.Transaction)
        .filter(schemas.Transaction.user_id == user_id, schemas.Transaction.date >= start)
        .all()
    )
    by_cat: dict[str, float] = defaultdict(float)
    for t in txns:
        by_cat[t.category or "Uncategorized"] += abs(float(t.amount))

    n = 0
    for g in goals:
        spent = by_cat.get(g.category, 0.0)
        limit = float(g.monthly_limit)
        if limit <= 0:
            continue
        thr = float(g.alert_threshold_pct) * limit
        pct = spent / limit * 100
        month_key = start.strftime("%Y-%m")

        if spent >= limit:
            dedupe = f"budget_over:{g.category}:{month_key}"
            if not _already_alerted(db, user_id, dedupe, hours=24 * 32):
                _create_alert(
                    db,
                    user_id,
                    "budget_exceeded",
                    f"{g.category} over budget",
                    f"You've spent ${spent:.2f} vs ${limit:.2f} limit ({pct:.0f}%).",
                    {"dedupe": dedupe, "category": g.category},
                )
                n += 1
        elif spent >= thr:
            dedupe = f"budget_warn:{g.category}:{month_key}"
            if not _already_alerted(db, user_id, dedupe, hours=24 * 10):
                _create_alert(
                    db,
                    user_id,
                    "budget_warning",
                    f"{g.category} at {pct:.0f}%",
                    f"You've used about {pct:.0f}% of your ${limit:.2f} monthly budget (${spent:.2f} spent).",
                    {"dedupe": dedupe, "category": g.category},
                )
                n += 1
    return n


def _unusual_charge_alerts(db: Session, user_id: int) -> int:
    cutoff_hist = datetime.utcnow() - timedelta(days=90)
    txns = (
        db.query(schemas.Transaction)
        .filter(schemas.Transaction.user_id == user_id, schemas.Transaction.date >= cutoff_hist)
        .all()
    )
    by_m: dict[str, list[float]] = defaultdict(list)
    for t in txns:
        by_m[(t.merchant or "").lower().strip()].append(abs(float(t.amount)))

    recent_cut = datetime.utcnow() - timedelta(days=4)
    recent = (
        db.query(schemas.Transaction)
        .filter(schemas.Transaction.user_id == user_id, schemas.Transaction.date >= recent_cut)
        .order_by(schemas.Transaction.date.desc())
        .limit(40)
        .all()
    )

    n = 0
    for t in recent:
        mkey = (t.merchant or "").lower().strip()
        amounts = by_m.get(mkey, [])
        if len(amounts) < 4:
            continue
        cur = abs(float(t.amount))
        med = float(statistics.median(amounts))
        if med <= 0:
            continue
        if cur < med * 2.5:
            continue
        tid = t.plaid_id or str(t.id)
        dedupe = f"unusual:{tid}"
        if _already_alerted(db, user_id, dedupe, hours=24 * 14):
            continue
        _create_alert(
            db,
            user_id,
            "unusual_charge",
            f"Unusual charge: {t.merchant}",
            f"${cur:.2f} is well above your typical ~${med:.2f} at this merchant.",
            {"dedupe": dedupe, "transaction_id": tid},
        )
        n += 1
    return n


def evaluate_alerts(db: Session, user_id: int) -> int:
    """Run all pull-based checks and persist new alerts."""
    n = 0
    n += _budget_alerts(db, user_id)
    n += _unusual_charge_alerts(db, user_id)
    db.commit()
    return n
