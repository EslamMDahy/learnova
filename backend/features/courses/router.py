from fastapi import APIRouter, Depends, File, UploadFile, Form, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.core.deps import get_current_user
from . import service
from .schemas import (CourseCreateRequest,
                      CourseCreateResponse,
                      CourseInvitesUploadResponse,
                      CourseInvitesSendRequest, 
                      CourseInvitesSendResponse,
                      CourseInviteAcceptRequest,
                      CourseInviteAcceptResponse,
                      MyCoursesResponse,
                      CourseInvitationsListResponse,
                      CourseInviteStatus)

router = APIRouter(prefix="/courses", tags=["Courses"])

@router.post("", response_model=CourseCreateResponse, status_code=status.HTTP_201_CREATED)
def create_course(
    payload: CourseCreateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.create_course(
        payload=payload, 
        db=db, 
        current_user=current_user)

@router.post("/{course_id}/invitations/upload", response_model=CourseInvitesUploadResponse,
              status_code=status.HTTP_201_CREATED,)
def upload_course_invitations_excel(
    course_id: int,
    file: UploadFile = File(..., description="Excel file (.xlsx) containing invited emails"),
    # optional: لو الفرونت محتاج يبعت حاجات زيادة مع الملف (مش ضروري غالبًا)
    sheet_name: str | None = Form(default=None, description="Optional Excel sheet name"),
    email_column: str = Form(default="email", description="Column name that contains emails"),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.upload_course_invitations_excel(
        course_id=course_id,
        file=file,
        sheet_name=sheet_name,
        email_column=email_column,
        db=db,
        current_user=current_user,)

@router.post("/{course_id}/invitations/send",response_model=CourseInvitesSendResponse,status_code=status.HTTP_200_OK,)
def send_course_invitations(
    course_id: int,
    payload: CourseInvitesSendRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.send_course_invitations(
        course_id=course_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.post("/invitations/accept",response_model=CourseInviteAcceptResponse,status_code=status.HTTP_200_OK,)
def accept_course_invitation(
    payload: CourseInviteAcceptRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):# لو مش logged in => 401
    return service.accept_course_invitation(payload=payload, db=db, current_user=current_user)

@router.get("/my", response_model=MyCoursesResponse, status_code=status.HTTP_200_OK,)
def get_my_courses(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.get_my_courses(db=db, current_user=current_user)

@router.get("/{course_id}/invitations", response_model=CourseInvitationsListResponse)
def list_course_invitations(
    course_id: int,
    limit: int = 200,
    offset: int = 0,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.list_course_invitations(
        course_id=course_id,
        limit=limit,
        offset=offset,
        db=db,
        current_user=current_user,)
