from sqlalchemy import (
    DateTime,
    Integer,
    Text,
    ForeignKey,
    JSON,
    String,
    Enum as SQLEnum,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import AIChatMessageType


class AIChatMessage(Base):
    __tablename__ = "ai_chat_messages"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    session_id: Mapped[int] = mapped_column(
        ForeignKey("ai_chat_sessions.id", ondelete="CASCADE"),
        nullable=False
    )

    message_type: Mapped[AIChatMessageType] = mapped_column(
        SQLEnum(
            AIChatMessageType,
            name="ai_chat_message_type_enum"
        ),
        nullable=False,
        index=True
    )

    content: Mapped[str] = mapped_column(
        Text,
        nullable=False
    )

    sources: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True
    )

    model_used: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True
    )

    credits_used: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    token_count: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    prompt_tokens: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    completion_tokens: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )

    __table_args__ = (
        Index(
            "ix_ai_chat_messages_session_created",
            "session_id",
            "created_at"
        ),
    )
