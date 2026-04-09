from sqlalchemy import (
    String,
    DateTime,
    Boolean,
    Integer,
    Float,
    ForeignKey,
    Enum as SQLEnum,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import AIChatContextType


class AIChatSession(Base):
    __tablename__ = "ai_chat_sessions"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False
    )

    course_id: Mapped[int | None] = mapped_column(
        ForeignKey("courses.id", ondelete="SET NULL"),
        nullable=True
    )

    session_title: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True
    )

    context_type: Mapped[AIChatContextType] = mapped_column(
        SQLEnum(
            AIChatContextType,
            name="ai_chat_context_type_enum"
        ),
        default=AIChatContextType.general,
        index=True
    )

    context_id: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True
    )

    credits_used: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )

    last_message_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    ended_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    model_used: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True
    )

    temperature: Mapped[float | None] = mapped_column(
        Float,
        nullable=True
    )

    __table_args__ = (
        Index("ix_ai_chat_sessions_user_active", "user_id", "is_active"),
        Index("ix_ai_chat_sessions_course_last_msg", "course_id", "last_message_at"),
    )
