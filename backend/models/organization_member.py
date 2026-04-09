from sqlalchemy import (
    String,
    DateTime,
    Integer,
    ForeignKey,
    JSON,
    Enum as SQLEnum,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import OrganizationMemberRole, OrganizationMemberStatus


class OrganizationMember(Base):
    __tablename__ = "organization_members"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    organization_id: Mapped[int] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False
    )

    role: Mapped[OrganizationMemberRole] = mapped_column(
        SQLEnum(OrganizationMemberRole, name="organization_member_role_enum"),
        nullable=False,
        index=True
    )

    title: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True
    )

    department: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True
    )

    status: Mapped[OrganizationMemberStatus] = mapped_column(
        SQLEnum(OrganizationMemberStatus, name="organization_member_status_enum"),
        nullable=False,
        default=OrganizationMemberStatus.pending
    )

    invited_by: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True
    )

    invited_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    joined_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    last_active_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    permissions: Mapped[dict | None] = mapped_column(
        JSON,
        nullable=True
    )

    __table_args__ = (
        # unique (organization_id, user_id)
        Index(
            "uq_org_members_org_id_user_id",
            "organization_id",
            "user_id",
            unique=True
        ),
        # (user_id, status)
        Index(
            "ix_org_members_user_id_status",
            "user_id",
            "status"
        ),
    )
