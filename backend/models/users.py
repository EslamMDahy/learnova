from sqlalchemy import (
    String,
    DateTime,
    Boolean,
    Integer,
    Text,
    Enum as SQLEnum
)
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime

from app.db.base import Base
from app.models.enums import SystemRole, AccountStatus



class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    full_name: Mapped[str] = mapped_column(
        String(255),
        nullable=False
    )

    email: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        nullable=False,
        index=True
    )

    hashed_password: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True
    )

    avatar_key: Mapped[str | None] = mapped_column(
        String(512),
        nullable=True
    )

    phone_number: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True
    )

    bio: Mapped[str | None] = mapped_column(
        Text,
        nullable=True
    )

    student_id: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True
    )

    university_email: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True
    )

    language_preference: Mapped[str] = mapped_column(
        String(20),
        default="en_US"
    )

    system_role: Mapped[SystemRole] = mapped_column(
        SQLEnum(SystemRole, name="system_role_enum"),
    )

    is_email_verified: Mapped[bool] = mapped_column(
        Boolean,
        default=False
    )

    email_verified_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    account_status: Mapped[AccountStatus] = mapped_column(
        SQLEnum(AccountStatus, name="account_status_enum"),
        default=AccountStatus.active,
        index=True
    )

    last_login_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    last_password_change: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    # token_version: Mapped[int] = mapped_column(
    #     Integer,
    #     nullable=False,
    #     server_default="1"
    # )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
        onupdate=datetime.utcnow
    )
