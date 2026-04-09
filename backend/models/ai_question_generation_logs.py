from sqlalchemy import (
    String,
    DateTime,
    Integer,
    Text,
    ForeignKey,
    JSON,
    Boolean,
    CheckConstraint,
    Enum as SQLEnum,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import AIQuestionGenerationStatus, QuestionGenerationScope


class AIQuestionGenerationLog(Base):
    __tablename__ = "ai_question_generation_logs"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    # Generation scope chosen by instructor
    scope: Mapped[QuestionGenerationScope] = mapped_column(
        SQLEnum(
            QuestionGenerationScope,
            name="question_generation_scope_enum"
        ),
        default=QuestionGenerationScope.topic,
        index=True
    )

    # Context references (only one is expected based on `scope`)
    course_id: Mapped[int | None] = mapped_column(
        ForeignKey("courses.id", ondelete="CASCADE"),
        nullable=True,
        index=True
    )

    module_id: Mapped[int | None] = mapped_column(
        ForeignKey("modules.id", ondelete="CASCADE"),
        nullable=True,
        index=True
    )

    topic_id: Mapped[int | None] = mapped_column(
        ForeignKey("topics.id", ondelete="CASCADE"),
        nullable=True,
        index=True
    )

    material_id: Mapped[int | None] = mapped_column(
        ForeignKey("materials.id", ondelete="CASCADE"),
        nullable=True,
        index=True
    )

    model_used: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True
    )

    credits_used: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    requested_count: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    requested_question_types: Mapped[list | None] = mapped_column(
        JSON,
        nullable=True
    )

    requested_difficulty: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True
    )

    include_answers: Mapped[bool] = mapped_column(
        Boolean,
        default=True
    )

    include_explanations: Mapped[bool] = mapped_column(
        Boolean,
        default=True
    )

    status: Mapped[AIQuestionGenerationStatus] = mapped_column(
        SQLEnum(
            AIQuestionGenerationStatus,
            name="ai_question_generation_status_enum"
        ),
        default=AIQuestionGenerationStatus.completed,
        index=True
    )

    error_message: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )

    __table_args__ = (
        CheckConstraint(
            "(course_id IS NOT NULL) OR (module_id IS NOT NULL) OR (topic_id IS NOT NULL) OR (material_id IS NOT NULL)",
            name="ck_ai_qgen_scope_ref_required"
        ),
        # (material_id, topic_id, created_at)
        Index(
            "ix_ai_qgen_course_created",
            "course_id",
            "created_at"
        ),
        Index(
            "ix_ai_qgen_module_created",
            "module_id",
            "created_at"
        ),
        Index(
            "ix_ai_qgen_topic_created",
            "topic_id",
            "created_at"
        ),
        Index(
            "ix_ai_qgen_material_topic_created",
            "material_id",
            "topic_id",
            "created_at"
        ),
    )
