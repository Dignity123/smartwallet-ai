from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth.deps import get_current_user, require_uid_matches
from app.database import schemas
from app.database.db import get_db
from app.services.cash_flow_service import forecast_cash_flow

router = APIRouter()


@router.get("/{user_id}")
def cash_flow_forecast(
    user_id: int,
    db: Session = Depends(get_db),
    user: schemas.User = Depends(get_current_user),
):
    require_uid_matches(user, user_id)
    return forecast_cash_flow(user_id, db)
