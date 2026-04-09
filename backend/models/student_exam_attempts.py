from sqlalchemy import (
    DateTime,
    Integer,
    Float,
    Boolean,
    Text,
    ForeignKey,
    JSON,
    Enum as SQLEnum,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import ExamAttemptStatus


class StudentExamAttempt(Base):
    __tablename__ = "student_exam_attempts"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    student_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False
    )

    exam_id: Mapped[int] = mapped_column(
        ForeignKey("exams.id", ondelete="CASCADE"),
        nullable=False
    )

    attempt_number: Mapped[int] = mapped_column(
        Integer,
        default=1
    )

    status: Mapped[ExamAttemptStatus] = mapped_column(
        SQLEnum(
            ExamAttemptStatus,
            name="exam_attempt_status_enum"
        ),
        default=ExamAttemptStatus.in_progress,
        index=True
    )

    started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    submitted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    graded_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    time_spent_seconds: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    total_score: Mapped[float | None] = mapped_column(
        Float,
        nullable=True
    )

    percentage_score: Mapped[float | None] = mapped_column(
        Float,
        nullable=True
    )

    is_passed: Mapped[bool | None] = mapped_column(
        Boolean,
        nullable=True
    )

    correct_count: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    incorrect_count: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    unanswered_count: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    cheating_flags: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True
    )

    session_data: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True
    )

    proctoring_data: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True
    )

    teacher_feedback: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    teacher_reviewed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    __table_args__ = (
        # unique (student_id, exam_id, attempt_number)
        Index(
            "uq_student_exam_attempts_student_exam_attempt",
            "student_id",
            "exam_id",
            "attempt_number",
            unique=True
        ),
        # (exam_id, started_at)
        Index(
            "ix_student_exam_attempts_exam_started",
            "exam_id",
            "started_at"
        ),
    )
