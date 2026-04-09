from sqlalchemy import (
    DateTime,
    Integer,
    Float,
    Text,
    ForeignKey,
    Enum as SQLEnum,
    Index,
    Boolean,
    CheckConstraint
)
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime

from app.db.base import Base
from app.models.enums import (
    QuestionType,
    QuestionDifficulty,
    QuestionSource,
    QuestionApprovalStatus
)


class Question(Base):
    __tablename__ = "questions"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    course_id: Mapped[int] = mapped_column(
        ForeignKey("courses.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    topic_id: Mapped[int] = mapped_column(
        ForeignKey("topics.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    question_text: Mapped[str] = mapped_column(
        Text,
        nullable=False
    )

    explanation: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    # Used only for choice-based questions like:
    # multiple_choice / multi_select / true_false / matching / ordering
    options: Mapped[list | None] = mapped_column(
        JSONB,
        nullable=True
    )

    type: Mapped[QuestionType] = mapped_column(
        SQLEnum(QuestionType, name="question_type_enum"),
        nullable=False
    )

    difficulty: Mapped[QuestionDifficulty] = mapped_column(
        SQLEnum(QuestionDifficulty, name="question_difficulty_enum"),
        nullable=False,
        index=True,
        default=QuestionDifficulty.medium
    )

    source: Mapped[QuestionSource] = mapped_column(
        SQLEnum(QuestionSource, name="question_source_enum"),
        nullable=False,
        default=QuestionSource.manual
    )

    approval_status: Mapped[QuestionApprovalStatus] = mapped_column(
        SQLEnum(
            QuestionApprovalStatus,
            name="question_approval_status_enum"
        ),
        nullable=False,
        default=QuestionApprovalStatus.approved,
        index=True
    )

    expected_answer: Mapped[dict | list | str | None] = mapped_column(
        JSONB,
        nullable=True
    )

    grading_rubric: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True
    )

    max_score: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=1
    )

    auto_gradable: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True
    )

    usage_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
        index=True
    )

    success_rate: Mapped[float | None] = mapped_column(
        Float,
        nullable=True
    )

    average_time_seconds: Mapped[float | None] = mapped_column(
        Float,
        nullable=True
    )

    tags: Mapped[list | None] = mapped_column(
        JSONB,
        nullable=True
    )

    created_by: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=datetime.utcnow
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow
    )

    __table_args__ = (
        Index("ix_questions_course_topic", "course_id", "topic_id"),
        Index("ix_questions_course_type", "course_id", "type"),
        Index("ix_questions_topic_type", "topic_id", "type"),
        Index("ix_questions_course_difficulty", "course_id", "difficulty"),
        Index("ix_questions_course_approval_status", "course_id", "approval_status"),

        CheckConstraint("max_score > 0", name="ck_questions_max_score_positive"),
    )