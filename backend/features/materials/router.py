from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.core.deps import get_current_user

from . import service
from .schemas import (
    MaterialInitUploadRequest,
    MaterialInitUploadResponse,
    MaterialConfirmUploadResponse,
    MaterialListResponse,
    MaterialDownloadUrlResponse,
    MaterialReassignRequest,
    MaterialReassignResponse)

router = APIRouter(tags=["Materials"])


# =========================
# Init upload (nested under course + module)
# =========================
@router.post("/courses/{course_id}/modules/{module_id}/materials/init-upload",
             response_model=MaterialInitUploadResponse,
             status_code=status.HTTP_201_CREATED,)
def init_material_upload(
    course_id: int,
    module_id: int,
    payload: MaterialInitUploadRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.init_material_upload(
        course_id=course_id,
        module_id=module_id,
        payload=payload,
        db=db,
        current_user=current_user,)

# =========================
# Confirm upload (by material id)
# =========================
@router.post("/materials/{material_id}/confirm-upload",
             response_model=MaterialConfirmUploadResponse,
             status_code=status.HTTP_200_OK,)
def confirm_material_upload(
    material_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.confirm_material_upload(
        material_id=material_id,
        db=db,
        current_user=current_user,)

# =========================
# List material metadata
# =========================
@router.get("/courses/{course_id}/modules/{module_id}/materials", 
            response_model=MaterialListResponse)
def list_module_materials(
    course_id: int,
    module_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.list_module_materials(
        course_id=course_id,
        module_id=module_id,
        db=db,
        current_user=current_user,
    )


@router.get("/courses/{course_id}/modules/{module_id}/materials/{material_id}/download-url", 
            response_model=MaterialDownloadUrlResponse,)
def get_material_download_url(
    course_id: int,
    module_id: int,
    material_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.get_material_download_url(
        course_id=course_id,
        module_id=module_id,
        material_id=material_id,
        db=db,
        current_user=current_user,)

@router.patch("/{material_id}/reassign",response_model=MaterialReassignResponse,status_code=status.HTTP_200_OK,)
def reassign_material(
    course_id: int,
    module_id: int,
    material_id: int,
    payload: MaterialReassignRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.reassign_material(
        course_id=course_id,
        module_id=module_id,
        material_id=material_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.delete("/courses/{course_id}/modules/{module_id}/materials/{material_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_material(
    course_id: int,
    module_id: int,
    material_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    service.delete_material(
        course_id=course_id,
        module_id=module_id,
        material_id=material_id,
        db=db,
        current_user=current_user,)