from sqlalchemy import (
    String,
    DateTime,
    Boolean,
    Integer,
    Text,
    ForeignKey,
    JSON,
    Enum as SQLEnum,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import NotificationType


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False
    )

    type: Mapped[NotificationType] = mapped_column(
        SQLEnum(
            NotificationType,
            name="notification_type_enum"
        ),
        nullable=False,
        index=True
    )

    title: Mapped[str] = mapped_column(
        String(255),
        nullable=False
    )

    body: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    data: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True
    )

    is_read: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    read_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    delivery_channels: Mapped[list] = mapped_column(
        JSON,
        default=lambda: ["in_app"]
    )

    sent_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
        index=True
    )

    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    __table_args__ = (
        Index(
            "ix_notifications_user_read",
            "user_id",
            "is_read"
        ),
    )
