"""Weekly / monthly aggregates for analytics."""

from collections import defaultdict
from datetime import datetime, timedelta

from app.services.spending_analyzer import _parse_txn_date


def trend_buckets(transactions: list, weeks: int = 8, months: int = 6) -> dict:
    """Return weekly_totals, monthly_totals, and category_month_to_date."""
    now = datetime.utcnow()
    week_start = now - timedelta(days=now.weekday())
    week_start = week_start.replace(hour=0, minute=0, second=0, microsecond=0)

    weekly: dict[str, float] = defaultdict(float)
    monthly: dict[str, float] = defaultdict(float)
    cat_mtd: dict[str, float] = defaultdict(float)

    month_key_cur = f"{now.year:04d}-{now.month:02d}"

    for t in transactions:
        d = _parse_txn_date(t)
        if d is None:
            continue
        amt = float(t.get("amount") or 0)
        iso = d.isocalendar()
        wk = f"{iso.year}-W{iso.week:02d}"
        if d >= week_start - timedelta(weeks=weeks) * 7:
            weekly[wk] += amt
        mk = f"{d.year:04d}-{d.month:02d}"
        if d >= datetime(now.year, now.month, 1) - timedelta(days=32 * months):
            monthly[mk] += amt
        if mk == month_key_cur:
            cat = t.get("category") or "Uncategorized"
            cat_mtd[cat] += amt

    def sort_slice(d: dict[str, float], n: int) -> list[dict[str, float]]:
        keys = sorted(d.keys(), reverse=True)[:n]
        return [{"period": k, "total": round(d[k], 2)} for k in keys]

    return {
        "weekly": sort_slice(dict(weekly), weeks),
        "monthly": sort_slice(dict(monthly), months),
        "category_this_month": [{"category": k, "spent": round(v, 2)} for k, v in sorted(cat_mtd.items(), key=lambda x: -x[1])],
    }
