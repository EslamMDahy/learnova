from sqlalchemy import (
    String,
    DateTime,
    Integer,
    Text,
    ForeignKey,
    Index,
    CheckConstraint
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base


class VideoTimestamp(Base):
    __tablename__ = "video_timestamps"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    material_id: Mapped[int] = mapped_column(
        ForeignKey("materials.id", ondelete="CASCADE"),
        nullable=False
    )

    topic_id: Mapped[int] = mapped_column(
        ForeignKey("topics.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    title: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    start_time_seconds: Mapped[int] = mapped_column(
        Integer,
        nullable=False
    )

    end_time_seconds: Mapped[int] = mapped_column(
        Integer,
        nullable=False
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )

    __table_args__ = (
        Index("ix_video_timestamps_material_start", "material_id", "start_time_seconds"),
        CheckConstraint("start_time_seconds >= 0", name="ck_video_ts_start_nonneg"),
        CheckConstraint("end_time_seconds >= 0", name="ck_video_ts_end_nonneg"),
        CheckConstraint("end_time_seconds > start_time_seconds", name="ck_video_ts_range_valid"),
    )
