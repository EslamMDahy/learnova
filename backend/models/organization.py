from sqlalchemy import (
    String,
    DateTime,
    Boolean,
    Integer,
    Text,
    ForeignKey,
    JSON,
    Enum as SQLEnum
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import SubscriptionStatus


class Organization(Base):
    __tablename__ = "organizations"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    logo_url: Mapped[str | None] = mapped_column(
        String(512),
        nullable=True
    )

    banner_url: Mapped[str | None] = mapped_column(
        String(512),
        nullable=True
    )

    website_url: Mapped[str | None] = mapped_column(
        String(512),
        nullable=True
    )

    contact_email: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True
    )

    owner_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True
    )

    subscription_plan_id: Mapped[int] = mapped_column(
        ForeignKey("subscription_plans.id", ondelete="RESTRICT"),
        nullable=False
    )

    invite_code: Mapped[str] = mapped_column(
        String(64),
        unique=True,
        nullable=False,
        index=True
    )

    subscription_status: Mapped[SubscriptionStatus] = mapped_column(
        SQLEnum(SubscriptionStatus, name="subscription_status_enum"),
        default=SubscriptionStatus.active,
        index=True
    )

    subscription_started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    subscription_renews_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    trial_ends_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    cancel_at_period_end: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    settings: Mapped[dict] = mapped_column(
        JSON,
        default=dict
    )

    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        index=True
    )

    is_public: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    allow_self_registration: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    member_count: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    course_count: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
        onupdate=datetime.utcnow
    )
