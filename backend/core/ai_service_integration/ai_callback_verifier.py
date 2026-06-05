import json
from dataclasses import dataclass
from typing import Any

from fastapi import HTTPException, Request, status

from app.core.config import settings
from app.core.ai_service_integration.ai_protocol import (
    AI_REQUEST_ID_HEADER,
    AI_SIGNATURE_HEADER,
    AI_TIMESTAMP_HEADER,
)
from app.core.ai_service_integration.ai_signature import (
    is_timestamp_valid,
    verify_signature_from_bytes,
    # create_signature_from_bytes,
)


@dataclass(frozen=True)
class VerifiedAICallbackRequest:
    request_id: str
    timestamp: str
    signature: str
    payload: dict[str, Any]
    raw_body: bytes


def _get_required_header(request: Request, header_name: str) -> str:
    value = request.headers.get(header_name)

    if not value:
        print("callback header is empty")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Missing {header_name} header",
        )

    return value


def _extract_ai_callback_headers(request: Request) -> tuple[str, str, str]:
    request_id = _get_required_header(request, AI_REQUEST_ID_HEADER)
    timestamp = _get_required_header(request, AI_TIMESTAMP_HEADER)
    signature = _get_required_header(request, AI_SIGNATURE_HEADER)

    return request_id, timestamp, signature


async def _read_request_body_bytes(request: Request) -> bytes:
    body = await request.body()

    if not body:
        print("callback body is empty")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty callback request body",
        )

    return body


def _validate_callback_timestamp(timestamp: str) -> None:
    # print("Checking timestamp:", timestamp)
    if not is_timestamp_valid(
        timestamp=timestamp,
        allowed_drift_seconds=settings.ai_allowed_timestamp_drift_seconds,
    ):
        # print("❌ Timestamp invalid or expired:", timestamp)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired callback timestamp",
        )


def _validate_callback_signature(
    *,
    request: Request,
    request_id: str,
    timestamp: str,
    signature: str,
    body: bytes,
) -> None:
    # print("=== SIGNATURE DEBUG ===")
    # print("Method:", request.method)
    # print("Path:", request.url.path)
    # print("Request ID:", request_id)
    # print("Timestamp:", timestamp)
    # print("Raw body bytes:", body)
    # print("Provided signature:", signature)

    # expected_signature = create_signature_from_bytes(
    #     secret=settings.ai_shared_secret,
    #     method=request.method,
    #     path=request.url.path,
    #     request_id=request_id,
    #     timestamp=timestamp,
    #     body=body,
    # )

    # print("Expected signature:", expected_signature)
    # print("=======================")

    is_valid = verify_signature_from_bytes(
        secret=settings.ai_shared_secret,
        method=request.method,
        path=request.url.path,
        request_id=request_id,
        timestamp=timestamp,
        body=body,
        received_signature=signature,
    )

    if not is_valid:
        # print("❌ Signature mismatch")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid callback signature",
        )


def _parse_callback_json(body: bytes) -> dict[str, Any]:
    try:
        payload = json.loads(body.decode("utf-8"))
    except Exception as e:

        print("\n=== JSON PARSE ERROR ===")
        print(f"Exception Type: {type(e).__name__}")
        print(f"Exception Message: {e}")
        print(f"Raw Body: {body[:1000]}")
        print("========================\n")

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid callback JSON body",
        )

    if not isinstance(payload, dict):

        print("\n=== INVALID PAYLOAD TYPE ===")
        print(f"Payload Type: {type(payload).__name__}")
        print(f"Payload Value: {payload}")
        print("============================\n")

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Callback body must be a JSON object",
        )

    return payload


async def verify_ai_callback_request(
    request: Request,
) -> VerifiedAICallbackRequest:
    request_id, timestamp, signature = _extract_ai_callback_headers(request)
    raw_body = await _read_request_body_bytes(request)
    # print("=== AI CALLBACK RECEIVED ===")
    # print("Headers:")
    # print("Request-Id:", request.headers.get("Learnova-Request-Id"))
    # print("Timestamp:", request.headers.get("Learnova-Timestamp"))
    # print("Signature:", request.headers.get("Learnova-Signature"))
    # print("Path:", request.url.path)
    # print("============================")

    _validate_callback_timestamp(timestamp)
    _validate_callback_signature(
        request=request,
        request_id=request_id,
        timestamp=timestamp,
        signature=signature,
        body=raw_body,
    )

    payload = _parse_callback_json(raw_body)

    return VerifiedAICallbackRequest(
        request_id=request_id,
        timestamp=timestamp,
        signature=signature,
        payload=payload,
        raw_body=raw_body,
    )