from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.core.deps import get_current_user

from . import service
from .schemas import (
    LearningOutcomeCreateRequest,
    LearningOutcomeCreateResponse,
    LearningOutcomeListResponse,
    LearningOutcomeGetResponse,
    LearningOutcomeUpdateRequest,
    LearningOutcomeUpdateResponse,
)

router = APIRouter(prefix="/courses/{course_id}/learning-outcomes", tags=["Learning Outcomes"],)


@router.post("", response_model=LearningOutcomeCreateResponse, status_code=status.HTTP_201_CREATED)
def create_learning_outcome(
    course_id: int,
    payload: LearningOutcomeCreateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.create_learning_outcome(
        course_id=course_id,
        payload=payload,
        db=db,
        current_user=current_user,)


@router.get("", response_model=LearningOutcomeListResponse, status_code=status.HTTP_200_OK)
def list_learning_outcomes(
    course_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.list_learning_outcomes(
        course_id=course_id,
        db=db,
        current_user=current_user,)


@router.get("/{learning_outcome_id}", response_model=LearningOutcomeGetResponse, status_code=status.HTTP_200_OK)
def get_learning_outcome(
    course_id: int,
    learning_outcome_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.get_learning_outcome(
        course_id=course_id,
        learning_outcome_id=learning_outcome_id,
        db=db,
        current_user=current_user,)


@router.patch("/{learning_outcome_id}/update", response_model=LearningOutcomeUpdateResponse, status_code=status.HTTP_200_OK)
def update_learning_outcome(
    course_id: int,
    learning_outcome_id: int,
    payload: LearningOutcomeUpdateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.update_learning_outcome(
        course_id=course_id,
        learning_outcome_id=learning_outcome_id,
        payload=payload,
        db=db,
        current_user=current_user,)


@router.delete("/{learning_outcome_id}/delete", status_code=status.HTTP_204_NO_CONTENT)
def delete_learning_outcome(
    course_id: int,
    learning_outcome_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    service.delete_learning_outcome(
        course_id=course_id,
        learning_outcome_id=learning_outcome_id,
        db=db,
        current_user=current_user,)