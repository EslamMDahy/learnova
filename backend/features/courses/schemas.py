from __future__ import annotations

from enum import Enum
from typing import Optional, List
from pydantic import BaseModel, Field, ConfigDict, model_validator
from datetime import datetime
from app.models.enums import CourseStatus



class CourseType(str, Enum):
    individual = "individual"
    organization = "organization"

class CourseVisibilityLevel(str, Enum):
    private = "private"
    public = "public"
    unlisted = "unlisted"

class CourseInviteStatus(str, Enum):
    pending = "pending"
    accepted = "accepted"
    revoked = "revoked"
    expired = "expired"




class CourseCreateRequest(BaseModel):
    course_type: CourseType = Field(..., description="organization | individual")
    organization_id: Optional[int] = Field(default=None, description="Required if course_type=organization")

    title: str = Field(..., min_length=1, max_length=255)
    course_code: Optional[str] = Field(default=None, max_length=50, description="Optional course code shown in UI")
    description: Optional[str] = None

    is_open_for_enrollment: bool
    visibility_level: CourseVisibilityLevel
    requires_enrollment_approval: bool = False

    # learning_outcomes: Optional[list[str]] = None
    tags: Optional[list[str]] = None
    category: Optional[str] = Field(default=None, max_length=100)
    status: Optional[CourseStatus] = Field(
        default=None,
        description="draft | published | archived"
    )

    model_config = ConfigDict(extra="forbid")

    @model_validator(mode="after")
    def validate_org_rules(self):
        if self.course_type == CourseType.organization and not self.organization_id:
            raise ValueError("organization_id is required when course_type=organization")
        if self.course_type == CourseType.individual and self.organization_id is not None:
            raise ValueError("organization_id must be null when course_type=individual")
        return self

class CourseCreateResponse(BaseModel):
    id: int
    title: str
    course_code: Optional[str] = None
    course_type: CourseType
    organization_id: Optional[int]
    is_open_for_enrollment: bool
    visibility_level: CourseVisibilityLevel
    requires_enrollment_approval: bool

    # keep parity with DB model
    status: CourseStatus
    published_at: Optional[datetime] = None

    model_config = ConfigDict(extra="forbid", use_enum_values=True)




class CourseInvitesUploadResponse(BaseModel):
    course_id: int

    total_rows: int = Field(..., ge=0, description="Total rows read from the Excel sheet (excluding header if any)")
    extracted_emails: int = Field(..., ge=0, description="How many email-like values were extracted")
    inserted: int = Field(..., ge=0, description="How many new invitations were created")
    skipped_existing: int = Field(..., ge=0, description="How many were skipped because (course_id, invited_email) already exists")
    invalid_emails: int = Field(..., ge=0, description="How many values were rejected as invalid emails")

    # token_expires_at: datetime = Field(..., description="Expiration timestamp used for newly created invitations (UTC)")

    # useful for UI/debugging without returning huge lists
    sample_invalid_emails: list[str] = Field(default_factory=list, max_length=20)
    sample_existing_emails: list[str] = Field(default_factory=list, max_length=20)

    model_config = ConfigDict(extra="forbid")




class CourseInvitesSendRequest(BaseModel):
    # لو موجود => resend لواحد معين
    email: Optional[str] = Field(default=None, max_length=320, description="If provided, send invitation only to this email")

    # افتراضيًا هنرسل pending + expired
    include_expired: bool = Field(default=True, description="If true, also send to expired invitations by rotating token")

    # TODO لاحقًا للrate limiting override
    force: bool = Field(default=False, description="Future use: bypass rate limiting (admin/instructor)")

    model_config = ConfigDict(extra="forbid")

class CourseInvitesSendResponse(BaseModel):
    course_id: int

    # كم invite اتعمل له إرسال (نجح)
    sent: int = Field(..., ge=0)

    # كان فيه invites مش eligible (accepted/revoked) أو مش موجودة في حالة email واحدة
    skipped_not_eligible: int = Field(..., ge=0)

    # في حالة حصل fails أثناء الإرسال (SMTP… إلخ)
    failed: int = Field(..., ge=0)

    # معلومات مساعدة للـ UI
    target_email: Optional[str] = None
    attempted: int = Field(..., ge=0)

    # آخر وقت إرسال
    last_sent_at: Optional[datetime] = None

    # samples للديباج/الواجهة
    sample_failed_emails: list[str] = Field(default_factory=list, max_length=20)
    sample_skipped_emails: list[str] = Field(default_factory=list, max_length=20)

    model_config = ConfigDict(extra="forbid")




class CourseInviteAcceptRequest(BaseModel):
    token: str = Field(..., min_length=10, max_length=4096, description="Raw invitation token from email link")
    model_config = ConfigDict(extra="forbid")

class CourseInviteAcceptResponse(BaseModel):
    message: str
    course_id: int
    enrollment_id: int | None = None
    enrolled: bool = True
    accepted_at: datetime | None = None

    model_config = ConfigDict(extra="forbid")


class MyCourseItem(BaseModel):
    id: int
    title: str

    course_code: Optional[str] = None

    course_type: str  # أو CourseType
    organization_id: Optional[int] = None

    is_open_for_enrollment: bool
    visibility_level: str  # أو CourseVisibilityLevel
    status: str

    # cover_image_url: Optional[str] = None
    # banner_image_url: Optional[str] = None
    category: Optional[str] = None

    created_by: int
    created_at: datetime
    updated_at: datetime

    # Useful counts for dashboard (اختياري، لو مش هتجيبهم دلوقتي خليهم None)
    enrollment_count: Optional[int] = None
    pending_invites: Optional[int] = None

    model_config = ConfigDict(extra="forbid")

class MyCoursesResponse(BaseModel):
    items: list[MyCourseItem] = Field(default_factory=list)
    total: int = 0

    model_config = ConfigDict(extra="forbid")




class CourseInvitationItem(BaseModel):
    id: int
    course_id: int
    created_by: int
    invited_email: str
    invited_user_id: Optional[int]
    status: CourseInviteStatus

    token_expires_at: datetime
    sent_at: Optional[datetime]
    last_sent_at: Optional[datetime]
    send_count: int
    accepted_at: Optional[datetime]
    revoked_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime

    invited_user_exists: bool  # helper للفرونت

    model_config = ConfigDict(extra="forbid")

class CourseInvitationsListResponse(BaseModel):
    course_id: int
    total: int
    items: List[CourseInvitationItem]

    model_config = ConfigDict(extra="forbid")




