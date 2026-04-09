from sqlalchemy import (
    String,
    DateTime,
    Integer,
    ForeignKey,
    Enum as SQLEnum,
    Index
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import (
    OrganizationInvitationRole,
    OrganizationInvitationStatus
)


class OrganizationInvitation(Base):
    __tablename__ = "organization_invitations"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    organization_id: Mapped[int] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False
    )

    email: Mapped[str] = mapped_column(
        String(255),
        nullable=False
    )

    role: Mapped[OrganizationInvitationRole] = mapped_column(
        SQLEnum(
            OrganizationInvitationRole,
            name="organization_invitation_role_enum"
        ),
        nullable=False
    )

    invited_by: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False
    )

    token: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        nullable=False,
        index=True
    )

    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        index=True
    )

    status: Mapped[OrganizationInvitationStatus] = mapped_column(
        SQLEnum(
            OrganizationInvitationStatus,
            name="organization_invitation_status_enum"
        ),
        default=OrganizationInvitationStatus.pending
    )

    accepted_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True
    )

    accepted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )

    __table_args__ = (
        # (organization_id, email, status)
        Index(
            "ix_org_invitations_org_email_status",
            "organization_id",
            "email",
            "status"
        ),
    )
