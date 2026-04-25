from __future__ import annotations

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.core.deps import get_current_user

from . import service
from .schemas import (ExamCreateRequest,
                      ExamResponse,
                      ExamAddQuestionsRequest,
                      ExamAddQuestionsResponse,
                      ExamListResponse,
                      ExamDetailsResponse,)


router = APIRouter(
    prefix="/courses/{course_id}/exams",
    tags=["Exams"],
)


@router.post("", response_model=ExamResponse, status_code=status.HTTP_201_CREATED,)
def create_exam_endpoint(
    course_id: int,
    payload: ExamCreateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.create_exam(
        course_id=course_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.post("/{exam_id}/questions",  response_model=ExamAddQuestionsResponse, status_code=status.HTTP_201_CREATED,)
def add_questions_to_exam_endpoint(
    course_id: int,
    exam_id: int,
    payload: ExamAddQuestionsRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.add_questions_to_exam(
        course_id=course_id,
        exam_id=exam_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.get("", response_model=ExamListResponse,)
def list_exams_endpoint(
    course_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.list_exams(
        course_id=course_id,
        db=db,
        current_user=current_user,)

@router.get("/{exam_id}", response_model=ExamDetailsResponse,)
def get_exam_endpoint(
    course_id: int,
    exam_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.get_exam(
        course_id=course_id,
        exam_id=exam_id,
        db=db,
        current_user=current_user,)