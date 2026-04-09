from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.core.deps import get_current_user

from . import service
from .schemas import (QuestionCreateRequest, 
                      QuestionCreateResponse,
                      TopicQuestionListResponse,
                      MaterialQuestionListResponse,
                      ModuleQuestionListResponse,
                      CourseQuestionListResponse,)

router = APIRouter(prefix="/courses/{course_id}", tags=["Questions"],)


@router.post("/questions", response_model=QuestionCreateResponse, status_code=status.HTTP_201_CREATED)
def create_question(
    course_id: int,
    payload: QuestionCreateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.create_question(
        course_id=course_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.get("/modules/{module_id}/materials/{material_id}/topics/{topic_id}/questions", response_model=TopicQuestionListResponse,status_code=status.HTTP_200_OK,)
def list_topic_questions(
    course_id: int,
    module_id: int,
    material_id: int,
    topic_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.list_topic_questions(
        course_id=course_id,
        module_id=module_id,
        material_id=material_id,
        topic_id=topic_id,
        db=db,
        current_user=current_user,)

@router.get("/modules/{module_id}/materials/{material_id}/questions", response_model=MaterialQuestionListResponse,status_code=status.HTTP_200_OK,)
def list_material_questions(
    course_id: int,
    module_id: int,
    material_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.list_material_questions(
        course_id=course_id,
        module_id=module_id,
        material_id=material_id,
        db=db,
        current_user=current_user,)

@router.get("/modules/{module_id}/questions", response_model=ModuleQuestionListResponse, status_code=status.HTTP_200_OK,)
def list_module_questions(
    course_id: int,
    module_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.list_module_questions(
        course_id=course_id,
        module_id=module_id,
        db=db,
        current_user=current_user,)


@router.get("/questions", response_model=CourseQuestionListResponse, status_code=status.HTTP_200_OK,)
def list_course_questions(
    course_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.list_course_questions(
        course_id=course_id,
        db=db,
        current_user=current_user,)