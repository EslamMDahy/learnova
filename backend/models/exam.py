from sqlalchemy import (
    String,
    DateTime,
    Boolean,
    Integer,
    Float,
    Text,
    ForeignKey,
    JSON,
    Enum as SQLEnum,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import ExamType


class Exam(Base):
    __tablename__ = "exams"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    course_id: Mapped[int] = mapped_column(
        ForeignKey("courses.id", ondelete="CASCADE"),
        nullable=False
    )

    title: Mapped[str] = mapped_column(
        String(255),
        nullable=False
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    instructions: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    exam_type: Mapped[ExamType] = mapped_column(
        SQLEnum(ExamType, name="exam_type_enum"),
        nullable=False,
        index=True
    )

    duration_minutes: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    max_attempts: Mapped[int] = mapped_column(
        Integer,
        default=1
    )

    passing_score: Mapped[float | None] = mapped_column(
        Float,
        nullable=True
    )

    total_questions: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0
    )

    total_score: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        default=0
    )

    is_published: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    is_auto_generated: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    shuffle_questions: Mapped[bool] = mapped_column(
        Boolean,
        default=True
    )

    shuffle_options: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    available_from: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        index=True
    )

    available_to: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        index=True
    )

    enable_proctoring: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    prevent_copy_paste: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    prevent_tab_switch: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    require_webcam: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    require_microphone: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    access_code: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True
    )

    ip_restrictions: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True
    )

    created_by: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
        onupdate=datetime.utcnow
    )

    __table_args__ = (
        Index("ix_exams_course_published", "course_id", "is_published"),
    )
