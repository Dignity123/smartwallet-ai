import json

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import schemas
from app.database.db import get_db
from app.services.alert_engine import evaluate_alerts

router = APIRouter()


@router.get("/{user_id}")
def list_alerts(user_id: int, unread_only: bool = False, db: Session = Depends(get_db)):
    q = db.query(schemas.Alert).filter(schemas.Alert.user_id == user_id)
    if unread_only:
        q = q.filter(schemas.Alert.is_read.is_(False))
    rows = q.order_by(schemas.Alert.created_at.desc()).limit(100).all()
    return {
        "alerts": [
            {
                "id": r.id,
                "type": r.alert_type,
                "title": r.title,
                "body": r.body,
                "payload": json.loads(r.payload_json) if r.payload_json else None,
                "is_read": r.is_read,
                "created_at": r.created_at.isoformat() if r.created_at else None,
            }
            for r in rows
        ]
    }


@router.post("/{user_id}/evaluate")
def run_alert_engine(user_id: int, db: Session = Depends(get_db)):
    n = evaluate_alerts(db, user_id)
    return {"new_alerts": n}


@router.patch("/{user_id}/{alert_id}/read")
def mark_read(user_id: int, alert_id: int, db: Session = Depends(get_db)):
    row = (
        db.query(schemas.Alert)
        .filter(schemas.Alert.id == alert_id, schemas.Alert.user_id == user_id)
        .first()
    )
    if not row:
        raise HTTPException(status_code=404, detail="Not found")
    row.is_read = True
    db.commit()
    return {"status": "ok"}


@router.post("/{user_id}/read-all")
def mark_all_read(user_id: int, db: Session = Depends(get_db)):
    db.query(schemas.Alert).filter(schemas.Alert.user_id == user_id).update({"is_read": True})
    db.commit()
    return {"status": "ok"}
