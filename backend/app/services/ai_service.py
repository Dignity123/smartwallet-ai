import json
import os
import re
from typing import Any

from dotenv import load_dotenv
from google import genai
from google.genai import types

load_dotenv()

_DEFAULT_MODEL = "gemini-2.0-flash"


def _configured() -> bool:
    return bool(os.getenv("GEMINI_API_KEY", "").strip())


def _model_name() -> str:
    return os.getenv("GEMINI_MODEL", _DEFAULT_MODEL).strip() or _DEFAULT_MODEL


def _generate_text(prompt: str, max_output_tokens: int = 2048) -> str:
    key = os.getenv("GEMINI_API_KEY", "").strip()
    if not key:
        raise RuntimeError("GEMINI_API_KEY is not set")
    client = genai.Client(api_key=key)
    response = client.models.generate_content(
        model=_model_name(),
        contents=prompt,
        config=types.GenerateContentConfig(
            max_output_tokens=max_output_tokens,
            temperature=0.35,
        ),
    )
    text = (response.text or "").strip()
    if not text and response.candidates:
        parts = response.candidates[0].content.parts
        text = "".join(getattr(p, "text", "") for p in parts).strip()
    return text


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
            "I'm your financial assistant. When the server has GEMINI_API_KEY set, I'll give tailored guidance from your real spending snapshot. "
            "Until then: pick one category to trim this week, pause non-essential buys for 48 hours, and automate a small transfer to savings on payday."
        )

    return _generate_text(prompt, max_output_tokens=1200)


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
- Current savings rate: {user_spending.get('savings_rate', 10)}%
- Spending by category in the last 7 days (JSON): {cat7_preview}
- Shopping spend last 7 days: ${user_spending.get('shopping_last_7_days', 0):.2f}
- Highlights: {narrative or "n/a"}

Use the 7-day category totals to personalize advice (e.g., if shopping is already high, say so). Respond ONLY with a JSON object (no markdown) with these keys:
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
        return {
            "regret_score": 65,
            "verdict": "wait",
            "comparison": f"About {pct:.1f}% of your estimated monthly income",
            "weekly_equivalent": f"${(price / 4.33):.2f} per week if spread like a monthly bill",
            "percentage_of_monthly": f"{pct:.1f}",
            "emotional_insight": f"Pause 48–72 hours; many impulse buys lose their appeal.{extra}",
            "alternative": "Add to a wish list and revisit after a full weekend.",
        }

    raw = _generate_text(prompt, max_output_tokens=600)
    return _parse_json_object(raw)


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
            "insight": "Set GEMINI_API_KEY for AI analysis; showing totals only.",
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
