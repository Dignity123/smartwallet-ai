"""Heuristics to infer subscriptions from transaction streams."""

from collections import defaultdict
from typing import Any


def detect_subscriptions(transactions: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_merchant: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for t in transactions:
        if t.get("is_recurring"):
            by_merchant[t["merchant"]].append(t)

    result: list[dict[str, Any]] = []
    for merchant, rows in by_merchant.items():
        amounts = [float(r["amount"]) for r in rows]
        avg = sum(amounts) / len(amounts)
        result.append(
            {
                "merchant": merchant,
                "amount": round(avg, 2),
                "category": rows[0].get("category", "Other"),
                "frequency": "monthly",
                "charges_seen": len(rows),
                "is_active": True,
            }
        )
    return sorted(result, key=lambda s: s["amount"], reverse=True)


def find_duplicate_subscriptions(subscriptions: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_category: dict[str, list[str]] = defaultdict(list)
    for s in subscriptions:
        cat = s.get("category") or "Other"
        by_category[cat].append(s["merchant"])

    duplicates: list[dict[str, Any]] = []
    overlap_categories = frozenset({"Entertainment", "Software", "Fitness"})
    for category, merchants in by_category.items():
        uniq = sorted(set(merchants))
        if len(uniq) > 1 and category in overlap_categories:
            duplicates.append(
                {
                    "category": category,
                    "merchants": uniq,
                    "note": f"Multiple {category.lower()} subscriptions; consider consolidating.",
                }
            )
    return duplicates
