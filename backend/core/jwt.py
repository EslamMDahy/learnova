import os
from datetime import datetime, timedelta, timezone
from jose import jwt, JWTError
from fastapi import HTTPException

JWT_SECRET = os.getenv("JWT_SECRET")
JWT_ALG = os.getenv("JWT_ALG", "HS256")
JWT_EXPIRE_MIN = int(os.getenv("JWT_EXPIRE_MIN", "15"))

def create_access_token(*, subject: str, extra: dict | None = None) -> str:
    """
    subject: غالبًا user_id كنص
    extra: claims إضافية بسيطة (email, full_name, role...)
    """
    if not JWT_SECRET:
        raise RuntimeError("JWT_SECRET is missing")

    now = datetime.now(timezone.utc)
    payload = {
        "sub": subject,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=JWT_EXPIRE_MIN)).timestamp()),
    }
    if extra:
        payload.update(extra)

    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALG)

def decode_access_token(token: str) -> dict:
    if not JWT_SECRET:
        raise RuntimeError("JWT_SECRET is missing")

    try:
        # jose بيتحقق من exp تلقائيًا أثناء decode
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALG])
        return payload
    except JWTError:
        # 401 عشان التوكين invalid أو expired
        raise HTTPException(status_code=401, detail="Invalid or expired token")