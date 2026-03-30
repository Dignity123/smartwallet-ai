from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.auth.deps import get_current_user
from app.database import schemas
from app.database.db import get_db
from app.services.ai_service import financial_assistant_reply
from app.services.plaid_service import get_transactions
from app.services.spending_analyzer import summarize_spending

router = APIRouter()


class ConversationCreate(BaseModel):
    title: str | None = Field(default=None, max_length=200)


class MessageCreate(BaseModel):
    content: str = Field(..., min_length=1, max_length=8000)


@router.post("/conversations")
def create_conversation(
    body: ConversationCreate,
    user: schemas.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    title = (body.title or "Financial assistant").strip() or "Financial assistant"
    row = schemas.ChatConversation(user_id=user.id, title=title[:200])
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id, "title": row.title, "created_at": row.created_at.isoformat() if row.created_at else None}


@router.get("/conversations")
def list_conversations(
    user: schemas.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(schemas.ChatConversation)
        .filter(schemas.ChatConversation.user_id == user.id)
        .order_by(schemas.ChatConversation.updated_at.desc(), schemas.ChatConversation.id.desc())
        .limit(50)
        .all()
    )
    return {
        "conversations": [
            {
                "id": r.id,
                "title": r.title,
                "created_at": r.created_at.isoformat() if r.created_at else None,
                "updated_at": r.updated_at.isoformat() if r.updated_at else None,
            }
            for r in rows
        ]
    }


@router.get("/conversations/{conversation_id}/messages")
def list_messages(
    conversation_id: int,
    user: schemas.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    conv = (
        db.query(schemas.ChatConversation)
        .filter(
            schemas.ChatConversation.id == conversation_id,
            schemas.ChatConversation.user_id == user.id,
        )
        .first()
    )
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
    msgs = (
        db.query(schemas.ChatMessage)
        .filter(schemas.ChatMessage.conversation_id == conversation_id)
        .order_by(schemas.ChatMessage.created_at.asc(), schemas.ChatMessage.id.asc())
        .limit(200)
        .all()
    )
    return {
        "messages": [
            {
                "id": m.id,
                "role": m.role,
                "content": m.content,
                "created_at": m.created_at.isoformat() if m.created_at else None,
            }
            for m in msgs
        ]
    }


@router.post("/conversations/{conversation_id}/messages")
def send_message(
    conversation_id: int,
    body: MessageCreate,
    user: schemas.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    conv = (
        db.query(schemas.ChatConversation)
        .filter(
            schemas.ChatConversation.id == conversation_id,
            schemas.ChatConversation.user_id == user.id,
        )
        .first()
    )
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")

    user_msg = schemas.ChatMessage(
        conversation_id=conversation_id,
        role="user",
        content=body.content.strip(),
    )
    db.add(user_msg)
    db.flush()
    db.refresh(user_msg)
    db.commit()

    prior = (
        db.query(schemas.ChatMessage)
        .filter(schemas.ChatMessage.conversation_id == conversation_id)
        .order_by(schemas.ChatMessage.created_at.desc(), schemas.ChatMessage.id.desc())
        .limit(25)
        .all()
    )
    prior_chrono = list(reversed(prior))
    history = [{"role": m.role, "content": m.content} for m in prior_chrono]

    income = float(user.monthly_income) if user.monthly_income else 3000.0
    txns = get_transactions(user.id, days=45, db=db)
    summary = summarize_spending(txns, monthly_income=income)
    snapshot = {
        "user_name": user.name,
        "monthly_income_estimate": income,
        "spending_summary": summary,
    }

    try:
        reply_text = financial_assistant_reply(history, snapshot).strip()
    except Exception:
        reply_text = ""
    if not reply_text:
        reply_text = (
            "I couldn’t generate a full answer just now. "
            "Confirm GEMINI_API_KEY on the server, check Gemini quota at https://ai.dev/rate-limit , "
            "or try again shortly. "
            "Meanwhile: skim last week’s spending by category and pick one line item to cut by 10%."
        )
    asst = schemas.ChatMessage(
        conversation_id=conversation_id,
        role="assistant",
        content=reply_text,
    )
    db.add(asst)
    conv.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(asst)
    return {
        "user_message_id": user_msg.id,
        "assistant": {
            "id": asst.id,
            "role": asst.role,
            "content": asst.content,
            "created_at": asst.created_at.isoformat() if asst.created_at else None,
        },
    }
