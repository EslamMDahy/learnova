from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.core.deps import get_current_user

from . import service
from .schemas import (
    TopicCreateRequest,
    TopicCreateResponse,
    TopicUpdateRequest,
    TopicUpdateResponse,
    TopicListResponse,
    TopicGetResponse, 
    TopicReorderRequest, 
    TopicReorderResponse)

router = APIRouter(
    prefix="/courses/{course_id}/modules/{module_id}/materials/{material_id}/topics",
    tags=["Topics"],
)


@router.post("", response_model=TopicCreateResponse, status_code=status.HTTP_201_CREATED)
def create_topic(
    course_id: int,
    module_id: int,
    material_id: int,
    payload: TopicCreateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.create_topic(
        course_id=course_id,
        module_id=module_id,
        material_id=material_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.get("", response_model=TopicListResponse, status_code=status.HTTP_200_OK)
def list_material_topics(
    course_id: int,
    module_id: int,
    material_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.list_material_topics(
        course_id=course_id,
        module_id=module_id,
        material_id=material_id,
        db=db,
        current_user=current_user,)

@router.get("/{topic_id}", response_model=TopicGetResponse, status_code=status.HTTP_200_OK)
def get_topic(
    course_id: int,
    module_id: int,
    material_id: int,
    topic_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.get_topic(
        course_id=course_id,
        module_id=module_id,
        material_id=material_id,
        topic_id=topic_id,
        db=db,
        current_user=current_user,)

@router.patch("/{topic_id}/update", response_model=TopicUpdateResponse, status_code=status.HTTP_200_OK)
def update_topic(
    course_id: int,
    module_id: int,
    material_id: int,
    topic_id: int,
    payload: TopicUpdateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.update_topic(
        course_id=course_id,
        module_id=module_id,
        material_id=material_id,
        topic_id=topic_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.patch("/reorder", response_model=TopicReorderResponse, status_code=status.HTTP_200_OK)
def reorder_topics(
    course_id: int,
    module_id: int,
    material_id: int,
    payload: TopicReorderRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.reorder_topics(
        course_id=course_id,
        module_id=module_id,
        material_id=material_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.delete("/{topic_id}/delete", status_code=status.HTTP_204_NO_CONTENT)
def delete_topic(
    course_id: int,
    module_id: int,
    material_id: int,
    topic_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    service.delete_topic(
        course_id=course_id,
        module_id=module_id,
        material_id=material_id,
        topic_id=topic_id,
        db=db,
        current_user=current_user,)
    

