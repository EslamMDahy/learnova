from sqlalchemy import (
    Integer,
    String,
    ForeignKey,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class QuestionTag(Base):
    __tablename__ = "question_tags"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    question_id: Mapped[int] = mapped_column(
        ForeignKey("questions.id", ondelete="CASCADE"),
        nullable=False
    )

    tag_name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        index=True
    )

    __table_args__ = (
        # unique (question_id, tag_name)
        Index(
            "uq_question_tags_question_tag",
            "question_id",
            "tag_name",
            unique=True
        ),
    )
