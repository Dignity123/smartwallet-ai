from fastapi import APIRouter, HTTPException
from app.services.plaid_service import get_transactions, get_account_balance
from app.services.spending_analyzer import summarize_spending

router = APIRouter()

@router.get("/{user_id}")
def get_user_transactions(user_id: int, days: int = 30):
    """Fetch and return transactions with spending summary."""
    try:
        transactions = get_transactions(user_id, days)
        summary = summarize_spending(transactions)
        balance = get_account_balance(user_id)
        return {
            "transactions": transactions,
            "summary": summary,
            "balance": balance,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))