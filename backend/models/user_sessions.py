from sqlalchemy import (
    String,
    DateTime,
    Integer,
    ForeignKey,
    Text,
    JSON
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base


class UserSession(Base):
    __tablename__ = "user_sessions"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    session_token: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        nullable=False,
        index=True
    )

    device_type: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True
    )

    device_info: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True
    )

    ip_address: Mapped[str | None] = mapped_column(
        String(45),  # IPv4 / IPv6 safe
        nullable=True
    )

    user_agent: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        index=True
    )

    last_active_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )