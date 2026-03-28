import os
from datetime import datetime, timedelta
from typing import Any, Optional

from dotenv import load_dotenv
from sqlalchemy.orm import Session

from app.database import schemas
from app.database.db import SessionLocal
from app.services.plaid_core import get_plaid_client, plaid_configured

load_dotenv()

USE_MOCK = os.getenv("USE_MOCK_DATA", "true").lower() == "true"

MOCK_TRANSACTIONS = [
    {"id": "t1", "merchant": "Starbucks", "amount": 6.50, "category": "Food & Drink", "date": (datetime.now() - timedelta(days=1)).isoformat()},
    {"id": "t2", "merchant": "Netflix", "amount": 15.99, "category": "Entertainment", "date": (datetime.now() - timedelta(days=3)).isoformat()},
    {"id": "t3", "merchant": "Spotify", "amount": 9.99, "category": "Entertainment", "date": (datetime.now() - timedelta(days=3)).isoformat()},
    {"id": "t4", "merchant": "Amazon Prime", "amount": 14.99, "category": "Shopping", "date": (datetime.now() - timedelta(days=5)).isoformat()},
    {"id": "t5", "merchant": "Hulu", "amount": 12.99, "category": "Entertainment", "date": (datetime.now() - timedelta(days=5)).isoformat()},
    {"id": "t6", "merchant": "Whole Foods", "amount": 87.34, "category": "Groceries", "date": (datetime.now() - timedelta(days=6)).isoformat()},
    {"id": "t7", "merchant": "Nike.com", "amount": 129.00, "category": "Shopping", "date": (datetime.now() - timedelta(days=7)).isoformat()},
    {"id": "t8", "merchant": "Gym Membership", "amount": 40.00, "category": "Fitness", "date": (datetime.now() - timedelta(days=10)).isoformat()},
    {"id": "t9", "merchant": "Adobe Creative Cloud", "amount": 54.99, "category": "Software", "date": (datetime.now() - timedelta(days=12)).isoformat()},
    {"id": "t10", "merchant": "Starbucks", "amount": 7.25, "category": "Food & Drink", "date": (datetime.now() - timedelta(days=2)).isoformat()},
    {"id": "t11", "merchant": "Starbucks", "amount": 6.75, "category": "Food & Drink", "date": (datetime.now() - timedelta(days=4)).isoformat()},
    {"id": "t12", "merchant": "DoorDash", "amount": 42.10, "category": "Food & Drink", "date": (datetime.now() - timedelta(days=2)).isoformat()},
    {"id": "t13", "merchant": "Peacock", "amount": 5.99, "category": "Entertainment", "date": (datetime.now() - timedelta(days=15)).isoformat()},
    {"id": "t14", "merchant": "LinkedIn Premium", "amount": 39.99, "category": "Software", "date": (datetime.now() - timedelta(days=20)).isoformat()},
    {"id": "t15", "merchant": "Shell Gas", "amount": 68.00, "category": "Transportation", "date": (datetime.now() - timedelta(days=8)).isoformat()},
]

RECURRING_MERCHANTS = {
    "Netflix",
    "Spotify",
    "Amazon Prime",
    "Hulu",
    "Gym Membership",
    "Adobe Creative Cloud",
    "Peacock",
    "LinkedIn Premium",
}


def _row_to_dict(r: schemas.Transaction, user_id: int) -> dict[str, Any]:
    return {
        "id": str(r.id),
        "merchant": r.merchant or "Unknown",
        "amount": abs(float(r.amount)),
        "category": r.category or "Uncategorized",
        "date": r.date.isoformat() if r.date else "",
        "user_id": user_id,
        "is_recurring": bool(r.is_recurring),
    }


def get_transactions(user_id: int, days: int = 30, db: Optional[Session] = None) -> list[dict[str, Any]]:
    close = False
    if db is None:
        db = SessionLocal()
        close = True
    try:
        cutoff = datetime.utcnow() - timedelta(days=days)
        rows = (
            db.query(schemas.Transaction)
            .filter(
                schemas.Transaction.user_id == user_id,
                schemas.Transaction.date >= cutoff,
            )
            .order_by(schemas.Transaction.date.desc())
            .all()
        )
        if rows:
            return [_row_to_dict(r, user_id) for r in rows]
        if USE_MOCK:
            return [
                {
                    **t,
                    "user_id": user_id,
                    "is_recurring": t["merchant"] in RECURRING_MERCHANTS,
                }
                for t in MOCK_TRANSACTIONS
            ]
        return []
    finally:
        if close:
            db.close()


def get_account_balance(user_id: int, db: Optional[Session] = None) -> dict[str, Any]:
    close = False
    if db is None:
        db = SessionLocal()
        close = True
    try:
        items = db.query(schemas.PlaidItem).filter(schemas.PlaidItem.user_id == user_id).all()
        if not items:
            if USE_MOCK:
                return {"available": 2340.50, "current": 2890.00, "currency": "USD"}
            return {"available": 0.0, "current": 0.0, "currency": "USD"}
        if not plaid_configured():
            return {"available": 0.0, "current": 0.0, "currency": "USD", "note": "Plaid credentials missing"}

        client = get_plaid_client()
        from plaid.model.accounts_balance_get_request import AccountsBalanceGetRequest

        total_avail = 0.0
        total_curr = 0.0
        for item in items:
            req = AccountsBalanceGetRequest(access_token=item.access_token)
            resp = client.accounts_balance_get(req)
            data = resp.to_dict() if hasattr(resp, "to_dict") else dict(resp)
            for acc in data.get("accounts", []):
                b = acc.get("balances") or {}
                total_avail += float(b.get("available") or 0)
                total_curr += float(b.get("current") or 0)
        return {
            "available": round(total_avail, 2),
            "current": round(total_curr, 2),
            "currency": "USD",
        }
    finally:
        if close:
            db.close()


def user_has_plaid(user_id: int, db: Optional[Session] = None) -> bool:
    close = False
    if db is None:
        db = SessionLocal()
        close = True
    try:
        n = db.query(schemas.PlaidItem).filter(schemas.PlaidItem.user_id == user_id).count()
        return n > 0
    finally:
        if close:
            db.close()
