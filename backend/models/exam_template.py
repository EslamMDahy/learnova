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
from app.models.enums import ExamType


class ExamTemplate(Base):
    __tablename__ = "exam_templates"

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

    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False
    )

    exam_type: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True
    )

    is_default: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False
    )

    duration_minutes: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    max_attempts: Mapped[int] = mapped_column(
        Integer,
        default=1,
        nullable=False
    )

    passing_score: Mapped[float | None] = mapped_column(
        Float,
        nullable=True
    )

    shuffle_questions: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False
    )

    shuffle_options: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False
    )

    total_questions: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False
    )

    total_score: Mapped[float] = mapped_column(
        Float,
        default=0.0,
        nullable=False
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        nullable=False
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        nullable=False
    )

    __table_args__ = (
        Index(
            "ix_exam_templates_course_type",
            "course_id",
            "exam_type"
        ),
        Index(
            "uq_exam_templates_course_name",
            "course_id",
            "name",
            unique=True
        ),
    )
