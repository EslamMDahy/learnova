from sqlalchemy import (
    Date,
    DateTime,
    Integer,
    Float,
    ForeignKey,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base


class AnalyticsDashboard(Base):
    __tablename__ = "analytics"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    # nullable for individual analytics
    organization_id: Mapped[int | None] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=True
    )

    # individual owner / instructor analytics
    user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=True
    )

    course_id: Mapped[int | None] = mapped_column(
        ForeignKey("courses.id", ondelete="CASCADE"),
        nullable=True
    )

    date: Mapped[datetime] = mapped_column(
        Date,
        nullable=False
    )

    active_students: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    active_teachers: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    new_users: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    total_enrollments: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    total_exams_taken: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    total_questions_answered: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    total_practice_sessions: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    average_score: Mapped[float | None] = mapped_column(
        Float,
        nullable=True
    )

    completion_rate: Mapped[float | None] = mapped_column(
        Float,
        nullable=True
    )

    engagement_score: Mapped[float | None] = mapped_column(
        Float,
        nullable=True
    )

    ai_chat_usage: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    ai_question_gen_usage: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    credits_used: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    credits_purchased: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    total_courses: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    total_materials: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    total_questions: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )

    __table_args__ = (
        Index("ix_analytics_dashboard_org_date", "organization_id", "date"),
        Index("ix_analytics_dashboard_user_date", "user_id", "date"),
        Index("ix_analytics_dashboard_course_date", "course_id", "date"),
    )
