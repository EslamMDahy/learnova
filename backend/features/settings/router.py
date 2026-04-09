from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.core.deps import get_current_user
from app.db.session import get_db

from . import service
from .schemas import (
    UpdateProfileRequest,
    UpdateProfileResponse,
    CreateAvatarUploadUrlRequest,
    CreateAvatarUploadUrlResponse,
    ConfirmAvatarUploadRequest,
    ConfirmAvatarUploadResponse,
    ChangePasswordRequest,
    ChangePasswordResponse,
    RequestDeleteAccountRequest,
    RequestDeleteAccountResponse,
    ConfirmDeleteAccountRequest,
    ConfirmDeleteAccountResponse,
    UserPreferencesOut,
    UpdatePreferencesRequest,
)


router = APIRouter(prefix="/settings", tags=["Settings"])


@router.patch("/profile", response_model=UpdateProfileResponse)
def update_profile(
    payload: UpdateProfileRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),):
    return service.update_profile(
        payload=payload, 
        db=db, 
        current_user=current_user)

@router.post("/avatar/upload-url", response_model=CreateAvatarUploadUrlResponse)
def create_avatar_upload_url(
    payload: CreateAvatarUploadUrlRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),):
    return service.create_avatar_upload_url(
        payload=payload,
        db=db,
        current_user=current_user,)

@router.post("/avatar/confirm", response_model=ConfirmAvatarUploadResponse)
def confirm_avatar_upload(
    payload: ConfirmAvatarUploadRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),):
    return service.confirm_avatar_upload(
        payload=payload,
        db=db,
        current_user=current_user,)

@router.patch("/password", response_model=ChangePasswordResponse)
def change_password(
    payload: ChangePasswordRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),):
    return service.change_password(
        payload=payload, 
        db=db, 
        current_user=current_user)


@router.post("/delete/request", response_model=RequestDeleteAccountResponse)
def request_delete_account(
    payload: RequestDeleteAccountRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),):
    return service.request_delete_account(
        payload=payload, 
        db=db, 
        current_user=current_user)


@router.delete("/delete/confirm", response_model=ConfirmDeleteAccountResponse)
def confirm_delete_account(
    payload: ConfirmDeleteAccountRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),):
    return service.confirm_delete_account(
        payload=payload, 
        db=db, 
        current_user=current_user)


@router.get("/preferences", response_model=UserPreferencesOut)
def get_preferences(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    uid = int(current_user["id"])

    row = db.execute(
        text(
            """
            SELECT
              email_notifications,
              assignment_alerts,
              course_updates,
              announcement_notifications,
              grading_notifications,
              deadline_reminders,
              theme_mode,
              profile_visibility,
              show_online_status
            FROM user_preferences
            WHERE user_id = :uid
            """
        ),
        {"uid": uid},
    ).first()

    if not row:
        return UserPreferencesOut()  # defaults من الـ schema

    (
        email_notifications,
        assignment_alerts,
        course_updates,
        announcement_notifications,
        grading_notifications,
        deadline_reminders,
        theme_mode,
        profile_visibility,
        show_online_status,
    ) = row

    return UserPreferencesOut(
        email_notifications=bool(email_notifications),
        assignment_alerts=bool(assignment_alerts),
        course_updates=bool(course_updates),
        announcement_notifications=bool(announcement_notifications),
        grading_notifications=bool(grading_notifications),
        deadline_reminders=bool(deadline_reminders),
        theme_mode=theme_mode or "light",
        profile_visibility=profile_visibility or "private",
        show_online_status=bool(show_online_status),
    )


@router.patch("/preferences", response_model=UserPreferencesOut)
def update_preferences(
    payload: UpdatePreferencesRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    uid = int(current_user["id"])

    # Upsert
    exists = db.execute(
        text("SELECT 1 FROM user_preferences WHERE user_id = :uid"),
        {"uid": uid},
    ).first()

    if not exists:
        db.execute(
            text(
                """
                INSERT INTO user_preferences (
                  user_id,
                  email_notifications,
                  assignment_alerts,
                  course_updates,
                  announcement_notifications,
                  grading_notifications,
                  deadline_reminders,
                  theme_mode,
                  profile_visibility,
                  show_online_status,
                  created_at,
                  updated_at
                )
                VALUES (
                  :uid,
                  :email_notifications,
                  :assignment_alerts,
                  :course_updates,
                  :announcement_notifications,
                  :grading_notifications,
                  :deadline_reminders,
                  :theme_mode,
                  :profile_visibility,
                  :show_online_status,
                  CURRENT_TIMESTAMP,
                  CURRENT_TIMESTAMP
                )
                """
            ),
            {
                "uid": uid,
                "email_notifications": payload.email_notifications,
                "assignment_alerts": payload.assignment_alerts,
                "course_updates": payload.course_updates,
                "announcement_notifications": payload.announcement_notifications,
                "grading_notifications": payload.grading_notifications,
                "deadline_reminders": payload.deadline_reminders,
                "theme_mode": payload.theme_mode,
                "profile_visibility": payload.profile_visibility,
                "show_online_status": payload.show_online_status,
            },
        )
    else:
        db.execute(
            text(
                """
                UPDATE user_preferences
                SET
                  email_notifications = :email_notifications,
                  assignment_alerts = :assignment_alerts,
                  course_updates = :course_updates,
                  announcement_notifications = :announcement_notifications,
                  grading_notifications = :grading_notifications,
                  deadline_reminders = :deadline_reminders,
                  theme_mode = :theme_mode,
                  profile_visibility = :profile_visibility,
                  show_online_status = :show_online_status,
                  updated_at = CURRENT_TIMESTAMP
                WHERE user_id = :uid
                """
            ),
            {
                "uid": uid,
                "email_notifications": payload.email_notifications,
                "assignment_alerts": payload.assignment_alerts,
                "course_updates": payload.course_updates,
                "announcement_notifications": payload.announcement_notifications,
                "grading_notifications": payload.grading_notifications,
                "deadline_reminders": payload.deadline_reminders,
                "theme_mode": payload.theme_mode,
                "profile_visibility": payload.profile_visibility,
                "show_online_status": payload.show_online_status,
            },
        )

    db.commit()
    return UserPreferencesOut(**payload.model_dump())
