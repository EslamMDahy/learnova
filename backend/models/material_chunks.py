from sqlalchemy import (
    DateTime,
    Integer,
    Text,
    ForeignKey,
    JSON,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

# pgvector
# from pgvector.sqlalchemy import Vector

from app.db.base import Base


class MaterialChunk(Base):
    __tablename__ = "material_chunks"

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

    chunk_text: Mapped[str] = mapped_column(
        Text,
        nullable=False
    )

    chunk_index: Mapped[int] = mapped_column(
        Integer,
        nullable=False
    )

    start_page: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    start_time_seconds: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True
    )

    # embedding: Mapped[list[float] | None] = mapped_column(
    #     Vector(384),
    #     nullable=True
    # )

    extra_metadata: Mapped[dict | None] = mapped_column("metadata", JSON, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )

    __table_args__ = (
        # unique (material_id, chunk_index)
        Index(
            "uq_material_chunks_material_index",
            "material_id",
            "chunk_index",
            unique=True
        ),
    )
