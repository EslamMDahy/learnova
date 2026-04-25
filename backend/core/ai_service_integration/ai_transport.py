from __future__ import annotations

from typing import Any

import httpx
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.ai_service_integration.ai_protocol import (
    DEFAULT_HTTP_METHOD,
    build_ai_request_envelope,
    build_ai_request_headers,
    serialize_json_for_signing,
)
from app.core.ai_service_integration.ai_request_tracking import (
    build_ai_request_expiry,
    create_ai_request_log,
    generate_ai_request_id,
    mark_ai_request_failed,
    mark_ai_request_sent,
)
from app.core.ai_service_integration.ai_signature import (
    create_signature_from_bytes,
    get_current_timestamp,
)


def send_ai_request(
    db: Session,
    *,
    operation_type: str,
    endpoint_path: str,
    body: dict[str, Any],
    course_id: int | None = None,
    primary_entity_type: str | None = None,
    primary_entity_id: int | None = None,
    http_method: str = DEFAULT_HTTP_METHOD,
) -> str:
    request_id = generate_ai_request_id(operation_type)
    timestamp = get_current_timestamp()
    expires_at = build_ai_request_expiry(
        timeout_seconds=settings.ai_request_timeout_seconds,
    )

    normalized_method = http_method.upper()
    normalized_endpoint_path = _normalize_endpoint_path(endpoint_path)

    envelope = build_ai_request_envelope(
        request_id=request_id,
        timestamp=timestamp,
        operation_type=operation_type,
        course_id=course_id,
        body=body,
    )

    serialized_envelope = serialize_json_for_signing(envelope)

    signature = create_signature_from_bytes(
        secret=settings.ai_shared_secret,
        method=normalized_method,
        path=normalized_endpoint_path,
        request_id=request_id,
        timestamp=timestamp,
        body=serialized_envelope,
    )

    headers = build_ai_request_headers(
        request_id=request_id,
        timestamp=timestamp,
        signature=signature,
    )

    create_ai_request_log(
        db,
        request_id=request_id,
        course_id=course_id,
        operation_type=operation_type,
        http_method=normalized_method,
        target_endpoint=normalized_endpoint_path,
        request_payload=envelope,
        expires_at=expires_at,
        primary_entity_type=primary_entity_type,
        primary_entity_id=primary_entity_id,
    )

    try:
        with httpx.Client(
            base_url=settings.ai_service_base_url,
            timeout=settings.ai_request_timeout_seconds,
        ) as client:
            response = client.request(
                method=normalized_method,
                url=normalized_endpoint_path,
                content=serialized_envelope,
                headers=headers,
            )

        response.raise_for_status()

        mark_ai_request_sent(
            db,
            request_id=request_id,
        )

        return request_id

    except httpx.HTTPError as exc:
        mark_ai_request_failed(
            db,
            request_id=request_id,
            error_message=str(exc),
        )
        raise


def _normalize_endpoint_path(endpoint_path: str) -> str:
    if not endpoint_path:
        raise ValueError("endpoint_path must not be empty")

    endpoint_path = endpoint_path.strip()

    if not endpoint_path:
        raise ValueError("endpoint_path must not be empty")

    if not endpoint_path.startswith("/"):
        endpoint_path = f"/{endpoint_path}"

    return endpoint_path