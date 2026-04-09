from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.core.deps import get_current_user

from .schemas import CreateOrganizationRequest
from .schemas import CreateOrganizationResponse
from .schemas import JoinRequestsResponse
from .schemas import UpdateMemberStatusRequest
from .schemas import UpdateMemberStatusResponse
from . import service

router = APIRouter(prefix="/organizations", tags=["Organizations"])


@router.post("", response_model=CreateOrganizationResponse, status_code=201)
def create_organization(
    payload: CreateOrganizationRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),):
    return service.create_organization(payload, db, current_user)

@router.get("/{organization_id}/join-requests", response_model=JoinRequestsResponse)
def list_join_requests(
    organization_id: int,
    view: str = Query("pending", pattern="^(pending|accepted)$"),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),):
    return service.list_join_requests(
        organization_id=organization_id,
        view=view,
        db=db,
        current_user=current_user,)

@router.patch("/{organization_id}/members/{org_member_id}/status", response_model=UpdateMemberStatusResponse)
def update_member_status(
    organization_id: int,
    org_member_id: int,
    payload: UpdateMemberStatusRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),):
    return service.update_member_status(
        organization_id=organization_id,
        org_member_id=org_member_id,
        new_status=payload.new_status,
        db=db,
        current_user=current_user,)

