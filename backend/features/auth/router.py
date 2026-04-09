from fastapi import APIRouter, Response, Request, Depends, Query
from sqlalchemy.orm import Session
from fastapi import HTTPException

from app.db.session import get_db
from app.core.deps import get_current_user

from .schemas import RegisterRequest
from .schemas import LoginRequest
from .schemas import ForgetPasswordRequest
from .schemas import ForgetPasswordResponse
from .schemas import ResetPasswordRequest
from .schemas import ResetPasswordResponse
from .schemas import SendVerificationEmailRequest
from .schemas import SendVerificationEmailResponse
from .schemas import CheckEmailVerifiedRequest
from .schemas import CheckEmailVerifiedResponse
from . import service

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/register", status_code=201)
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    return service.register_user(payload, db)

@router.post("/send-verification-email", response_model=SendVerificationEmailResponse)
def send_verification_email(payload: SendVerificationEmailRequest, db: Session = Depends(get_db)):
    return service.send_verification_email(payload, db)

@router.get("/verify-email")
def verify_email(token: str = Query(...), db: Session = Depends(get_db)):
    return service.verify_email_token(token, db)

@router.post("/check-email-verified", response_model=CheckEmailVerifiedResponse)
def check_email_verified(payload: CheckEmailVerifiedRequest, db: Session = Depends(get_db)):
    """
    Check if a user's email is verified without requiring authentication.
    Used by the 'I've Verified, Continue' button on the verify-email-sent screen.
    Returns { is_verified: false } for unknown emails to avoid user enumeration.
    """
    return service.check_email_verified(payload, db)

@router.post("/login")
def login(payload: LoginRequest, response: Response, db: Session = Depends(get_db)):
    return service.login_user(payload, db, response=response)

@router.get("/me")
def me(user=Depends(get_current_user)):
    return {"user": user}

@router.post("/refresh")
def refresh_token(request: Request, response: Response, db: Session = Depends(get_db)):
    return service.refresh_access_token(db=db, request=request, response=response)

@router.post("/logout")
def logout(request: Request, response: Response, db: Session = Depends(get_db)):
    return service.logout_user(db=db, request=request, response=response)

@router.post("/forgot-password", response_model=ForgetPasswordResponse)
def forget_password(payload: ForgetPasswordRequest, db: Session = Depends(get_db)):
    return service.forget_password_request(payload, db)

@router.post("/reset-password", response_model=ResetPasswordResponse)
def reset_password(payload: ResetPasswordRequest, db: Session = Depends(get_db)):
    return service.reset_password(payload, db)