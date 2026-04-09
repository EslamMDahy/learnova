from sqlalchemy import (
    Integer,
    ForeignKey,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class AIQuestionGenerationLogQuestion(Base):
    __tablename__ = "ai_question_generation_log_questions"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    log_id: Mapped[int] = mapped_column(
        ForeignKey("ai_question_generation_logs.id", ondelete="CASCADE"),
        nullable=False
    )

    question_id: Mapped[int] = mapped_column(
        ForeignKey("questions.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    __table_args__ = (
        # unique (log_id, question_id)
        Index(
            "uq_ai_qgen_log_question",
            "log_id",
            "question_id",
            unique=True
        ),
    )
