from sqlalchemy import (
    String,
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
from app.models.enums import QuestionType


class ExamTemplateSection(Base):
    __tablename__ = "exam_template_sections"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    template_id: Mapped[int] = mapped_column(
        ForeignKey("exam_templates.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    title: Mapped[str] = mapped_column(
        String(255),
        nullable=False
    )

    question_type: Mapped[QuestionType] = mapped_column(
        SQLEnum(
            QuestionType,
            name="question_type_enum"
        ),
        nullable=False
    )

    question_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0
    )

    points_per_question: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        default=1.0
    )

    section_score: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        default=0.0
    )

    order_index: Mapped[int] = mapped_column(
        Integer,
        default=0
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
            "uq_exam_template_sections_template_order",
            "template_id",
            "order_index",
            unique=True
        ),
    )
