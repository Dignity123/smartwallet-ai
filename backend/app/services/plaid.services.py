import os
from datetime import datetime, timedelta
import random
from dotenv import load_dotenv

load_dotenv()

PLAID_CLIENT_ID = os.getenv("PLAID_CLIENT_ID", "")
PLAID_SECRET = os.getenv("PLAID_SECRET", "")
USE_MOCK = os.getenv("USE_MOCK_DATA", "true").lower() == "true"

MOCK_TRANSACTIONS = [
    {"id": "t1", "merchant": "Starbucks", "amount": 6.50, "category": "Food & Drink", "date": (datetime.now() - timedelta(days=1)).isoformat()},
    {"id": "t2", "merchant": "Netflix", "amount": 15.99, "category": "Entertainment", "date": (datetime.now() - timedelta(days=3)).isoformat()},
    {"id": "t3", "merchant": "Spotify", "amount": 9.99, "category": "Entertainment", "date": (datetime.now() - timedelta(days=3)).isoformat()},
    {"id": "t4", "merchant": "Amazon Prime", "amount": 14.99, "category": "Shopping", "date": (datetime.now() - timedelta(days=5)).isoformat()},
    {"id": "t5", "merchant": "Hulu", "amount": 12.99, "category": "Entertainment", "date": (datetime.now() - timedelta(days=5)).isoformat()},
    {"id": "t6", "merchant": "Whole Foods", "amount": 87.34, "category": "Groceries", "date": (datetime.now() - timedelta(days=6)).isoformat()},
    {"id": "t7", "merchant": "Nike.com", "amount": 129.00, "category": "Shopping", "date": (datetime.now() - timedelta(days=7)).isoformat()},
    {"id": "t8", "merchant": "Gym Membership", "amount": 40.00, "category": "Fitness", "date": (datetime.now() - timedelta(days=10)).isoformat()},
    {"id": "t9", "merchant": "Adobe Creative Cloud", "amount": 54.99, "category": "Software", "date": (datetime.now() - timedelta(days=12)).isoformat()},
    {"id": "t10", "merchant": "Starbucks", "amount": 7.25, "category": "Food & Drink", "date": (datetime.now() - timedelta(days=2)).isoformat()},
    {"id": "t11", "merchant": "Starbucks", "amount": 6.75, "category": "Food & Drink", "date": (datetime.now() - timedelta(days=4)).isoformat()},
    {"id": "t12", "merchant": "DoorDash", "amount": 42.10, "category": "Food & Drink", "date": (datetime.now() - timedelta(days=2)).isoformat()},
    {"id": "t13", "merchant": "Peacock", "amount": 5.99, "category": "Entertainment", "date": (datetime.now() - timedelta(days=15)).isoformat()},
    {"id": "t14", "merchant": "LinkedIn Premium", "amount": 39.99, "category": "Software", "date": (datetime.now() - timedelta(days=20)).isoformat()},
    {"id": "t15", "merchant": "Shell Gas", "amount": 68.00, "category": "Transportation", "date": (datetime.now() - timedelta(days=8)).isoformat()},
]

RECURRING_MERCHANTS = {"Netflix", "Spotify", "Amazon Prime", "Hulu", "Gym Membership", 
                        "Adobe Creative Cloud", "Peacock", "LinkedIn Premium"}

def get_transactions(user_id: int, days: int = 30):
    if USE_MOCK:
        return [
            {**t, "user_id": user_id, "is_recurring": t["merchant"] in RECURRING_MERCHANTS}
            for t in MOCK_TRANSACTIONS
        ]
    # Real Plaid integration would go here
    raise NotImplementedError("Live Plaid not configured")

def get_account_balance(user_id: int):
    if USE_MOCK:
        return {"available": 2340.50, "current": 2890.00, "currency": "USD"}
    raise NotImplementedError("Live Plaid not configured")