from sqlalchemy import (
    DateTime,
    Integer,
    Float,
    ForeignKey,
    JSON,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base


class StudentWeakPoint(Base):
    __tablename__ = "weak_points"

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

    topic_id: Mapped[int] = mapped_column(
        ForeignKey("topics.id", ondelete="CASCADE"),
        nullable=False
    )

    weakness_score: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        index=True
    )

    error_count: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    total_attempts: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    last_updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )

    metrics: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True
    )

    __table_args__ = (
        # unique (student_id, course_id, topic_id)
        Index(
            "uq_student_weak_points_student_course_topic",
            "student_id",
            "course_id",
            "topic_id",
            unique=True
        ),
        # (course_id, topic_id)
        Index(
            "ix_student_weak_points_course_topic",
            "course_id",
            "topic_id"
        ),
    )
