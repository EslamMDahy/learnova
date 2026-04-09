from pydantic import BaseModel, Field, EmailStr
from typing import Optional, List, Literal


class CreateOrganizationRequest(BaseModel):
    name: str = Field(min_length=2, max_length=255)
    description: str = Field(min_length=2, max_length=50)  # جاي من Flutter
    logo_url: Optional[str] = Field(default=None, max_length=512)


class OrganizationOut(BaseModel):
    id: int
    name: str
    description: str
    logo_url: Optional[str] = None
    owner_id: int
    subscription_plan_id: int
    invite_code: str
    subscription_status: str

class CreateOrganizationResponse(BaseModel):
    organization: OrganizationOut


class JoinRequestUser(BaseModel):
    id: int
    org_member_id: int
    full_name: str
    email: EmailStr
    avatar_url: Optional[str] = None
    system_role: str
    status: str

class JoinRequestsResponse(BaseModel):
    count: int
    users: List[JoinRequestUser]



MembershipStatus = Literal["pending", "accepted", "suspended", "declinate"]

class UpdateMemberStatusRequest(BaseModel):
    new_status: MembershipStatus

class UpdateMemberStatusResponse(BaseModel):
    org_member_id: int
    user_id: int
    organization_id: int
    old_status: MembershipStatus
    new_status: MembershipStatus