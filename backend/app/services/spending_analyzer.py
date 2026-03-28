from collections import defaultdict
from typing import Optional

# Fallback when user has not set custom category budgets (fraction of monthly income)
CATEGORY_BENCHMARKS = {
    "Food & Drink": 0.15,
    "Groceries": 0.10,
    "Entertainment": 0.05,
    "Shopping": 0.10,
    "Transportation": 0.10,
    "Fitness": 0.03,
    "Software": 0.03,
}


def summarize_spending(
    transactions: list,
    monthly_income: float = 3000.0,
    category_budgets: Optional[dict[str, float]] = None,
) -> dict:
    """
    Aggregate transactions into category totals.
    If `category_budgets` is provided (category -> monthly dollar cap), those are used as benchmarks.
    Otherwise CATEGORY_BENCHMARKS * monthly_income is used.
    """
    by_category = defaultdict(float)
    by_merchant = defaultdict(float)

    for t in transactions:
        by_category[t["category"]] += t["amount"]
        by_merchant[t["merchant"]] += t["amount"]

    total_spend = sum(by_category.values())
    savings_rate = max(0, (monthly_income - total_spend) / monthly_income * 100) if monthly_income else 0.0

    category_insights = []
    for cat, amount in by_category.items():
        if category_budgets and cat in category_budgets:
            benchmark_amount = category_budgets[cat]
        else:
            benchmark = CATEGORY_BENCHMARKS.get(cat, 0.08)
            benchmark_amount = monthly_income * benchmark
        category_insights.append(
            {
                "category": cat,
                "spent": round(amount, 2),
                "benchmark": round(benchmark_amount, 2),
                "over_budget": amount > benchmark_amount,
                "percent_of_budget": round(amount / benchmark_amount * 100, 1) if benchmark_amount else 0.0,
                "percent_of_income": round(amount / monthly_income * 100, 1) if monthly_income else 0.0,
            }
        )

    top_merchants = sorted(
        [{"merchant": k, "total": round(v, 2)} for k, v in by_merchant.items()],
        key=lambda x: x["total"],
        reverse=True,
    )[:5]

    return {
        "total_spend": round(total_spend, 2),
        "monthly_income": monthly_income,
        "savings_rate": round(savings_rate, 1),
        "by_category": category_insights,
        "top_merchants": top_merchants,
        "groceries": by_category.get("Groceries", 0),
        "dining": by_category.get("Food & Drink", 0),
        "income": monthly_income,
        "uses_custom_budgets": bool(category_budgets),
    }
