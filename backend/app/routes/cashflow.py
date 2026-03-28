from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database.db import get_db
from app.services.cash_flow_service import forecast_cash_flow

router = APIRouter()


@router.get("/{user_id}")
def cash_flow_forecast(user_id: int, db: Session = Depends(get_db)):
    return forecast_cash_flow(user_id, db)
