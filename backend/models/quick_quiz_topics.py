from sqlalchemy import (
    Integer,
    ForeignKey,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class QuickQuizTopic(Base):
    __tablename__ = "quick_quiz_topics"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    quick_quiz_id: Mapped[int] = mapped_column(
        ForeignKey("quick_quizzes.id", ondelete="CASCADE"),
        nullable=False
    )

    topic_id: Mapped[int] = mapped_column(
        ForeignKey("topics.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    __table_args__ = (
        # unique (quick_quiz_id, topic_id)
        Index(
            "uq_quick_quiz_topics_quiz_topic",
            "quick_quiz_id",
            "topic_id",
            unique=True
        ),
    )
