from __future__ import annotations

import json
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any

from sqlalchemy import text
from sqlalchemy.orm import Session


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def generate_ai_request_id(operation_type: str) -> str:
    """
    Generate a compact request ID prefixed by operation type.
    Example: question_generation_a1b2c3d4
    """
    return f"{operation_type}_{secrets.token_hex(4)}"


def create_ai_request_log(
    db: Session,
    *,
    request_id: str,
    course_id: int | None,
    operation_type: str,
    http_method: str,
    target_endpoint: str,
    request_payload: dict[str, Any],
    expires_at: datetime | None,
    primary_entity_type: str | None = None,
    primary_entity_id: int | None = None,
    status: str = "pending",
) -> None:
    query = text("""
        INSERT INTO ai_request_logs (
            request_id,
            course_id,
            operation_type,
            http_method,
            target_endpoint,
            request_payload,
            status,
            expires_at,
            primary_entity_type,
            primary_entity_id,
            created_at,
            updated_at
        )
        VALUES (
            :request_id,
            :course_id,
            :operation_type,
            :http_method,
            :target_endpoint,
            CAST(:request_payload AS jsonb),
            :status,
            :expires_at,
            :primary_entity_type,
            :primary_entity_id,
            NOW(),
            NOW()
        )
    """)

    db.execute(
        query,
        {
            "request_id": request_id,
            "course_id": course_id,
            "operation_type": operation_type,
            "http_method": http_method.upper(),
            "target_endpoint": target_endpoint,
            "request_payload": json.dumps(request_payload, ensure_ascii=False),
            "status": status,
            "expires_at": expires_at,
            "primary_entity_type": primary_entity_type,
            "primary_entity_id": primary_entity_id,
        },
    )


def mark_ai_request_sent(
    db: Session,
    *,
    request_id: str,
) -> None:
    query = text("""
        UPDATE ai_request_logs
        SET
            status = 'sent',
            sent_at = NOW(),
            updated_at = NOW()
        WHERE request_id = :request_id
    """)

    db.execute(query, {"request_id": request_id})


def mark_ai_request_failed(
    db: Session,
    *,
    request_id: str,
    error_message: str,
) -> None:
    query = text("""
        UPDATE ai_request_logs
        SET
            status = 'failed',
            error_message = :error_message,
            last_error_at = NOW(),
            updated_at = NOW()
        WHERE request_id = :request_id
    """)

    db.execute(
        query,
        {
            "request_id": request_id,
            "error_message": error_message,
        },
    )


def mark_ai_callback_received(
    db: Session,
    *,
    request_id: str,
    response_payload: dict[str, Any],
) -> None:
    query = text("""
        UPDATE ai_request_logs
        SET
            status = 'callback_received',
            response_payload = CAST(:response_payload AS jsonb),
            callback_received_at = NOW(),
            updated_at = NOW()
        WHERE request_id = :request_id
    """)

    db.execute(
        query,
        {
            "request_id": request_id,
            "response_payload": json.dumps(response_payload, ensure_ascii=False),
        },
    )


def mark_ai_request_completed(
    db: Session,
    *,
    request_id: str,
    response_payload: dict[str, Any] | None = None,
) -> None:
    if response_payload is None:
        query = text("""
            UPDATE ai_request_logs
            SET
                status = 'completed',
                completed_at = NOW(),
                updated_at = NOW()
            WHERE request_id = :request_id
        """)

        db.execute(query, {"request_id": request_id})
        return

    query = text("""
        UPDATE ai_request_logs
        SET
            status = 'completed',
            response_payload = CAST(:response_payload AS jsonb),
            completed_at = NOW(),
            updated_at = NOW()
        WHERE request_id = :request_id
    """)

    db.execute(
        query,
        {
            "request_id": request_id,
            "response_payload": json.dumps(response_payload, ensure_ascii=False),
        },
    )


def mark_ai_request_invalid_callback(
    db: Session,
    *,
    request_id: str,
    error_message: str,
) -> None:
    query = text("""
        UPDATE ai_request_logs
        SET
            status = 'invalid_callback',
            error_message = :error_message,
            last_error_at = NOW(),
            updated_at = NOW()
        WHERE request_id = :request_id
    """)

    db.execute(
        query,
        {
            "request_id": request_id,
            "error_message": error_message,
        },
    )


def mark_ai_request_expired(
    db: Session,
    *,
    request_id: str,
) -> None:
    query = text("""
        UPDATE ai_request_logs
        SET
            status = 'expired',
            updated_at = NOW()
        WHERE request_id = :request_id
    """)

    db.execute(query, {"request_id": request_id})


def get_ai_request_log_by_request_id(
    db: Session,
    *,
    request_id: str,
) -> dict[str, Any] | None:
    query = text("""
        SELECT
            id,
            request_id,
            course_id,
            operation_type,
            http_method,
            target_endpoint,
            request_payload,
            response_payload,
            status,
            error_message,
            expires_at,
            primary_entity_type,
            primary_entity_id,
            created_at,
            sent_at,
            callback_received_at,
            completed_at,
            last_error_at,
            updated_at
        FROM ai_request_logs
        WHERE request_id = :request_id
        LIMIT 1
    """)

    row = db.execute(query, {"request_id": request_id}).mappings().first()
    return dict(row) if row else None


def is_ai_request_expired(
    db: Session,
    *,
    request_id: str,
) -> bool:
    query = text("""
        SELECT
            CASE
                WHEN expires_at IS NULL THEN FALSE
                WHEN NOW() > expires_at THEN TRUE
                ELSE FALSE
            END AS is_expired
        FROM ai_request_logs
        WHERE request_id = :request_id
        LIMIT 1
    """)

    row = db.execute(query, {"request_id": request_id}).mappings().first()

    if row is None:
        return False

    return bool(row["is_expired"])


def build_ai_request_expiry(
    *,
    timeout_seconds: int,
) -> datetime:
    return utc_now() + timedelta(seconds=timeout_seconds)