from sqlalchemy import (
    String,
    DateTime,
    Integer,
    ForeignKey,
    Text,
    JSON,
    Enum as SQLEnum,
    Index,
    CheckConstraint
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import CreditTransactionType


class CreditTransaction(Base):
    __tablename__ = "credit_transactions"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    credit_wallet_id: Mapped[int] = mapped_column(
        ForeignKey("credit_wallets.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    type: Mapped[CreditTransactionType] = mapped_column(
        SQLEnum(CreditTransactionType, name="credit_transaction_type_enum"),
        nullable=False,
        index=True
    )

    amount: Mapped[int] = mapped_column(
        Integer,
        nullable=False
    )

    balance_before: Mapped[int] = mapped_column(
        Integer,
        nullable=False
    )

    balance_after: Mapped[int] = mapped_column(
        Integer,
        nullable=False
    )

    reason: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        index=True
    )

    source: Mapped[str] = mapped_column(
        String(100),
        nullable=False
    )

    reference_type: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True
    )

    reference_id: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    extra_metadata: Mapped[dict | None] = mapped_column("metadata", JSON, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
        index=True
    )

    __table_args__ = (
        # composite index: (reference_type, reference_id)
        Index(
            "ix_credit_tx_reference_type_id",
            "reference_type",
            "reference_id"
        ),
        # sanity checks
        CheckConstraint("amount <> 0", name="ck_credit_tx_amount_nonzero"),
        CheckConstraint("balance_before >= 0", name="ck_credit_tx_balance_before_nonneg"),
        CheckConstraint("balance_after >= 0", name="ck_credit_tx_balance_after_nonneg"),
    )
