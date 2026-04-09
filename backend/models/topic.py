from sqlalchemy import (
    String,
    DateTime,
    Boolean,
    Integer,
    Text,
    ForeignKey,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base


class Topic(Base):
    __tablename__ = "topics"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    material_id: Mapped[int] = mapped_column(
        ForeignKey("materials.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    title: Mapped[str] = mapped_column(
        String(255),
        nullable=False
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    order_index: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0
    )

    parent_topic_id: Mapped[int | None] = mapped_column(
        ForeignKey("topics.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )

    is_ai_generated: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        index=True
    )

    is_reviewed: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        index=True
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
        Index("ix_topics_material_parent", "material_id", "parent_topic_id"),
        Index("ix_topics_material_order", "material_id", "order_index"),
    )