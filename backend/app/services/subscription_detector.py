"""Infer subscriptions from transaction streams using amount + cadence heuristics."""

from collections import defaultdict
from typing import Any

from app.services.recurring_heuristics import subscriptions_from_transactions


def detect_subscriptions(transactions: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return subscriptions_from_transactions(transactions)


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
