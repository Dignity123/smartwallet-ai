import os
import anthropic
import json
from dotenv import load_dotenv

load_dotenv()

client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

def analyze_impulse_purchase(item: str, price: float, user_spending: dict) -> dict:
    """Predict regret likelihood and provide spending context for a potential purchase."""
    prompt = f"""You are a behavioral finance AI assistant helping users avoid impulse purchases.

A user is considering buying: {item} for ${price:.2f}

Their recent spending context:
- Monthly grocery spend: ${user_spending.get('groceries', 0):.2f}
- Monthly dining out: ${user_spending.get('dining', 0):.2f}
- Monthly income estimate: ${user_spending.get('income', 3000):.2f}
- Current savings rate: {user_spending.get('savings_rate', 10)}%

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

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=500,
        messages=[{"role": "user", "content": prompt}]
    )
    
    raw = response.content[0].text.strip()
    return json.loads(raw)


def analyze_subscriptions(subscriptions: list) -> dict:
    """Detect waste, duplicates, and cancellation opportunities."""
    sub_list = "\n".join([
        f"- {s['merchant']}: ${s['amount']:.2f}/month (category: {s['category']})"
        for s in subscriptions
    ])

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

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=800,
        messages=[{"role": "user", "content": prompt}]
    )

    raw = response.content[0].text.strip()
    return json.loads(raw)


def generate_recommendations(spending_summary: dict, subscription_analysis: dict) -> list:
    """Generate top 3 actionable personalized financial recommendations."""
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

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=600,
        messages=[{"role": "user", "content": prompt}]
    )

    raw = response.content[0].text.strip()
    return json.loads(raw)