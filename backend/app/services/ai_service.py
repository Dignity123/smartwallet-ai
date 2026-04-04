import json
import logging
import os
import re
from typing import Any

from dotenv import load_dotenv
from openai import OpenAI

load_dotenv()

logger = logging.getLogger(__name__)

_DEFAULT_MODEL = "gpt-4o-mini"


def _user_visible_openai_error(exc: BaseException) -> str:
    """Turn SDK/API failures into text we can show in chat (never raises)."""
    raw = str(exc)
    low = raw.lower()
    if "429" in raw or "rate" in low and "limit" in low or "quota" in low:
        return (
            "The AI could not run because OpenAI returned a rate limit / quota error (HTTP 429). "
            "Check your OpenAI usage/billing and try again in a bit. "
            "You can also set OPENAI_MODEL in backend/.env to a cheaper/faster model. "
            "Meanwhile: review last week’s spending by category and pick one line to cut by ~10%."
        )
    if "404" in raw and ("not found" in low or "not_found" in low):
        return (
            "The configured OPENAI_MODEL was not found or is not available for your API key. "
            "Update OPENAI_MODEL in backend/.env to a model available for your account."
        )
    if "401" in raw or "403" in raw:
        return (
            "OpenAI rejected the request (auth). Confirm OPENAI_API_KEY in backend/.env is set and valid."
        )
    return (
        f"The AI request failed ({type(exc).__name__}). See the backend terminal for the full error. "
        "Verify OPENAI_API_KEY and OPENAI_MODEL, then try again."
    )


def _configured() -> bool:
    return bool(os.getenv("OPENAI_API_KEY", "").strip())


def _model_name() -> str:
    return os.getenv("OPENAI_MODEL", _DEFAULT_MODEL).strip() or _DEFAULT_MODEL


def _generate_text(prompt: str, max_output_tokens: int = 2048) -> str:
    key = os.getenv("OPENAI_API_KEY", "").strip()
    if not key:
        raise RuntimeError("OPENAI_API_KEY is not set")
    client = OpenAI(api_key=key)
    response = client.responses.create(
        model=_model_name(),
        input=prompt,
        max_output_tokens=max_output_tokens,
        temperature=0.35,
    )
    return (response.output_text or "").strip()


def _strip_code_fence(raw: str) -> str:
    s = raw.strip()
    if s.startswith("```"):
        s = re.sub(r"^```(?:json)?\s*", "", s, flags=re.IGNORECASE)
        s = re.sub(r"\s*```\s*$", "", s)
    return s.strip()


def _parse_json_object(raw: str) -> dict[str, Any]:
    s = _strip_code_fence(raw)
    try:
        return json.loads(s)
    except json.JSONDecodeError:
        m = re.search(r"\{[\s\S]*\}", s)
        if m:
            return json.loads(m.group(0))
        raise


def _parse_json_array(raw: str) -> list[Any]:
    s = _strip_code_fence(raw)
    try:
        out = json.loads(s)
        if isinstance(out, list):
            return out
    except json.JSONDecodeError:
        pass
    m = re.search(r"\[[\s\S]*\]", s)
    if m:
        out = json.loads(m.group(0))
        if isinstance(out, list):
            return out
    raise ValueError("Expected JSON array in model response")


def financial_assistant_reply(
    messages: list[dict[str, str]],
    financial_snapshot: dict[str, Any],
) -> str:
    """Multi-turn finance coach with bank-summary context."""
    hist_lines = [f"{m.get('role', 'user').upper()}: {m.get('content', '')}" for m in messages[-24:]]
    hist = "\n".join(hist_lines)
    snap = json.dumps(financial_snapshot, default=str)[:14000]
    prompt = f"""You are a supportive personal finance coach. The user has linked spending data; treat the JSON snapshot as ground truth and do not invent transactions.

Financial snapshot (JSON):
{snap}

Recent chat (oldest to newest):
{hist}

Write the assistant's next reply. Be concise (under ~220 words), practical, and kind. Reference specific numbers from the snapshot when helpful."""

    if not _configured():
        return (
            "I'm your financial assistant. When the server has OPENAI_API_KEY set, I'll give tailored guidance from your real spending snapshot. "
            "Until then: pick one category to trim this week, pause non-essential buys for 48 hours, and automate a small transfer to savings on payday."
        )

    try:
        return _generate_text(prompt, max_output_tokens=1200)
    except Exception as e:
        logger.warning("financial_assistant_reply OpenAI error: %s", e)
        return _user_visible_openai_error(e)


def compute_impulse_regret_score(
    price: float,
    monthly_income: float,
    available_balance: float,
    savings_rate: float,
    shopping_last_7_days: float,
) -> int:
    """
    0–100 regret / strain score from numbers only (matches UI expectations when price or balance moves).
    Higher when the buy is large vs income, eats liquid savings, savings rate is weak, or shopping was already heavy.
    """
    score = 0.0
    income = max(float(monthly_income or 0), 1.0)
    pct_income = (float(price) / income) * 100.0
    score += min(44.0, pct_income * 1.75)

    avail = float(available_balance or 0.0)
    if avail <= 0.0:
        score += 26.0
    else:
        burn = float(price) / max(avail, 1.0)
        if burn >= 1.0:
            score += 34.0
        elif burn >= 0.5:
            score += 24.0
        elif burn >= 0.25:
            score += 14.0
        elif burn >= 0.1:
            score += 6.0

    sr = float(savings_rate or 0.0)
    if sr < 3.0:
        score += 14.0
    elif sr < 8.0:
        score += 9.0
    elif sr < 15.0:
        score += 5.0

    weekly_income = income / 4.33
    if weekly_income > 0.0:
        shop_press = float(shopping_last_7_days or 0.0) / weekly_income
        score += min(16.0, shop_press * 11.0)

    return int(max(0, min(100, round(score))))


def _apply_regret_from_context(
    analysis: dict[str, Any],
    price: float,
    user_spending: dict[str, Any],
) -> dict[str, Any]:
    out = dict(analysis)
    out["regret_score"] = compute_impulse_regret_score(
        price=price,
        monthly_income=float(user_spending.get("income", 3000) or 3000),
        available_balance=float(user_spending.get("available_balance", 0) or 0),
        savings_rate=float(user_spending.get("savings_rate", 0) or 0),
        shopping_last_7_days=float(user_spending.get("shopping_last_7_days", 0) or 0),
    )
    return out


def _finalize_impulse_analysis(
    analysis: dict[str, Any],
    price: float,
    user_spending: dict[str, Any],
) -> dict[str, Any]:
    """Apply regret score; if purchase is under 20% of monthly income, verdict is buy_now (wait optional)."""
    out = _apply_regret_from_context(analysis, price, user_spending)
    income = max(float(user_spending.get("income", 3000) or 3000), 1.0)
    pct = (float(price) / income) * 100.0
    if pct < 20.0:
        out["verdict"] = "buy_now"
        prefix = (
            "Under 20% of your monthly income — no mandatory wait unless you want a pause."
        )
        insight = str(out.get("emotional_insight") or "").strip()
        if not insight.startswith("Under 20%"):
            out["emotional_insight"] = f"{prefix} {insight}".strip()
    return out


def analyze_impulse_purchase(item: str, price: float, user_spending: dict) -> dict[str, Any]:
    """Predict regret likelihood and spending context (JSON for API clients)."""
    cat7 = user_spending.get("last_7_days_by_category") or {}
    cat7_preview = json.dumps(cat7, ensure_ascii=False)[:800]
    narrative = (user_spending.get("pattern_narrative") or "").strip()

    prompt = f"""You are a behavioral finance AI assistant helping users avoid impulse purchases.

A user is considering buying: {item} for ${price:.2f}

Their recent spending context (approx. last 30 days in the rolling window we use):
- Monthly grocery spend: ${user_spending.get('groceries', 0):.2f}
- Monthly dining out: ${user_spending.get('dining', 0):.2f}
- Monthly income estimate: ${user_spending.get('income', 3000):.2f}
- Estimated available balance (linked accounts): ${user_spending.get('available_balance', 0):.2f}
- Current savings rate: {user_spending.get('savings_rate', 10)}%
- Spending by category in the last 7 days (JSON): {cat7_preview}
- Shopping spend last 7 days: ${user_spending.get('shopping_last_7_days', 0):.2f}
- Highlights: {narrative or "n/a"}

Use the 7-day category totals to personalize advice (e.g., if shopping is already high, say so).
If the purchase is under 20% of monthly income, verdict should usually be buy_now (waiting is optional, not required).
Respond ONLY with a JSON object (no markdown) with these keys:
{{
  "regret_score": <0-100 integer, likelihood of regret>,
  "verdict": "<buy_now | wait | skip>",
  "comparison": "<creative real-world comparison, e.g. '3 weeks of groceries'>",
  "weekly_equivalent": "<what this costs per week if bought monthly>",
  "percentage_of_monthly": "<% of monthly income>",
  "emotional_insight": "<1 sentence behavioral finance insight>",
  "alternative": "<one specific alternative suggestion>"
}}"""

    if not _configured():
        income = float(user_spending.get("income", 3000) or 3000)
        pct = (price / income * 100) if income else 0.0
        shop = float(user_spending.get("shopping_last_7_days", 0) or 0)
        extra = f" You've spent about ${shop:.0f} on shopping in the last 7 days." if shop else ""
        base = {
            "verdict": "wait",
            "comparison": f"About {pct:.1f}% of your estimated monthly income",
            "weekly_equivalent": f"${(price / 4.33):.2f} per week if spread like a monthly bill",
            "percentage_of_monthly": f"{pct:.1f}",
            "emotional_insight": f"Pause 48–72 hours; many impulse buys lose their appeal.{extra}",
            "alternative": "Add to a wish list and revisit after a full weekend.",
        }
        return _finalize_impulse_analysis(base, price, user_spending)

    raw = _generate_text(prompt, max_output_tokens=600)
    parsed = _parse_json_object(raw)
    return _finalize_impulse_analysis(parsed, price, user_spending)


def analyze_subscriptions(subscriptions: list) -> dict[str, Any]:
    """Subscription waste / duplicates / cancel candidates (JSON)."""
    sub_list = "\n".join(
        f"- {s['merchant']}: ${s['amount']:.2f}/month (category: {s['category']})"
        for s in subscriptions
    )

    prompt = f"""You are a subscription optimization AI. Analyze these subscriptions for waste:

{sub_list}

Respond ONLY with a JSON object (no markdown):
{{
  "total_monthly": <sum of all>,
  "wasted_monthly": <estimated wasted amount>,
  "duplicates": [<list of merchant names that overlap in purpose>],
  "cancel_candidates": [
    {{"merchant": "<name>", "reason": "<why cancel>", "savings": <monthly amount>}}
  ],
  "cheaper_alternatives": [
    {{"from": "<merchant>", "to": "<alternative>", "savings": <monthly savings>}}
  ],
  "insight": "<one punchy overall insight about their subscription habits>"
}}"""

    if not _configured():
        total = sum(float(s.get("amount", 0)) for s in subscriptions)
        return {
            "total_monthly": round(total, 2),
            "wasted_monthly": 0.0,
            "duplicates": [],
            "cancel_candidates": [],
            "cheaper_alternatives": [],
            "insight": "Set OPENAI_API_KEY for AI analysis; showing totals only.",
        }

    raw = _generate_text(prompt, max_output_tokens=900)
    return _parse_json_object(raw)


def generate_recommendations(
    spending_summary: dict, subscription_analysis: dict
) -> list[dict[str, Any]]:
    """Top 3 actionable recommendations as JSON array."""
    prompt = f"""You are a personal finance AI. Based on this user's data, give top recommendations.

Spending summary: {json.dumps(spending_summary)}
Subscription analysis: {json.dumps(subscription_analysis)}

Respond ONLY with a JSON array of exactly 3 recommendation objects (no markdown):
[
  {{
    "title": "<short action title>",
    "description": "<2 sentence explanation>",
    "monthly_impact": <dollar amount saved or redirected>,
    "difficulty": "<easy | medium | hard>",
    "category": "<subscriptions | impulse | budgeting | savings>"
  }}
]"""

    if not _configured():
        return [
            {
                "title": "Review recurring charges",
                "description": "List subscriptions and cancel what you have not used in 30 days.",
                "monthly_impact": 25.0,
                "difficulty": "easy",
                "category": "subscriptions",
            },
            {
                "title": "Use a 48-hour rule",
                "description": "Wait two days before non-essential purchases over $50.",
                "monthly_impact": 40.0,
                "difficulty": "easy",
                "category": "impulse",
            },
            {
                "title": "Automate savings",
                "description": "Move a fixed amount to savings on payday before discretionary spending.",
                "monthly_impact": 100.0,
                "difficulty": "medium",
                "category": "savings",
            },
        ]

    raw = _generate_text(prompt, max_output_tokens=800)
    arr = _parse_json_array(raw)
    return arr[:3] if len(arr) >= 3 else arr
