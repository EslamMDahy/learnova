from sqlalchemy import (
    DateTime,
    Integer,
    Float,
    Boolean,
    String,
    ForeignKey,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base


class QuestionRecommendation(Base):
    __tablename__ = "question_recommendations"

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

    question_id: Mapped[int] = mapped_column(
        ForeignKey("questions.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    recommendation_reason: Mapped[str] = mapped_column(
        String(255),
        nullable=False
    )

    priority_score: Mapped[float] = mapped_column(
        Float,
        nullable=False
    )

    is_completed: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        index=True
    )

    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    suggested_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )

    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    __table_args__ = (
        Index(
            "ix_question_recommendations_student_course_suggested",
            "student_id",
            "course_id",
            "suggested_at"
        ),
    )
