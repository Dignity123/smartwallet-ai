from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import schemas
from app.database.db import SessionLocal, engine
from app.auth.passwords import hash_password
from app.routes import (
    alerts,
    auth,
    budgets,
    cashflow,
    chat,
    impulse,
    plaid,
    recommendations,
    subscriptions,
    transactions,
)

schemas.Base.metadata.create_all(bind=engine)


@asynccontextmanager
async def lifespan(_: FastAPI):
    db = SessionLocal()
    try:
        demo = db.query(schemas.User).filter(schemas.User.id == 1).first()
        if demo is None:
            db.add(
                schemas.User(
                    id=1,
                    email="demo@smartwallet.ai",
                    name="Demo User",
                    monthly_income=3000.0,
                    hashed_password=hash_password("demo"),
                )
            )
            db.commit()
        elif not demo.hashed_password:
            demo.hashed_password = hash_password("demo")
            db.commit()
    finally:
        db.close()
    yield


app = FastAPI(title="SmartWallet AI", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(chat.router, prefix="/api/chat", tags=["chat"])
app.include_router(transactions.router, prefix="/api/transactions", tags=["transactions"])
app.include_router(subscriptions.router, prefix="/api/subscriptions", tags=["subscriptions"])
app.include_router(impulse.router, prefix="/api/impulse", tags=["impulse"])
app.include_router(recommendations.router, prefix="/api/recommendations", tags=["recommendations"])
app.include_router(plaid.router, prefix="/api/plaid", tags=["plaid"])
app.include_router(budgets.router, prefix="/api/budgets", tags=["budgets"])
app.include_router(alerts.router, prefix="/api/alerts", tags=["alerts"])
app.include_router(cashflow.router, prefix="/api/cashflow", tags=["cashflow"])


@app.get("/")
def root():
    return {"message": "SmartWallet AI is running 🚀"}
