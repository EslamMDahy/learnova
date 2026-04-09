from sqlalchemy import (
    String,
    DateTime,
    Integer,
    ForeignKey,
    JSON,
    Enum as SQLEnum,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import CourseInstructorRole


class CourseInstructor(Base):
    __tablename__ = "course_instructors"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    course_id: Mapped[int] = mapped_column(
        ForeignKey("courses.id", ondelete="CASCADE"),
        nullable=False
    )

    instructor_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    organization_id: Mapped[int | None] = mapped_column(
        ForeignKey("organizations.id", ondelete="SET NULL"),
        nullable=True
    )

    role: Mapped[CourseInstructorRole] = mapped_column(
        SQLEnum(
            CourseInstructorRole,
            name="course_instructor_role_enum"
        ),
        default=CourseInstructorRole.instructor
    )

    permissions: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True
    )

    added_by: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True
    )

    added_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )

    __table_args__ = (
        # unique (course_id, instructor_id)
        Index(
            "uq_course_instructors_course_instructor",
            "course_id",
            "instructor_id",
            unique=True
        ),
    )
