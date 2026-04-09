from sqlalchemy import (
    Integer,
    Float,
    Text,
    ForeignKey,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class ExamQuestion(Base):
    __tablename__ = "exam_questions"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    exam_id: Mapped[int] = mapped_column(
        ForeignKey("exams.id", ondelete="CASCADE"),
        nullable=False
    )

    section_id: Mapped[int | None] = mapped_column(
        ForeignKey("exam_sections.id", ondelete="SET NULL"),
        nullable=True
    )

    question_id: Mapped[int] = mapped_column(
        ForeignKey("questions.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    order_index: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    points: Mapped[float] = mapped_column(
        Float,
        default=1.0
    )

    custom_points: Mapped[float | None] = mapped_column(
        Float,
        nullable=True
    )

    custom_instructions: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    __table_args__ = (
        # each question appears once per exam
        Index(
            "uq_exam_questions_exam_question",
            "exam_id",
            "question_id",
            unique=True
        ),
        # unique ordering inside exam
        Index(
            "uq_exam_questions_exam_order",
            "exam_id",
            "order_index",
            unique=True
        ),
    )
