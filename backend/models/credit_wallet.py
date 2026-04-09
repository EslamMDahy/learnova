from sqlalchemy import (
    String,
    DateTime,
    Integer,
    ForeignKey,
    Enum as SQLEnum,
    CheckConstraint
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import CreditWalletType


class CreditWallet(Base):
    __tablename__ = "credit_wallets"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    wallet_type: Mapped[CreditWalletType] = mapped_column(
        SQLEnum(CreditWalletType, name="credit_wallet_type_enum"),
        nullable=False,
        index=True
    )

    # for individual wallet
    user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=True,
        index=True
    )

    # for organization wallet
    organization_id: Mapped[int | None] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=True,
        index=True
    )

    balance_credits: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0
    )

    monthly_allowance: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0
    )

    total_earned: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    total_spent: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    allowance_reset_day: Mapped[int] = mapped_column(
        Integer,
        default=1
    )

    last_reset_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    next_reset_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
        onupdate=datetime.utcnow
    )

    __table_args__ = (
        # ensure wallet is linked correctly
        CheckConstraint(
            """
            (
                wallet_type = 'individual'
                AND user_id IS NOT NULL
                AND organization_id IS NULL
            )
            OR
            (
                wallet_type = 'organization'
                AND organization_id IS NOT NULL
                AND user_id IS NULL
            )
            """,
            name="ck_credit_wallet_owner"
        ),
    )
