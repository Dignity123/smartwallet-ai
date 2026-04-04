from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from app.database.db import Base


class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    name = Column(String)
    monthly_income = Column(Float, default=0.0)
    hashed_password = Column(String, nullable=True)
    google_sub = Column(String, unique=True, nullable=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    transactions = relationship("Transaction", back_populates="owner")
    subscriptions = relationship("Subscription", back_populates="owner")
    plaid_items = relationship("PlaidItem", back_populates="owner")
    budget_goals = relationship("BudgetGoal", back_populates="owner")
    alerts = relationship("Alert", back_populates="owner")
    chat_conversations = relationship("ChatConversation", back_populates="owner")
    savings_targets = relationship("SavingsTarget", back_populates="owner")


class Transaction(Base):
    __tablename__ = "transactions"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    amount = Column(Float)
    merchant = Column(String)
    category = Column(String)
    date = Column(DateTime)
    is_recurring = Column(Boolean, default=False)
    plaid_id = Column(String, unique=True, nullable=True, index=True)
    account_id = Column(String, nullable=True)
    owner = relationship("User", back_populates="transactions")


class Subscription(Base):
    __tablename__ = "subscriptions"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    merchant = Column(String)
    amount = Column(Float)
    frequency = Column(String)
    last_charged = Column(DateTime)
    is_active = Column(Boolean, default=True)
    category = Column(String)
    owner = relationship("User", back_populates="subscriptions")


class PlaidItem(Base):
    """Linked Plaid Item (institution) per user."""

    __tablename__ = "plaid_items"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    item_id = Column(String, unique=True, index=True)
    access_token = Column(String, nullable=False)
    transactions_cursor = Column(String, nullable=True)
    institution_id = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    owner = relationship("User", back_populates="plaid_items")


class BudgetGoal(Base):
    __tablename__ = "budget_goals"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    category = Column(String, nullable=False, index=True)
    monthly_limit = Column(Float, nullable=False)
    alert_threshold_pct = Column(Float, default=0.8)
    created_at = Column(DateTime, default=datetime.utcnow)
    owner = relationship("User", back_populates="budget_goals")


class Alert(Base):
    __tablename__ = "alerts"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    alert_type = Column(String, nullable=False, index=True)
    title = Column(String, nullable=False)
    body = Column(Text, nullable=False)
    payload_json = Column(Text, nullable=True)
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    owner = relationship("User", back_populates="alerts")


class SubscriptionCancellation(Base):
    """User marked a subscription for cancellation — alert if it charges again."""

    __tablename__ = "subscription_cancellations"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    merchant_key = Column(String, nullable=False, index=True)
    amount_snapshot = Column(Float, nullable=True)
    marked_at = Column(DateTime, default=datetime.utcnow)
    active = Column(Boolean, default=True)


class ChatConversation(Base):
    __tablename__ = "chat_conversations"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    title = Column(String, default="Financial assistant")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    owner = relationship("User", back_populates="chat_conversations")
    messages = relationship("ChatMessage", back_populates="conversation")


class ChatMessage(Base):
    __tablename__ = "chat_messages"
    id = Column(Integer, primary_key=True, index=True)
    conversation_id = Column(Integer, ForeignKey("chat_conversations.id"), index=True)
    role = Column(String, nullable=False)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    conversation = relationship("ChatConversation", back_populates="messages")


class SavingsTarget(Base):
    """User-defined savings goal with progress (amount saved vs target)."""

    __tablename__ = "savings_targets"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    name = Column(String, nullable=False)
    target_amount = Column(Float, nullable=False)
    saved_amount = Column(Float, default=0.0)
    icon_code_point = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    owner = relationship("User", back_populates="savings_targets")
