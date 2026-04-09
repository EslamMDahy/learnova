from sqlalchemy import (
    Integer,
    ForeignKey,
    DateTime,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base


class TopicLearningOutcome(Base):
    __tablename__ = "topic_learning_outcomes"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
    )

    topic_id: Mapped[int] = mapped_column(
        ForeignKey("topics.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    learning_outcome_id: Mapped[int] = mapped_column(
        ForeignKey("learning_outcomes.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
    )

    __table_args__ = (
        UniqueConstraint(
            "topic_id",
            "learning_outcome_id",
            name="uq_topic_learning_outcome"
        ),
    )