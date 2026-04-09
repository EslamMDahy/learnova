from datetime import datetime, timezone
from sqlalchemy.orm import Session
from sqlalchemy import text
from fastapi import HTTPException


def get_valid_user_token(
    db: Session,
    *,
    token: str,
    token_type: str,
):
    """
    Fetch a token row from user_tokens and validate it:
    - correct type
    - not used
    - not expired

    Returns: row tuple (id, user_id, token, expires_at, used_at)
    Raises: HTTPException(400) if invalid/expired/used
    """
    row = db.execute(
        text(
            """
            SELECT id, user_id, token, expires_at, used_at
            FROM user_tokens
            WHERE token = :token AND type = :type
            """
        ),
        {"token": token, "type": token_type},
    ).first()

    if not row:
        raise HTTPException(status_code=400, detail="Invalid or expired token")

    token_id, user_id, token_db, expires_at, used_at = row

    if used_at is not None:
        raise HTTPException(status_code=400, detail="Invalid or expired token")

    now = datetime.now(timezone.utc)
    if expires_at <= now:
        raise HTTPException(status_code=400, detail="Invalid or expired token")

    return row


def mark_token_used(db: Session, *, token_id: int) -> None:
    """
    Marks a token as used (one-time token).
    """
    db.execute(
        text("UPDATE user_tokens SET used_at = NOW() WHERE id = :id"),
        {"id": token_id},
    )
