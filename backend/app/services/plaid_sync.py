"""Sync Plaid transactions into local DB and run smart checks."""

from __future__ import annotations

import json
from datetime import datetime
from typing import Any

from sqlalchemy.orm import Session

from app.database import schemas
from app.services.alert_engine import (
    maybe_alert_cancellation_charge,
    maybe_alert_subscription_price_change,
)
from app.services.plaid_core import get_plaid_client, plaid_configured
from app.services.plaid_service import RECURRING_MERCHANTS


def _pfc_to_category(pfc: Any) -> str:
    if not pfc:
        return "Uncategorized"
    if isinstance(pfc, dict):
        return str(pfc.get("primary") or pfc.get("detailed") or "Uncategorized")
    return "Uncategorized"


def _to_dt(date_str: str | None) -> datetime:
    if not date_str:
        return datetime.utcnow()
    try:
        return datetime.fromisoformat(date_str)
    except ValueError:
        return datetime.utcnow()


def upsert_plaid_transaction(db: Session, user_id: int, t: dict[str, Any]) -> bool:
    """Insert or update one Plaid transaction. Returns True if newly inserted."""
    tid = t.get("transaction_id")
    if not tid:
        return False
    existing = db.query(schemas.Transaction).filter(schemas.Transaction.plaid_id == tid).first()
    amt = float(t.get("amount") or 0)
    spend = abs(amt)
    merchant = t.get("merchant_name") or t.get("name") or "Unknown"
    cat = _pfc_to_category(t.get("personal_finance_category"))
    dt = _to_dt(t.get("date"))
    is_rec = merchant in RECURRING_MERCHANTS

    if existing:
        old_amt = float(existing.amount)
        existing.amount = spend
        existing.merchant = merchant
        existing.category = cat
        existing.date = dt
        existing.is_recurring = is_rec
        existing.account_id = t.get("account_id")
        if is_rec and abs(spend - old_amt) > 0.01:
            maybe_alert_subscription_price_change(db, user_id, merchant, old_amt, spend)
        maybe_alert_cancellation_charge(db, user_id, merchant, spend, dt)
        return False

    row = schemas.Transaction(
        user_id=user_id,
        amount=spend,
        merchant=merchant,
        category=cat,
        date=dt,
        is_recurring=is_rec,
        plaid_id=tid,
        account_id=t.get("account_id"),
    )
    db.add(row)
    db.flush()
    if is_rec:
        maybe_alert_subscription_price_change(db, user_id, merchant, 0.0, spend)
    maybe_alert_cancellation_charge(db, user_id, merchant, spend, dt)
    return True


def sync_item_transactions(db: Session, item: schemas.PlaidItem) -> dict[str, Any]:
    if not plaid_configured():
        raise RuntimeError("Plaid is not configured")
    from plaid.model.transactions_sync_request import TransactionsSyncRequest

    client = get_plaid_client()
    cursor = item.transactions_cursor or ""
    total_added = 0
    while True:
        if cursor:
            req = TransactionsSyncRequest(access_token=item.access_token, cursor=cursor)
        else:
            req = TransactionsSyncRequest(access_token=item.access_token)
        resp = client.transactions_sync(req)
        data = resp.to_dict() if hasattr(resp, "to_dict") else dict(resp)

        for t in data.get("added", []):
            if upsert_plaid_transaction(db, item.user_id, t):
                total_added += 1
        for t in data.get("modified", []):
            upsert_plaid_transaction(db, item.user_id, t)
        for rem in data.get("removed", []):
            rid = rem.get("transaction_id")
            if rid:
                db.query(schemas.Transaction).filter(schemas.Transaction.plaid_id == rid).delete()

        cursor = data.get("next_cursor") or ""
        if not data.get("has_more"):
            break

    item.transactions_cursor = cursor
    db.commit()
    return {"added": total_added, "cursor_set": bool(cursor)}


def handle_webhook_payload(payload: dict[str, Any]) -> dict[str, Any]:
    """Process Plaid TRANSACTIONS webhook (fire-and-forget sync for all items on that item_id)."""
    from app.database.db import SessionLocal

    wtype = payload.get("webhook_type")
    if wtype != "TRANSACTIONS":
        return {"status": "ignored", "reason": "not_transactions"}

    item_id = payload.get("item_id")
    if not item_id:
        return {"status": "ignored", "reason": "no_item_id"}

    db = SessionLocal()
    try:
        item = db.query(schemas.PlaidItem).filter(schemas.PlaidItem.item_id == item_id).first()
        if not item:
            return {"status": "ignored", "reason": "unknown_item"}
        result = sync_item_transactions(db, item)
        from app.services.alert_engine import evaluate_alerts

        evaluate_alerts(db, item.user_id)
        return {"status": "synced", **result}
    finally:
        db.close()
