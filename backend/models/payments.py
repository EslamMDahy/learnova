from sqlalchemy import (
    String,
    DateTime,
    Boolean,
    Integer,
    ForeignKey,
    Text,
    Numeric,
    Enum as SQLEnum,
    Index,
    CheckConstraint
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import PaymentStatus, BillingInterval


class Payment(Base):
    __tablename__ = "payments"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    # can pay as individual user or organization
    user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True
    )

    organization_id: Mapped[int | None] = mapped_column(
        ForeignKey("organizations.id", ondelete="SET NULL"),
        nullable=True
    )

    credit_wallet_id: Mapped[int | None] = mapped_column(
        ForeignKey("credit_wallets.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )

    provider: Mapped[str] = mapped_column(
        String(50),
        nullable=False
    )

    provider_ref: Mapped[str | None] = mapped_column(
        String(255),
        unique=True,
        nullable=True,
        index=True
    )

    amount_money: Mapped[float] = mapped_column(
        Numeric(10, 2),
        nullable=False
    )

    currency: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
        default="EGP"
    )

    credits_purchased: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0
    )

    unit_price: Mapped[float | None] = mapped_column(
        Numeric(10, 4),
        nullable=True
    )

    status: Mapped[PaymentStatus] = mapped_column(
        SQLEnum(PaymentStatus, name="payment_status_enum"),
        nullable=False,
        default=PaymentStatus.pending,
        index=True
    )

    status_changed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    payer_email: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True
    )

    payer_name: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True
    )

    notes: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    billing_interval: Mapped[BillingInterval] = mapped_column(
        SQLEnum(BillingInterval, name="billing_interval_enum"),
        default=BillingInterval.one_time
    )

    next_billing_date: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
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

    __table_args__ = (
        # indexes: (organization_id, created_at) and (user_id, created_at)
        Index("ix_payments_org_created_at", "organization_id", "created_at"),
        Index("ix_payments_user_created_at", "user_id", "created_at"),

        # ensure payer is either user or organization (not both, not neither)
        CheckConstraint(
            """
            (
                user_id IS NOT NULL AND organization_id IS NULL
            )
            OR
            (
                user_id IS NULL AND organization_id IS NOT NULL
            )
            """,
            name="ck_payments_payer_one"
        ),

        # sanity checks
        CheckConstraint("amount_money >= 0", name="ck_payments_amount_nonneg"),
        CheckConstraint("credits_purchased >= 0", name="ck_payments_credits_nonneg"),
    )
