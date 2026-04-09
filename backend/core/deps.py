from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.core.config import settings
from app.core.jwt import decode_access_token
from app.core.supabase_client import supabase
from app.db.session import get_db

bearer_scheme = HTTPBearer(auto_error=False)

def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
):
    # 1) لازم يبقى فيه Authorization header
    if not creds or creds.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Not authenticated")

    token = creds.credentials

    # 2) فك التوكين وتحقق منه
    payload = decode_access_token(token)

    user_id = payload.get("sub")
    last_password_change = payload.get("last_password_change")

    if user_id is None:
        raise HTTPException(status_code=401, detail="Invalid token payload")

    try:
        user_id_int = int(user_id)
    except (TypeError, ValueError):
        raise HTTPException(status_code=401, detail="Invalid token payload")

    # 3) هات اليوزر من DB
    row = db.execute(
        text(
            """
            SELECT id, email, full_name, system_role, is_email_verified, last_password_change, avatar_key, updated_at
            FROM users
            WHERE id = :id
            """
        ),
        {"id": user_id_int},
    ).first()

    if not row:
        raise HTTPException(status_code=401, detail="User not found")

    uid, email, full_name, system_role, is_verified, last_password_change_db, avatar_key, updated_at = row

    # (اختياري): لو عايز تمنع غير المفعّلين من استخدام النظام كله
    if not is_verified:
        raise HTTPException(status_code=403, detail="Email not verified")

    # ✅ مهم: قارن بس لو الاتنين موجودين
    if last_password_change_db is not None and last_password_change is not None:
        try:
            token_ts = int(last_password_change)
        except (TypeError, ValueError):
            token_ts = None

        if token_ts is None:
            raise HTTPException(status_code=401, detail="Invalid token payload")

        db_ts = int(last_password_change_db.timestamp())

        if token_ts != db_ts:
            raise HTTPException(status_code=401, detail="Token revoked")

    # احسب avatar_url من avatar_key زي ما بيعمل login
    # avatar_url = None
    # if avatar_key:
    #     try:
    #         from datetime import datetime, timezone
    #         base_url = supabase.storage.from_(settings.supabase_public_bucket).get_public_url(str(avatar_key))
    #         ts = int(updated_at.timestamp()) if updated_at else int(datetime.now(timezone.utc).timestamp())
    #         avatar_url = f"{base_url}?v={ts}"
    #     except Exception:
    #         avatar_url = None

    return {
        "id": uid,
        "email": email,
        "full_name": full_name,
        "system_role": system_role,
        # "avatar_url": avatar_url,
    }