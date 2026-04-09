from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.core.deps import get_current_user
from . import service
from .schemas import (ModuleCreateRequest,
                      ModuleCreateResponse,
                      ModuleUpdateRequest,
                      ModuleUpdateResponse,
                      ModuleCopyResponse,
                      ModuleReorderRequest,
                      ModuleReorderResponse,
                      ModuleListResponse)


router = APIRouter(prefix="/courses/{course_id}/modules", tags=["Modules"])


@router.post("", response_model=ModuleCreateResponse, status_code=status.HTTP_201_CREATED)
def create_module(
    course_id: int,
    payload: ModuleCreateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    # course_id is path param now; service should use it instead of reading from payload
    return service.create_module(
        course_id=course_id, 
        payload=payload, 
        db=db, 
        current_user=current_user)

@router.patch("/{module_id}/update", response_model=ModuleUpdateResponse, status_code=status.HTTP_200_OK,)
def update_module(
    course_id: int,
    module_id: int,
    payload: ModuleUpdateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.update_module(
        course_id=course_id,
        module_id=module_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.post("/{module_id}/copy", response_model=ModuleCopyResponse, status_code=status.HTTP_201_CREATED)
def copy_module(
    course_id: int,
    module_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.copy_module(
        target_course_id=course_id,
        source_module_id=module_id,
        db=db,
        current_user=current_user,)

@router.patch("/reorder", response_model=ModuleReorderResponse, status_code=status.HTTP_200_OK,)
def reorder_modules(
    course_id: int,
    payload: ModuleReorderRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.reorder_modules(
        course_id=course_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.get("", response_model=ModuleListResponse,)
def list_course_modules(
    course_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.list_course_modules(
        course_id=course_id,
        db=db,
        current_user=current_user,)

@router.delete("/{module_id}/delete", status_code=status.HTTP_204_NO_CONTENT,)
def delete_module(
    course_id: int,
    module_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    service.delete_module(
        course_id=course_id,
        module_id=module_id,
        db=db,
        current_user=current_user,)