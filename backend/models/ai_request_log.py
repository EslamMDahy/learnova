from datetime import datetime, timezone

from sqlalchemy import (
    DateTime,
    Index,
    Integer,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class AIRequestLog(Base):
    __tablename__ = "ai_request_logs"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
    )

    request_id: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        unique=True,
        index=True,
    )

    course_id: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        index=True,
    )

    operation_type: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        index=True,
    )

    http_method: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
        default="POST",
    )

    target_endpoint: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )

    request_payload: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
    )

    response_payload: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
    )

    status: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        index=True,
    )

    error_message: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    primary_entity_type: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
    )

    primary_entity_id: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )

    sent_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    callback_received_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    last_error_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        onupdate=utc_now,
        nullable=False,
    )

    __table_args__ = (
        Index("ix_ai_request_logs_operation_status", "operation_type", "status"),
        Index("ix_ai_request_logs_course_operation", "course_id", "operation_type"),
        Index("ix_ai_request_logs_status_expires_at", "status", "expires_at"),
    )