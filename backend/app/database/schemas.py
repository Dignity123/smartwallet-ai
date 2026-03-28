from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.database.db import Base
from datetime import datetime

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    name = Column(String)
    monthly_income = Column(Float, default=0.0)
    created_at = Column(DateTime, default=datetime.utcnow)
    transactions = relationship("Transaction", back_populates="owner")
    subscriptions = relationship("Subscription", back_populates="owner")

class Transaction(Base):
    __tablename__ = "transactions"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    amount = Column(Float)
    merchant = Column(String)
    category = Column(String)
    date = Column(DateTime)
    is_recurring = Column(Boolean, default=False)
    plaid_id = Column(String, unique=True, nullable=True)
    owner = relationship("User", back_populates="transactions")

class Subscription(Base):
    __tablename__ = "subscriptions"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    merchant = Column(String)
    amount = Column(Float)
    frequency = Column(String)  # monthly, yearly
    last_charged = Column(DateTime)
    is_active = Column(Boolean, default=True)
    category = Column(String)   # streaming, software, fitness, etc.
    owner = relationship("User", back_populates="subscriptions")