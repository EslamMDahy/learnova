from sqlalchemy import (
    String,
    DateTime,
    Boolean,
    Integer,
    Text,
    ForeignKey,
    Index,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from datetime import datetime

from app.db.base import Base


class Module(Base):
    __tablename__ = "modules"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
    )

    course_id: Mapped[int] = mapped_column(
        ForeignKey("courses.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    title: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    order_index: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
    )

    is_published: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
    )

    published_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    # Optional relationship (nice to have, doesn't change DB schema)
    # materials: Mapped[list["Material"]] = relationship(
    #     "Material",
    #     back_populates="module",
    #     cascade="all, delete-orphan",
    #     passive_deletes=True,
    # )
    materials = relationship(
        "Material", 
        back_populates="module",
        cascade="all, delete-orphan",
        passive_deletes=True,)

    __table_args__ = (
        # unique (course_id, order_index)
        Index(
            "uq_modules_course_order",
            "course_id",
            "order_index",
            unique=True,
        ),
    )