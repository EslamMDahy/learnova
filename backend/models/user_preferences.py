from sqlalchemy import (
    String,
    DateTime,
    Boolean,
    Integer,
    ForeignKey,
    Enum as SQLEnum
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import ThemeMode, ProfileVisibility


class UserPreference(Base):
    __tablename__ = "user_preferences"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True
    )

    # Notifications
    email_notifications: Mapped[bool] = mapped_column(
        Boolean,
        default=True
    )

    assignment_alerts: Mapped[bool] = mapped_column(
        Boolean,
        default=True
    )

    course_updates: Mapped[bool] = mapped_column(
        Boolean,
        default=True
    )

    announcement_notifications: Mapped[bool] = mapped_column(
        Boolean,
        default=True
    )

    grading_notifications: Mapped[bool] = mapped_column(
        Boolean,
        default=True
    )

    deadline_reminders: Mapped[bool] = mapped_column(
        Boolean,
        default=True
    )

    # Display
    theme_mode: Mapped[ThemeMode] = mapped_column(
        SQLEnum(ThemeMode, name="theme_mode_enum"),
        default=ThemeMode.light
    )

    # Privacy
    profile_visibility: Mapped[ProfileVisibility] = mapped_column(
        SQLEnum(ProfileVisibility, name="profile_visibility_enum"),
        default=ProfileVisibility.private
    )

    show_online_status: Mapped[bool] = mapped_column(
        Boolean,
        default=True
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
