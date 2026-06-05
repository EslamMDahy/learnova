from datetime import datetime

from sqlalchemy import (
    Integer,
    Float,
    Text,
    Boolean,
    DateTime,
    ForeignKey,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import JSONB

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

    section_id: Mapped[int] = mapped_column(
        ForeignKey("exam_sections.id", ondelete="CASCADE"),
        nullable=False,
        index=True
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

    snapshot_topic_id: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    snapshot_question_text: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    snapshot_explanation: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    snapshot_options: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True
    )

    snapshot_type: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    snapshot_difficulty: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    snapshot_expected_answer: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True
    )

    snapshot_grading_rubric: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True
    )

    snapshot_max_score: Mapped[float | None] = mapped_column(
        Float,
        nullable=True
    )

    snapshot_auto_gradable: Mapped[bool | None] = mapped_column(
        Boolean,
        nullable=True
    )

    snapshot_tags: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True
    )

    snapshot_source_question_updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    snapshot_created_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
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
        # unique ordering inside section
        Index(
            "uq_exam_questions_section_order",
            "section_id",
            "order_index",
            unique=True
        ),
    )
