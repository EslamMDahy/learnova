from sqlalchemy import (
    DateTime,
    Integer,
    Float,
    Text,
    Boolean,
    ForeignKey,
    JSON,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base


class PracticeAnswer(Base):
    __tablename__ = "practice_answers"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    session_id: Mapped[int] = mapped_column(
        ForeignKey("practice_sessions.id", ondelete="CASCADE"),
        nullable=False
    )

    question_id: Mapped[int] = mapped_column(
        ForeignKey("questions.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    # For choice-based questions:
    # - single choice/true-false: selected_option_index
    # - multi-select: selected_option_indices
    selected_option_index: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    selected_option_indices: Mapped[list | None] = mapped_column(
        JSON,
        nullable=True
    )

    answer_text: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    is_correct: Mapped[bool | None] = mapped_column(
        Boolean,
        nullable=True
    )

    points_earned: Mapped[float | None] = mapped_column(
        Float,
        nullable=True
    )

    time_taken_seconds: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    confidence_level: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    answered_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )

    __table_args__ = (
        # unique (session_id, question_id)
        Index(
            "uq_practice_answers_session_question",
            "session_id",
            "question_id",
            unique=True
        ),
    )
