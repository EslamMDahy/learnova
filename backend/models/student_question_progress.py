from sqlalchemy import (
    DateTime,
    Integer,
    Float,
    ForeignKey,
    Enum as SQLEnum,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import QuestionMasteryLevel


class StudentQuestionProgress(Base):
    __tablename__ = "student_question_progress"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    student_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False
    )

    question_id: Mapped[int] = mapped_column(
        ForeignKey("questions.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    times_attempted: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    times_correct: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    times_wrong: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    average_time_seconds: Mapped[float | None] = mapped_column(
        Float,
        nullable=True
    )

    mastery_level: Mapped[QuestionMasteryLevel] = mapped_column(
        SQLEnum(
            QuestionMasteryLevel,
            name="question_mastery_level_enum"
        ),
        default=QuestionMasteryLevel.unattempted,
        index=True
    )

    last_attempted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    last_correct_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    __table_args__ = (
        # unique (student_id, question_id)
        Index(
            "uq_student_question_progress_student_question",
            "student_id",
            "question_id",
            unique=True
        ),
    )
