import enum
from sqlalchemy import (
    Column, Integer, String, DateTime, ForeignKey,
    Enum as SAEnum, UniqueConstraint, Index, text
)
from sqlalchemy.orm import relationship

from app.db.base import Base  # حسب مشروعك

class CourseInviteStatus(str, enum.Enum):
    pending = "pending"
    accepted = "accepted"
    revoked = "revoked"
    expired = "expired"

class CourseInvitation(Base):
    __tablename__ = "course_invitations"

    id = Column(Integer, primary_key=True)

    course_id = Column(Integer, ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    created_by = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    invited_email = Column(String(320), nullable=False)   # 320 للـ RFC emails
    invited_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    # نخزن HASH فقط
    token_hash = Column(String(128), nullable=True, unique=True)
    token_expires_at = Column(DateTime(timezone=True), nullable=True)

    status = Column(SAEnum(CourseInviteStatus, name="course_invite_status_enum"), nullable=False, server_default=text("'pending'"))

    sent_at = Column(DateTime(timezone=True), nullable=True)
    last_sent_at = Column(DateTime(timezone=True), nullable=True)
    send_count = Column(Integer, nullable=False, server_default=text("0"))

    accepted_at = Column(DateTime(timezone=True), nullable=True)
    revoked_at = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(DateTime(timezone=True), nullable=False, server_default=text("NOW()"))
    updated_at = Column(DateTime(timezone=True), nullable=False, server_default=text("NOW()"))

    __table_args__ = (
        UniqueConstraint("course_id", "invited_email", name="uq_course_invite_course_email"),
        Index("ix_course_invites_course_id", "course_id"),
        Index("ix_course_invites_invited_email", "invited_email"),
        Index("ix_course_invites_status", "status"),
    )

    # optional relationships (لو بتحب)
    # course = relationship("Course", back_populates="invitations")
