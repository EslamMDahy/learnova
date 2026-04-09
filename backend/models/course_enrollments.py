from sqlalchemy import (
    DateTime,
    Integer,
    ForeignKey,
    Enum as SQLEnum,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import (
    CourseEnrollmentStatus,
    CourseEnrollmentType
)


class CourseEnrollment(Base):
    __tablename__ = "course_enrollments"

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

    status: Mapped[CourseEnrollmentStatus] = mapped_column(
        SQLEnum(
            CourseEnrollmentStatus,
            name="course_enrollment_status_enum"
        ),
        default=CourseEnrollmentStatus.active
    )

    enrollment_type: Mapped[CourseEnrollmentType] = mapped_column(
        SQLEnum(
            CourseEnrollmentType,
            name="course_enrollment_type_enum"
        ),
        default=CourseEnrollmentType.self,
        index=True
    )

    enrolled_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )

    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    __table_args__ = (
        # unique (student_id, course_id)
        Index(
            "uq_course_enrollments_student_course",
            "student_id",
            "course_id",
            unique=True
        ),
        # (student_id, status)
        Index(
            "ix_course_enrollments_student_status",
            "student_id",
            "status"
        ),
    )
