from typing import Optional, Literal
from pydantic import BaseModel, Field

ThemeModeStr = Literal["light", "dark", "system"]
ProfileVisibilityStr = Literal["public", "private", "connections"]
AvatarContentType = Literal["image/png", "image/jpeg", "image/jpg"]


class UpdateProfileRequest(BaseModel):
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None

    # Flutter sends "phone" but DB column is phone_number
    phone: Optional[str] = None

    bio: Optional[str] = None
    # student_id: Optional[str] = None
    # university_email: Optional[str] = None
    language_preference: Optional[str] = None


class UpdateProfileResponse(BaseModel):
    id: int
    full_name: str
    email: str

    phone_number: Optional[str] = None
    bio: Optional[str] = None

    student_id: Optional[str] = None
    university_email: Optional[str] = None
    language_preference: str = "en_US"

    system_role: str


class CreateAvatarUploadUrlRequest(BaseModel):
    content_type: AvatarContentType
    file_size_bytes: Optional[int] = None  # للـvalidation في الـservice (max 5MB)

class CreateAvatarUploadUrlResponse(BaseModel):
    upload_url: str
    path: str
    token: str  # لو الفرونت محتاجه (في بعض طرق الرفع بيستخدم x-signature)
    content_type: str
    max_bytes: int


class ConfirmAvatarUploadRequest(BaseModel):
    # حالياً مش هنستخدمه في المنطق، بس موجود للمستقبل
    uploaded: bool = True
    
class ConfirmAvatarUploadResponse(BaseModel):
    avatar_url: str


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=1)
    new_password: str = Field(min_length=1)


class ChangePasswordResponse(BaseModel):
    message: str
    email_notification_sent: Optional[bool] = None


class RequestDeleteAccountRequest(BaseModel):
    current_password: str = Field(min_length=1)


class RequestDeleteAccountResponse(BaseModel):
    message: str
    email_sent: Optional[bool] = None


class ConfirmDeleteAccountRequest(BaseModel):
    otp: str = Field(min_length=1, max_length=6)


class ConfirmDeleteAccountResponse(BaseModel):
    message: str


class UserPreferencesOut(BaseModel):
    email_notifications: bool = True
    assignment_alerts: bool = True
    course_updates: bool = True
    announcement_notifications: bool = True
    grading_notifications: bool = True
    deadline_reminders: bool = True

    theme_mode: ThemeModeStr = "light"
    profile_visibility: ProfileVisibilityStr = "private"
    show_online_status: bool = True


class UpdatePreferencesRequest(BaseModel):
    email_notifications: bool = True
    assignment_alerts: bool = True
    course_updates: bool = True
    announcement_notifications: bool = True
    grading_notifications: bool = True
    deadline_reminders: bool = True

    theme_mode: ThemeModeStr = "light"
    profile_visibility: ProfileVisibilityStr = "private"
    show_online_status: bool = True
