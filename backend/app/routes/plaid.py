import os

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.auth.deps import get_current_user, require_uid_matches
from app.database import schemas
from app.database.db import get_db
from app.services.plaid_core import get_plaid_client, plaid_configured
from app.services.plaid_sync import handle_webhook_payload, sync_item_transactions

router = APIRouter()


class LinkTokenRequest(BaseModel):
    # Optional extras needed for some mobile/OAuth Link flows.
    redirect_uri: str | None = Field(default=None, max_length=1024)
    android_package_name: str | None = Field(default=None, max_length=255)
    webhook: str | None = Field(default=None, max_length=1024)


class ExchangeRequest(BaseModel):
    public_token: str


@router.post("/link-token")
def create_link_token(
    body: LinkTokenRequest,
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    if not plaid_configured():
        raise HTTPException(
            status_code=503,
            detail="Plaid not configured. Set PLAID_CLIENT_ID, PLAID_SECRET, and install plaid-python.",
        )
    from plaid.model.country_code import CountryCode
    from plaid.model.link_token_create_request import LinkTokenCreateRequest
    from plaid.model.link_token_create_request_user import LinkTokenCreateRequestUser
    from plaid.model.products import Products

    client = get_plaid_client()
    req = LinkTokenCreateRequest(
        user=LinkTokenCreateRequestUser(client_user_id=str(user.id)),
        client_name="SmartWallet AI",
        products=[Products("transactions")],
        country_codes=[CountryCode("US")],
        language="en",
    )
    # Some Plaid Link flows require redirect_uri and/or android package name.
    if body.redirect_uri:
        if hasattr(req, "redirect_uri"):
            req.redirect_uri = body.redirect_uri
    if body.android_package_name:
        # Only set when the installed plaid-python version supports it.
        if hasattr(req, "android_package_name"):
            req.android_package_name = body.android_package_name
    webhook = body.webhook or os.getenv("PLAID_WEBHOOK_URL", "").strip() or None
    if webhook and hasattr(req, "webhook"):
        req.webhook = webhook
    resp = client.link_token_create(req)
    data = resp.to_dict() if hasattr(resp, "to_dict") else dict(resp)
    return {"link_token": data.get("link_token")}


@router.post("/exchange")
def exchange_public_token(
    body: ExchangeRequest,
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    if not plaid_configured():
        raise HTTPException(status_code=503, detail="Plaid not configured")
    from plaid.model.item_public_token_exchange_request import ItemPublicTokenExchangeRequest

    client = get_plaid_client()
    ex = ItemPublicTokenExchangeRequest(public_token=body.public_token)
    resp = client.item_public_token_exchange(ex)
    data = resp.to_dict() if hasattr(resp, "to_dict") else dict(resp)
    access = data.get("access_token")
    item_id = data.get("item_id")
    if not access or not item_id:
        raise HTTPException(status_code=400, detail="Invalid Plaid response")

    existing = db.query(schemas.PlaidItem).filter(schemas.PlaidItem.item_id == item_id).first()
    if existing:
        existing.access_token = access
        existing.user_id = user.id
        db.commit()
        db.refresh(existing)
        item = existing
    else:
        item = schemas.PlaidItem(
            user_id=user.id,
            item_id=item_id,
            access_token=access,
        )
        db.add(item)
        db.commit()
        db.refresh(item)

    db.refresh(item)
    try:
        sync_item_transactions(db, item)
    except Exception as e:
        return {"item_id": item_id, "sync_warning": str(e)}

    return {"item_id": item_id, "status": "linked_and_synced"}


@router.post("/sync/{user_id}")
def manual_sync(
    user_id: int,
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    require_uid_matches(user, user_id)
    items = db.query(schemas.PlaidItem).filter(schemas.PlaidItem.user_id == user_id).all()
    if not items:
        raise HTTPException(status_code=404, detail="No linked Plaid items")
    results = []
    for item in items:
        try:
            results.append({"item_id": item.item_id, **sync_item_transactions(db, item)})
        except Exception as e:
            results.append({"item_id": item.item_id, "error": str(e)})
    from app.services.alert_engine import evaluate_alerts

    evaluate_alerts(db, user_id)
    return {"results": results}


@router.post("/webhook")
async def plaid_webhook(request: Request):
    payload = await request.json()
    return handle_webhook_payload(payload)


@router.get("/status/{user_id}")
def plaid_status(
    user_id: int,
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    require_uid_matches(user, user_id)
    n = db.query(schemas.PlaidItem).filter(schemas.PlaidItem.user_id == user_id).count()
    return {"linked": n > 0, "items": n, "plaid_configured": plaid_configured()}
