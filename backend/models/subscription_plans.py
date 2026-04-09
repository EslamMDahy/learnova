from sqlalchemy import (
    String,
    DateTime,
    Boolean,
    Integer,
    Text,
    Numeric,
    Enum as SQLEnum
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import SubscriptionTier


class SubscriptionPlan(Base):
    __tablename__ = "subscription_plans"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    name: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        nullable=False
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    tier: Mapped[SubscriptionTier] = mapped_column(
        SQLEnum(SubscriptionTier, name="subscription_tier_enum"),
        nullable=False,
        default=SubscriptionTier.free,
        index=True
    )

    max_teachers: Mapped[int] = mapped_column(
        Integer,
        default=1
    )

    max_students: Mapped[int] = mapped_column(
        Integer,
        default=10
    )

    max_courses: Mapped[int] = mapped_column(
        Integer,
        default=3
    )

    max_storage_mb: Mapped[int] = mapped_column(
        Integer,
        default=100
    )

    allow_ai_chat: Mapped[bool] = mapped_column(
        Boolean,
        default=True
    )

    allow_ai_question_gen: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    allow_video_analysis: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    allow_advanced_analytics: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    allow_custom_branding: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    allow_bulk_invites: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    allow_api_access: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    monthly_credits: Mapped[int] = mapped_column(
        Integer,
        default=100
    )

    price_per_month: Mapped[float] = mapped_column(
        Numeric(10, 2),
        default=0.00
    )

    price_per_year: Mapped[float | None] = mapped_column(
        Numeric(10, 2),
        nullable=True
    )

    currency: Mapped[str] = mapped_column(
        String(10),
        default="USD"
    )

    is_popular: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    sort_order: Mapped[int] = mapped_column(
        Integer,
        default=0,
        index=True
    )

    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        index=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )
