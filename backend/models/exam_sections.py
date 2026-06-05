from sqlalchemy import (
    String,
    DateTime,
    Boolean,
    Integer,
    Float,
    Text,
    ForeignKey,
    Enum as SQLEnum,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import QuestionType


class ExamSection(Base):
    __tablename__ = "exam_sections"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    exam_id: Mapped[int] = mapped_column(
        ForeignKey("exams.id", ondelete="CASCADE"),
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

    question_type: Mapped[QuestionType] = mapped_column(
        SQLEnum(
            QuestionType,
            name="question_type_enum"
        ),
        nullable=False
    )

    order_index: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    question_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0
    )

    section_score: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        default=0.0
    )

    time_limit_minutes: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    must_complete: Mapped[bool] = mapped_column(
        Boolean,
        default=True
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
        # unique ordering inside exam
        Index(
            "uq_exam_sections_exam_order",
            "exam_id",
            "order_index",
            unique=True
        ),
    )
