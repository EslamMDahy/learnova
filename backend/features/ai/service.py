from __future__ import annotations

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.ai_service_integration.ai_callback_verifier import (
    VerifiedAICallbackRequest,
)
from app.core.ai_service_integration.ai_request_tracking import (
    get_ai_request_log_by_request_id,
    is_ai_request_expired,
    mark_ai_callback_received,
    mark_ai_request_completed,
    mark_ai_request_expired,
    mark_ai_request_failed,
)

from .handlers import handle_content_structure_generation


_HANDLER_REGISTRY = {
    "content_structure_generation": handle_content_structure_generation,
}


def handle_ai_callback(*, verified_callback: VerifiedAICallbackRequest, db: Session):
    payload = verified_callback.payload
    request_id = verified_callback.request_id

    operation_type = payload.get("operation_type")
    if not operation_type:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing operation_type in callback payload",
        )

    handler = _HANDLER_REGISTRY.get(operation_type)
    if handler is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported operation_type: {operation_type}",
        )

    request_log = get_ai_request_log_by_request_id(
        db,
        request_id=request_id,
    )
    if request_log is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="AI request log not found",
        )

    if request_log["operation_type"] != operation_type:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Callback operation_type does not match request log",
        )

    if is_ai_request_expired(db, request_id=request_id):
        mark_ai_request_expired(db, request_id=request_id)
        db.commit()

        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="AI request has expired",
        )

    current_status = (request_log.get("status") or "").strip().lower()
    if current_status == "completed":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="AI request callback already processed",
        )

    if current_status == "expired":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="AI request has expired",
        )

    mark_ai_callback_received(
        db,
        request_id=request_id,
        response_payload=payload,
    )
    db.flush()

    try:
        result = handler(
            db=db,
            verified_callback=verified_callback,
            request_log=request_log,
        )

        mark_ai_request_completed(
            db,
            request_id=request_id,
            response_payload=payload,
        )
        db.commit()

        return {
            "message": "AI callback processed successfully",
            "request_id": request_id,
            "operation_type": operation_type,
            "status": "completed",
            "result": result,
        }

    except HTTPException:
        db.rollback()
        raise

    except Exception as exc:
        db.rollback()

        mark_ai_request_failed(
            db,
            request_id=request_id,
            error_message=str(exc),
        )
        db.commit()

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to process AI callback",
        ) from exc