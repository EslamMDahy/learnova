from sqlalchemy import (
    DateTime,
    Integer,
    Boolean,
    ForeignKey,
    JSON,
    Enum as SQLEnum,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import QuickQuizDifficulty, QuickQuizStatus


class QuickQuiz(Base):
    __tablename__ = "quick_quizzes"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    student_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False
    )

    course_id: Mapped[int] = mapped_column(
        ForeignKey("courses.id", ondelete="CASCADE"),
        nullable=False
    )

    question_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False
    )

    difficulty: Mapped[QuickQuizDifficulty] = mapped_column(
        SQLEnum(QuickQuizDifficulty, name="quick_quiz_difficulty_enum"),
        default=QuickQuizDifficulty.mixed
    )

    include_weak_points: Mapped[bool] = mapped_column(
        Boolean,
        default=True
    )

    time_limit_minutes: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    status: Mapped[QuickQuizStatus] = mapped_column(
        SQLEnum(QuickQuizStatus, name="quick_quiz_status_enum"),
        default=QuickQuizStatus.generated,
        index=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )

    started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    configuration: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True
    )

    __table_args__ = (
        Index("ix_quick_quizzes_student_course_created", "student_id", "course_id", "created_at"),
    )
