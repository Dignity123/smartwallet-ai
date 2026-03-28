from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routes import transactions, subscriptions, impulse, recommendations
from app.database.db import engine
from app.database import schemas

schemas.Base.metadata.create_all(bind=engine)

app = FastAPI(title="SmartWallet AI", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(transactions.router, prefix="/api/transactions", tags=["transactions"])
app.include_router(subscriptions.router, prefix="/api/subscriptions", tags=["subscriptions"])
app.include_router(impulse.router, prefix="/api/impulse", tags=["impulse"])
app.include_router(recommendations.router, prefix="/api/recommendations", tags=["recommendations"])

@app.get("/")
def root():
    return {"message": "SmartWallet AI is running 🚀"}