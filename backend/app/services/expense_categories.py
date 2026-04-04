"""Heuristic category suggestion from merchant text (manual + auto-label)."""

import re

STANDARD_CATEGORIES = [
    "Food & Drink",
    "Groceries",
    "Transportation",
    "Shopping",
    "Entertainment",
    "Bills & Utilities",
    "Health",
    "Software",
    "Fitness",
    "Travel",
    "Uncategorized",
]

_RULES: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"grocery|whole foods|safeway|kroger|aldi|trader", re.I), "Groceries"),
    (re.compile(r"uber|lyft|taxi|metro|transit|shell|gas|fuel|parking", re.I), "Transportation"),
    (re.compile(r"netflix|spotify|hulu|disney|cinema|streaming|game", re.I), "Entertainment"),
    (re.compile(r"amazon|target|walmart|nike|shop|mall|boutique", re.I), "Shopping"),
    (re.compile(r"electric|water|internet|phone|utility|rent|mortgage", re.I), "Bills & Utilities"),
    (re.compile(r"pharmacy|hospital|clinic|doctor|dental|cvs|walgreens", re.I), "Health"),
    (re.compile(r"gym|fitness|peloton", re.I), "Fitness"),
    (re.compile(r"hotel|airline|flight|airbnb", re.I), "Travel"),
    (re.compile(r"coffee|starbucks|restaurant|cafe|doordash|grubhub|food", re.I), "Food & Drink"),
]


def suggest_category(merchant: str, hint: str | None = None) -> str:
    if hint and hint.strip():
        s = hint.strip()
        for c in STANDARD_CATEGORIES:
            if s.lower() == c.lower():
                return c
        if s.title() in STANDARD_CATEGORIES:
            return s.title()
    m = (merchant or "").strip()
    if not m:
        return "Uncategorized"
    for pat, cat in _RULES:
        if pat.search(m):
            return cat
    return "Uncategorized"
