from sqlalchemy import (
    String,
    DateTime,
    Boolean,
    Integer,
    Text,
    ForeignKey,
    JSON,
    Enum as SQLEnum,
    Index,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from datetime import datetime

from app.db.base import Base
from app.models.enums import MaterialType, MaterialStatus

class Material(Base):
    __tablename__ = "materials"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
    )

    # New: material belongs to a module (not a topic)
    module_id: Mapped[int] = mapped_column(
        ForeignKey("modules.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Optional relationship (nice to have)
    # module: Mapped["Module"] = relationship(
    #     "Module",
    #     back_populates="materials",
    # )
    module = relationship(
        "Module", 
        back_populates="materials")

    # For deadline-friendly flow:
    # - You can create the DB row at init-upload time without forcing title/description.
    # - You can later add an endpoint to set/update title/description.
    title: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    type: Mapped[MaterialType] = mapped_column(
        SQLEnum(MaterialType, name="material_type_enum"),
        nullable=False,
        index=True,
        default=MaterialType.pdf,
    )

    file_name: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )

    file_size: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
    )

    # Replaces file_url: store the storage key/path, not a URL
    # Example: courses/{course_id}/modules/{module_id}/materials/{material_id}/{filename}
    storage_key: Mapped[str] = mapped_column(
        String(1024),
        nullable=False,
    )

    thumbnail_key: Mapped[str | None] = mapped_column(
        String(1024),
        nullable=True,
    )

    mime_type: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
    )

    status: Mapped[MaterialStatus] = mapped_column(
        SQLEnum(MaterialStatus, name="material_status_enum"),
        nullable=False,
        default=MaterialStatus.draft_upload,  # requires enum update
        index=True,
    )

    # AI pipeline fields (keep them, you can simplify later)
    # text_extracted: Mapped[bool] = mapped_column(
    #     Boolean,
    #     default=False,
    # )

    # transcript_text: Mapped[str | None] = mapped_column(
    #     Text,
    #     nullable=True,
    # )

    # extracted_text: Mapped[str | None] = mapped_column(
    #     Text,
    #     nullable=True,
    # )

    duration_seconds: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
    )

    page_count: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
    )

    dimensions: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True,
    )

    use_ai_processing: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    is_ai_processed: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
    )

    ai_processed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    uploaded_by: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    uploaded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
    )

    processed_at: Mapped[datetime | None] = mapped_column(
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

    __table_args__ = (
        Index("ix_materials_module_type", "module_id", "type"),
        Index("ix_materials_module_status", "module_id", "status"),
    )