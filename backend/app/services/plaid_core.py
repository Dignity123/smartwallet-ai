"""Plaid API client factory (sandbox / development / production)."""

import os

from dotenv import load_dotenv

load_dotenv()

try:
    import plaid
    from plaid.api import plaid_api
    from plaid.api_client import ApiClient
    from plaid.configuration import Configuration

    _PLAID_AVAILABLE = True
except ImportError:
    _PLAID_AVAILABLE = False


def plaid_configured() -> bool:
    return bool(
        os.getenv("PLAID_CLIENT_ID", "").strip()
        and os.getenv("PLAID_SECRET", "").strip()
        and _PLAID_AVAILABLE
    )


def _plaid_host() -> str:
    env = os.getenv("PLAID_ENV", "sandbox").lower().strip()
    if not _PLAID_AVAILABLE:
        return ""
    if env == "production":
        return plaid.Environment.Production
    if env in ("development", "dev"):
        return plaid.Environment.Development
    return plaid.Environment.Sandbox


def get_plaid_client():
    if not plaid_configured():
        raise RuntimeError("Plaid SDK missing or PLAID_CLIENT_ID / PLAID_SECRET not set")
    configuration = Configuration(
        host=_plaid_host(),
        api_key={
            "clientId": os.getenv("PLAID_CLIENT_ID"),
            "secret": os.getenv("PLAID_SECRET"),
        },
    )
    api_client = ApiClient(configuration)
    return plaid_api.PlaidApi(api_client)
