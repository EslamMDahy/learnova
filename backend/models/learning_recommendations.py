from sqlalchemy import (
    DateTime,
    Integer,
    Float,
    Boolean,
    Text,
    ForeignKey,
    Enum as SQLEnum,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import LearningRecommendationType


class LearningRecommendation(Base):
    __tablename__ = "learning_recommendations"

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

    recommendation_type: Mapped[LearningRecommendationType] = mapped_column(
        SQLEnum(
            LearningRecommendationType,
            name="learning_recommendation_type_enum"
        ),
        nullable=False
    )

    target_topic_id: Mapped[int | None] = mapped_column(
        ForeignKey("topics.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )

    target_material_id: Mapped[int | None] = mapped_column(
        ForeignKey("materials.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )

    priority: Mapped[int] = mapped_column(
        Integer,
        default=1
    )

    confidence_score: Mapped[float | None] = mapped_column(
        Float,
        nullable=True
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

    generated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )

    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    reason: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    expected_benefit: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    __table_args__ = (
        Index(
            "ix_learning_recommendations_student_course_generated",
            "student_id",
            "course_id",
            "generated_at"
        ),
    )
