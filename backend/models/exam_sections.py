from sqlalchemy import (
    String,
    DateTime,
    Boolean,
    Integer,
    Float,
    Text,
    ForeignKey,
    Enum as SQLEnum,
    Index,
    CheckConstraint
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import ExamSectionDifficulty


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

    title: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    order_index: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    topic_id: Mapped[int | None] = mapped_column(
        ForeignKey("topics.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )

    module_id: Mapped[int | None] = mapped_column(
        ForeignKey("modules.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )

    material_id: Mapped[int | None] = mapped_column(
        ForeignKey("materials.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )
    difficulty: Mapped[ExamSectionDifficulty | None] = mapped_column(
        SQLEnum(
            ExamSectionDifficulty,
            name="exam_section_difficulty_enum"
        ),
        nullable=True
    )

    question_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False
    )

    section_score: Mapped[float] = mapped_column(
        Float,
        nullable=False
    )

    time_limit_minutes: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    must_complete: Mapped[bool] = mapped_column(
        Boolean,
        default=True
    )

    __table_args__ = (
        CheckConstraint(
            "(topic_id IS NOT NULL) OR (module_id IS NOT NULL) OR (material_id IS NOT NULL)",
            name="ck_exam_sections_scope_required"
        ),
        # unique (exam_id, order_index)
        Index(
            "uq_exam_sections_exam_order",
            "exam_id",
            "order_index",
            unique=True
        ),
        Index(
            "ix_exam_sections_exam_scope",
            "exam_id",
            "topic_id",
            "module_id",
            "material_id"
        ),
    )
