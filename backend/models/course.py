from sqlalchemy import (
    String,
    DateTime,
    Boolean,
    Integer,
    Text,
    Float,
    ForeignKey,
    JSON,
    Enum as SQLEnum,
    Index,
    CheckConstraint
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import CourseVisibilityLevel, CourseType, CourseStatus


class Course(Base):
    __tablename__ = "courses"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    # Ownership: either org or individual
    organization_id: Mapped[int | None] = mapped_column(
        ForeignKey("organizations.id", ondelete="SET NULL"),
        nullable=True
    )

    created_by: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True
    )

    title: Mapped[str] = mapped_column(
        String(255),
        nullable=False
    )

    # Optional short code shown in UI (e.g. CS-101)
    course_code: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
        index=True,
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    cover_image_key: Mapped[str | None] = mapped_column(
        String(512),
        nullable=True
    )

    banner_image_key: Mapped[str | None] = mapped_column(
        String(512),
        nullable=True
    )

    is_open_for_enrollment: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        index=True,
    )

    # access_code: Mapped[str | None] = mapped_column(
    #     String(50),
    #     nullable=True
    # )

    visibility_level: Mapped[CourseVisibilityLevel] = mapped_column(
        SQLEnum(CourseVisibilityLevel, name="course_visibility_level_enum"),
        default=CourseVisibilityLevel.private
    )

    requires_enrollment_approval: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    # learning_outcomes: Mapped[dict | None] = mapped_column(
    #     JSON,
    #     nullable=True
    # )

    category: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True
    )

    tags: Mapped[list | None] = mapped_column(
        JSON,
        nullable=True
    )

    course_type: Mapped[CourseType] = mapped_column(
        SQLEnum(
            CourseType,
            name="course_type_enum",
            values_callable=lambda x: [e.value for e in x],
        ),
        default=CourseType.individual,
        index=True
    )

    enrollment_count: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    average_rating: Mapped[float | None] = mapped_column(
        Float,
        nullable=True
    )

    total_ratings: Mapped[int] = mapped_column(
        Integer,
        default=0
    )

    status: Mapped[CourseStatus] = mapped_column(
        SQLEnum(CourseStatus, name="course_status_enum"),
        default=CourseStatus.draft,
        index=True
    )

    published_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
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
        # indexes from schema
        Index("ix_courses_org_id_title", "organization_id", "title"),
        Index("ix_courses_created_by_course_type", "created_by", "course_type"),

        # consistency: organization course must have organization_id, individual must not
        CheckConstraint(
            """
            (
                course_type = 'organization' AND organization_id IS NOT NULL
            )
            OR
            (
                course_type = 'individual' AND organization_id IS NULL
            )
            """,
            name="ck_courses_owner_matches_type"
        ),
    )
