from typing import Optional
from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    full_name: str
    email: EmailStr
    password: str = Field(min_length=8)
    system_role: Optional[str] = None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6)
    remember_me: bool = False


class SendVerificationEmailRequest(BaseModel):
    email: EmailStr

class SendVerificationEmailResponse(BaseModel):
    message: str
    email_sent: bool

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    full_name: str
    email: str


class ForgetPasswordRequest(BaseModel):
    email: EmailStr

class ForgetPasswordResponse(BaseModel):
    message: str


class ResetPasswordRequest(BaseModel):
    token: str = Field(..., min_length=10)
    new_password: str = Field(..., min_length=6)

class ResetPasswordResponse(BaseModel):
    message: str


class CheckEmailVerifiedRequest(BaseModel):
    email: EmailStr

class CheckEmailVerifiedResponse(BaseModel):
    is_verified: bool