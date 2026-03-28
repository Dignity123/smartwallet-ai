"""Detect recurring charges from amount + cadence patterns (no merchant allowlist)."""

from __future__ import annotations

from collections import defaultdict
from datetime import datetime
from typing import Any

# Amounts within this relative band (or abs floor) are treated as the same subscription tier.
_REL_TOL = 0.04
_ABS_TOL = 0.75

# Gap days for cadence detection
_MONTHLY_MIN, MONTHLY_MAX = 22, 40
_WEEKLY_MIN, WEEKLY_MAX = 5, 11


def normalize_merchant_key(name: str | None) -> str:
    return (name or "").lower().strip()


def _parse_date(t: dict[str, Any]) -> datetime | None:
    raw = t.get("date")
    if raw is None:
        return None
    if isinstance(raw, datetime):
        d = raw
    else:
        s = str(raw).replace("Z", "+00:00")
        try:
            d = datetime.fromisoformat(s)
        except ValueError:
            return None
    if d.tzinfo:
        d = d.replace(tzinfo=None)
    return d


def amounts_close(a: float, b: float) -> bool:
    if a <= 0 or b <= 0:
        return False
    return abs(a - b) <= max(_ABS_TOL, _REL_TOL * max(a, b))


def _cluster_by_amount(txs: list[dict[str, Any]]) -> list[list[dict[str, Any]]]:
    """Greedy clusters: each cluster has mutually amount-compatible txs."""
    sorted_txs = sorted(txs, key=lambda x: float(x.get("amount") or 0))
    groups: list[list[dict[str, Any]]] = []
    for t in sorted_txs:
        amt = float(t.get("amount") or 0)
        if amt <= 0:
            continue
        placed = False
        for g in groups:
            ref = float(g[0].get("amount") or 0)
            if amounts_close(amt, ref):
                g.append(t)
                placed = True
                break
        if not placed:
            groups.append([t])
    return groups


def _infer_frequency(dates: list[datetime]) -> str | None:
    if len(dates) < 2:
        return None
    ordered = sorted(dates)
    gaps = [(ordered[i + 1] - ordered[i]).days for i in range(len(ordered) - 1)]
    monthly_hits = sum(1 for g in gaps if _MONTHLY_MIN <= g <= _MONTHLY_MAX)
    weekly_hits = sum(1 for g in gaps if _WEEKLY_MIN <= g <= _WEEKLY_MAX)
    span = (ordered[-1] - ordered[0]).days

    if len(ordered) >= 3 and weekly_hits >= 2:
        return "weekly"
    if len(ordered) >= 2 and monthly_hits >= 1:
        return "monthly"
    if len(ordered) >= 3 and span >= 50 and max(gaps) >= 25:
        return "monthly"
    if len(ordered) == 2 and span >= _MONTHLY_MIN:
        return "monthly"
    return None


def find_recurring_clusters(transactions: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """
    Return subscription-like clusters: merchant display name, avg amount, frequency, txn ids.
    """
    by_mkey: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for t in transactions:
        mkey = normalize_merchant_key(t.get("merchant"))
        if not mkey:
            continue
        by_mkey[mkey].append(t)

    out: list[dict[str, Any]] = []
    for mkey, txs in by_mkey.items():
        for group in _cluster_by_amount(txs):
            if len(group) < 2:
                continue
            dated: list[tuple[datetime, dict[str, Any]]] = []
            for t in group:
                d = _parse_date(t)
                if d is not None:
                    dated.append((d, t))
            if len(dated) < 2:
                continue
            dated.sort(key=lambda x: x[0])
            dates = [d for d, _ in dated]
            freq = _infer_frequency(dates)
            if not freq:
                continue
            amounts = [float(x.get("amount") or 0) for _, x in dated]
            avg = sum(amounts) / len(amounts)
            first = dated[0][1]
            out.append(
                {
                    "merchant": first.get("merchant") or mkey,
                    "merchant_key": mkey,
                    "amount": round(avg, 2),
                    "frequency": freq,
                    "category": first.get("category") or "Other",
                    "charges_seen": len(dated),
                    "transaction_ids": [str(x.get("id", "")) for _, x in dated if x.get("id") is not None],
                }
            )
    out.sort(key=lambda s: s["amount"], reverse=True)
    return out


def recurring_transaction_ids(transactions: list[dict[str, Any]]) -> set[str]:
    ids: set[str] = set()
    for c in find_recurring_clusters(transactions):
        for tid in c.get("transaction_ids") or []:
            if tid:
                ids.add(tid)
    return ids


def subscriptions_from_transactions(transactions: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Shape expected by subscription scan API."""
    subs: list[dict[str, Any]] = []
    for c in find_recurring_clusters(transactions):
        subs.append(
            {
                "merchant": c["merchant"],
                "amount": c["amount"],
                "category": c.get("category", "Other"),
                "frequency": c.get("frequency", "monthly"),
                "charges_seen": c.get("charges_seen", 0),
                "is_active": True,
            }
        )
    return subs


def recompute_is_recurring_flags(db: Any, user_id: int, days: int = 120) -> int:
    """Set Transaction.is_recurring from heuristics. Returns number of rows updated."""
    from datetime import timedelta

    from app.database import schemas
    cutoff = datetime.utcnow() - timedelta(days=days)
    rows = (
        db.query(schemas.Transaction)
        .filter(
            schemas.Transaction.user_id == user_id,
            schemas.Transaction.date >= cutoff,
        )
        .all()
    )
    if not rows:
        return 0

    txs = [
        {
            "id": str(r.id),
            "merchant": r.merchant or "",
            "amount": abs(float(r.amount or 0)),
            "category": r.category or "Uncategorized",
            "date": r.date.isoformat() if r.date else "",
        }
        for r in rows
    ]
    recurring_ids = recurring_transaction_ids(txs)
    updated = 0
    for r in rows:
        flag = str(r.id) in recurring_ids
        if bool(r.is_recurring) != flag:
            r.is_recurring = flag
            updated += 1
    if updated:
        db.commit()
    return updated
