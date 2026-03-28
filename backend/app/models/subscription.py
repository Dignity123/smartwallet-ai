from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.services.plaid_service import get_transactions
from app.services.subscription_detector import detect_subscriptions, find_duplicate_subscriptions
from app.services.ai_service import analyze_subscriptions

router = APIRouter()

class SubscriptionScanRequest(BaseModel):
    user_id: int

@router.post("/scan")
def scan_subscriptions(req: SubscriptionScanRequest):
    """Detect all subscriptions and get AI-powered optimization advice."""
    try:
        transactions = get_transactions(req.user_id)
        subscriptions = detect_subscriptions(transactions)
        duplicates = find_duplicate_subscriptions(subscriptions)
        ai_analysis = analyze_subscriptions(subscriptions)

        return {
            "subscriptions": subscriptions,
            "duplicates": duplicates,
            "ai_analysis": ai_analysis,
            "total_monthly_cost": sum(s["amount"] for s in subscriptions),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{user_id}")
def get_subscriptions(user_id: int):
    """Get detected subscriptions for a user."""
    transactions = get_transactions(user_id)
    subscriptions = detect_subscriptions(transactions)
    return {"subscriptions": subscriptions}