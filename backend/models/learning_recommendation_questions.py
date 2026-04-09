from sqlalchemy import (
    Integer,
    ForeignKey,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class LearningRecommendationQuestion(Base):
    __tablename__ = "learning_recommendation_questions"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    recommendation_id: Mapped[int] = mapped_column(
        ForeignKey("learning_recommendations.id", ondelete="CASCADE"),
        nullable=False
    )

    question_id: Mapped[int] = mapped_column(
        ForeignKey("questions.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    __table_args__ = (
        # unique (recommendation_id, question_id)
        Index(
            "uq_learning_recommendation_questions_rec_question",
            "recommendation_id",
            "question_id",
            unique=True
        ),
    )
