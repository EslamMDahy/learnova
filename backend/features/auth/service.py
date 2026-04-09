from fastapi import HTTPException, Response, Request

from sqlalchemy.orm import Session
from sqlalchemy import text

import secrets
import os

from datetime import datetime, timedelta, timezone

from .schemas import LoginRequest

from app.core.security import hash_password
from app.core.security import verify_password
from app.core.security import hmac_sha256_hex
from app.core.emailer import send_email
from app.core.jwt import create_access_token
from app.core.supabase_client import supabase
from app.core.config import settings


def _set_refresh_cookie(response: Response, refresh_raw: str, refresh_expires_at: datetime):
    ttl_seconds = max(int((refresh_expires_at - datetime.now(timezone.utc)).total_seconds()), 0)
    response.set_cookie(
        key=settings.refresh_cookie_name,
        value=refresh_raw,
        httponly=True,
        secure=settings.cookie_secure,
        samesite=settings.cookie_samesite,
        path=settings.cookie_path,
        max_age=ttl_seconds,
        expires=refresh_expires_at,
    )


def register_user(payload, db: Session):
    # 1) Check email unique
    existing = db.execute(
        text("SELECT 1 FROM users WHERE email = :email"),
        {"email": payload.email},
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail="Email already exists")

    # 2) Decide logic based on account_type
    system_role = (payload.system_role or "").strip().lower()

    ALLOWED_USER_ROLES: set[str] = {"student", "instructor", "assistant", "owner"}

    if system_role not in ALLOWED_USER_ROLES:
        raise HTTPException(
                status_code=400,
                detail="Invalid System Role. Choose student, instructor, assistant, or owner",
            )

    # 3) Hash password
    hashed_pw = hash_password(payload.password)

    # 4) Insert user
    row = db.execute(
        text(
            """
            INSERT INTO users (
                full_name, email, hashed_password,
                system_role, language_preference, account_status,
                is_email_verified, created_at, updated_at
            )
            VALUES (
                :full_name, :email, :hashed_password,
                CAST(:system_role AS system_role_enum),
                :language_preference,
                CAST(:account_status AS account_status_enum),
                :is_email_verified, NOW(), NOW()
            )
            RETURNING id
            """
        ),
        {
            "full_name": payload.full_name,
            "email": payload.email,
            "hashed_password": hashed_pw,
            "system_role": system_role,
            "language_preference": "en",
            "account_status": "pending_activation",  # أو "active"
            "is_email_verified": False,
        },
    ).first()

    if not row:
        raise HTTPException(status_code=500, detail="Failed to create user")

    user_id = row[0]

    avatar_key = f"users/{user_id}/avatar"

    db.execute(
        text("UPDATE users SET avatar_key = :avatar_key WHERE id = :uid"),
        {"avatar_key": avatar_key, "uid": user_id},
    )

    db.commit()

    send_verification_email(payload, db)
    
    return {
        "message": "Registration successful. Please check your email.",
        "email_verification_required": True,
        "system_type": system_role,
    }
    


def send_verification_email(payload, db: Session):
    row = db.execute(
        text("""
             SELECT
             id, full_name, 
             email, is_email_verified
             FROM users
             WHERE email = :email
             """
        ),
        {"email": payload.email},
    ).first()

    # 1) email مش موجود
    if not row:
        raise HTTPException(status_code=400, detail="Bad Request")
    
    user_id, full_name, email, is_verified = row
    
    # 2) لو الايميل موجود بس معموله فيريفاي
    if is_verified:
        raise HTTPException(status_code=400, detail="Bad Request")

    # 3) نبطل اي ريسيت توكين قديمه لليوزر
    db.execute(
        text(
            """
            UPDATE user_tokens
            SET used_at = NOW()
            WHERE user_id = :uid AND type = 'verify_email' AND used_at IS NULL
            """
        ),
        {"uid": user_id}
    )

    # 3) Create verification token
    verify_token = secrets.token_urlsafe(32)
    expires_at = datetime.now(timezone.utc) + timedelta(hours=24)

    db.execute(
        text(
            """
            INSERT INTO user_tokens (user_id, type, token, expires_at, created_at)
            VALUES (:user_id, :type, :token, :expires_at, NOW())
            """
        ),
        {
            "user_id": user_id,
            "type": "verify_email",
            "token": verify_token,
            "expires_at": expires_at,
        },
    )
    db.commit()

    

    # 4) Build verification link (fallback بدل RuntimeError)
    frontend_url = settings.frontend_base_url
    verify_link = f"{frontend_url.rstrip('/')}/#/verify-email?token={verify_token}"
    

    text_body = f"""
    Welcome to Learnova!

    Verify your email:
    {verify_link}

    This link expires in 24 hours.
    """
    html_body = f"""
    <!DOCTYPE html>
    <html lang="en">
    <body style="margin:0;padding:0;background:#f6f7fb;font-family:Arial,sans-serif;">
        <!-- Preheader (hidden) -->
        <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">
        Verify your email to activate your Learnova account.
        </div>

        <table width="100%" cellpadding="0" cellspacing="0" style="background:#f6f7fb;">
        <tr>
            <td align="center" style="padding:28px 16px;">

            <!-- Outer container -->
            <table width="560" cellpadding="0" cellspacing="0" style="width:560px;max-width:560px;">

                <!-- Brand header -->
                <tr>
                <td align="left" style="padding:0 8px 14px;">
                    <table cellpadding="0" cellspacing="0">
                    <tr>
                        <td style="vertical-align:middle;">
                        <img src="{settings.email_logo_url}" width="40" height="40" alt="Learnova"
                            style="display:block;border:0;outline:none;border-radius:10px;" />
                        </td>
                        <td style="vertical-align:middle;padding-left:10px;">
                        <div style="font-size:16px;font-weight:800;color:#111827;line-height:1;">
                            Learnova
                        </div>
                        <div style="font-size:12px;color:#6b7280;margin-top:2px;">
                            Email Verification
                        </div>
                        </td>
                    </tr>
                    </table>
                </td>
                </tr>

                <!-- Card -->
                <tr>
                <td style="background:#ffffff;border:1px solid #e5e7eb;border-radius:16px;overflow:hidden;">
                    <!-- Top accent -->
                    <div style="height:6px;background:#137FEC;"></div>

                    <table width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                        <td style="padding:26px 26px 10px;">
                        <h2 style="margin:0;color:#111827;font-size:22px;line-height:1.25;">
                            Welcome to Learnova 👋
                        </h2>
                        <p style="margin:10px 0 0;color:#374151;line-height:1.7;font-size:14px;">
                            Please confirm your email address to activate your account.
                        </p>

                        <!-- Button -->
                        <table cellpadding="0" cellspacing="0" style="margin-top:18px;">
                            <tr>
                            <td align="center" bgcolor="#137FEC" style="border-radius:10px;">
                                <a href="{verify_link}"
                                style="display:inline-block;padding:12px 18px;font-size:14px;font-weight:700;
                                        color:#ffffff;text-decoration:none;border-radius:10px;">
                                Verify Email
                                </a>
                            </td>
                            </tr>
                        </table>

                        <!-- Info chips -->
                        <table cellpadding="0" cellspacing="0" style="margin-top:16px;">
                            <tr>
                            <td style="background:#F3F4F6;border:1px solid #E5E7EB;border-radius:999px;padding:6px 10px;">
                                <span style="font-size:12px;color:#374151;">
                                ⏳ Expires in 24 hours
                                </span>
                            </td>
                            <td style="width:10px;"></td>
                            <td style="background:#EAF3FF;border:1px solid #BBD9FF;border-radius:999px;padding:6px 10px;">
                                <span style="font-size:12px;color:#1F4B99;">
                                🔒 Secure link
                                </span>
                            </td>
                            </tr>
                        </table>

                        </td>
                    </tr>

                    <!-- Divider -->
                    <tr>
                        <td style="padding:0 26px;">
                        <div style="height:1px;background:#E5E7EB;"></div>
                        </td>
                    </tr>

                    <!-- Fallback link -->
                    <tr>
                        <td style="padding:14px 26px 24px;">
                        <p style="margin:0;color:#6b7280;font-size:12px;line-height:1.6;">
                            If the button doesn’t work, copy and paste this link into your browser:
                        </p>
                        <p style="margin:10px 0 0;font-size:12px;line-height:1.6;">
                            <a href="{verify_link}" style="color:#137FEC;text-decoration:none;word-break:break-all;">
                            {verify_link}
                            </a>
                        </p>

                        <p style="margin:16px 0 0;color:#9ca3af;font-size:12px;line-height:1.6;">
                            If you didn’t create an account, you can safely ignore this email.
                        </p>
                        </td>
                    </tr>
                    </table>
                </td>
                </tr>

                <!-- Footer -->
                <tr>
                <td align="center" style="padding:14px 10px 0;">
                    <p style="margin:0;color:#9ca3af;font-size:12px;line-height:1.6;">
                    © {settings.email_brand_year} Learnova. All rights reserved.
                    </p>
                    <p style="margin:6px 0 0;color:#9ca3af;font-size:12px;line-height:1.6;">
                    Need help? Contact us at <a href="mailto:{settings.email_support_email}" style="color:#137FEC;text-decoration:none;">{settings.email_support_email}</a>
                    </p>
                </td>
                </tr>

            </table>
            </td>
        </tr>
        </table>
    </body>
    </html>
    """

    sent = False
    # 5) Send verification email (متبوظش التسجيل لو الإيميل وقع)
    try:
        send_email(
            to=payload.email,
            subject="Learnova – Verify your email",
            body=text_body,
            html=html_body,
        )
        sent = True
    except Exception:
        HTTPException(status_code=503, detail="Service Unavailable")

    return {
        "message": "Chick your email",
        "email_sent": sent,
    }



def verify_email_token(token: str, db: Session):
    # 1) fetch token row
    row = db.execute(
        text("""
            SELECT id, user_id, expires_at, used_at
            FROM user_tokens
            WHERE token = :token AND type = 'verify_email'
        """),
        {"token": token},
    ).first()

    if row is None:
        raise HTTPException(status_code=400, detail="Invalid verification token")

    token_id, user_id, expires_at, used_at = row

    # 2) already used?
    if used_at is not None:
        raise HTTPException(status_code=400, detail="Token already used")

    # 3) expired?
    # expires_at جاي من DB كـ timestamp with time zone، فالمقارنة مباشرة مع NOW() أسهل داخل SQL
    expired = db.execute(
        text("SELECT (NOW() > :expires_at)"),
        {"expires_at": expires_at},
    ).scalar()

    if expired:
        raise HTTPException(status_code=400, detail="Token expired")

    # 4) mark user verified + mark token used
    db.execute(
        text("UPDATE users SET is_email_verified = TRUE, email_verified_at = NOW(), updated_at = NOW() WHERE id = :uid"),
        {"uid": user_id},
    )

    db.execute(
        text("UPDATE user_tokens SET used_at = NOW() WHERE id = :tid"),
        {"tid": token_id},
    )

    db.commit()

    return {"message": "Email verified successfully"}



def login_user(payload: LoginRequest, db: Session, response: Response):
    row = db.execute(
        text("""
             SELECT
             id, full_name, email, hashed_password,
             avatar_key, phone_number,  bio, 
             system_role, student_id, university_email, 
             language_preference, is_email_verified, 
             created_at, updated_at, last_login_at, last_password_change
             FROM users
             WHERE email = :email
             """
        ),
        {"email": payload.email},
    ).first()

    # 1) email مش موجود
    if not row:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    user_id, full_name, email, hashed_pw, avatar_key, phone_number,  bio, system_role, student_id, university_email, language_preference, is_verified, created_at, updated_at, last_login_at, last_password_change = row

    # 2) باسورد غلط (قبل verification)
    if not verify_password(payload.password, hashed_pw):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    # 3) هنا فقط نكشف أنه مش verified لأن credentials صح
    if not is_verified:
        raise HTTPException(status_code=403, detail="Email not verified")
    
    # 4) preparing the login response data
    base_url = supabase.storage.from_(settings.supabase_public_bucket).get_public_url(str(avatar_key))

    avatar_updated_at = updated_at.isoformat() if updated_at else datetime.now(timezone.utc).isoformat()

    try:
        dt = datetime.fromisoformat(avatar_updated_at.replace("Z", "+00:00"))
        v = int(dt.timestamp())
    except Exception:
        v = int(datetime.now(timezone.utc).timestamp())
        
    avatar_url = f"{base_url}?v={v}"

    user = {
        "id": user_id,
        "full_name": full_name,
        "email": email,
        "avatar_url": avatar_url,
        "phone_number": phone_number,
        "bio": bio,
        "system_role": system_role,
        "student_id": student_id,
        "university_email": university_email,
        "language_preference": language_preference,
        "created_at": created_at,
        "last_login_at": last_login_at,
    }

    orgs = []
    if system_role == "owner":
        org_rows = db.execute(
            text("""
                SELECT
                id, name, description, logo_url,
                owner_id, subscription_plan_id, invite_code,
                subscription_status, subscription_started_at,
                subscription_renews_at, trial_ends_at
                FROM organizations
                WHERE owner_id = :uid
                ORDER BY id
            """),
            {"uid": user_id},
        ).all()

        orgs = [
            {
                "id": r[0],
                "name": r[1],
                "description": r[2],
                "logo_url": r[3],
                "owner_id": r[4],
                "subscription_plan_id": r[5],
                "invite_code": r[6],
                "subscription_status": r[7],
                "subscription_started_at": r[8],
                "subscription_renews_at": r[9],
                "trial_ends_at": r[10],
            }
            for r in org_rows
        ]

    plan_name = None

    if system_role != "owner":
        plan_name = db.execute(
            text("""
                SELECT sp.name
                FROM organization_members om
                JOIN organizations o ON o.id = om.organization_id
                JOIN subscription_plans sp ON sp.id = o.subscription_plan_id
                WHERE om.user_id = :uid
                LIMIT 1
            """),
            {"uid": user_id},
        ).scalar()

        user["subscription_plan_name"] = plan_name

    # 5) Cereating JWT
    access_token = create_access_token(
        subject=str(user_id),
        extra={"email": email, "full_name": full_name, "last_password_change": int(last_password_change.timestamp()) if last_password_change else None, "system_role": system_role},
    )
    
    # =========================
    # Refresh token (HttpOnly cookie)
    # =========================
    if not settings.refresh_token_secret:
        raise HTTPException(status_code=500, detail="Server misconfigured: REFRESH_TOKEN_SECRET is missing")

    # remember_me => مدة أطول
    days = settings.refresh_token_expire_days_remember if payload.remember_me else settings.refresh_token_expire_days_short

    now = datetime.now(timezone.utc)
    refresh_expires_at = now + timedelta(days=days)

    # raw refresh token (ده اللي هيتحط في cookie)
    refresh_raw = secrets.token_urlsafe(48)

    # store only HMAC hash in DB
    refresh_hash = hmac_sha256_hex(refresh_raw, settings.refresh_token_secret)

    # (اختياري) إبطال refresh tokens القديمة لليوزر (جلسة واحدة فقط)
    # لو عايز multi-device شيل الجزء ده
    db.execute(
        text("""
            UPDATE user_tokens
            SET used_at = NOW()
            WHERE user_id = :uid
              AND type = 'refresh'
              AND used_at IS NULL
        """),
        {"uid": user_id},
    )

    # insert refresh token hash
    db.execute(
        text("""
            INSERT INTO user_tokens (user_id, type, token, expires_at, used_at, created_at)
            VALUES (:uid, 'refresh', :token, :expires_at, NULL, NOW())
        """),
        {"uid": user_id, "token": refresh_hash, "expires_at": refresh_expires_at},
    )

    # set HttpOnly cookie
    _set_refresh_cookie(response, refresh_raw, refresh_expires_at)

    # 6) Sending the login response
    resp = {
    "access_token": access_token,
    "token_type": "bearer",
    "user": user,
    }

    db.execute(
        text("UPDATE users SET last_login_at = NOW() WHERE id = :uid"),
        {"uid": user_id},
    )
    db.commit()

    return resp



def check_email_verified(payload, db: Session) -> dict:
    """
    Check if a user's email address is verified.

    Security notes:
    - Returns { is_verified: false } for unknown emails (does NOT reveal if email exists).
    - No authentication required — used by unverified users who can't log in.
    - Rate limiting should be applied at the API gateway / reverse proxy level.
    """
    row = db.execute(
        text("""
            SELECT is_email_verified
            FROM users
            WHERE email = :email
        """),
        {"email": payload.email},
    ).first()

    # Unknown email → return false (don't reveal existence)
    if row is None:
        return {"is_verified": False}

    (is_verified,) = row
    return {"is_verified": bool(is_verified)}


def refresh_access_token(*, db: Session, request: Request, response: Response):
    if not settings.refresh_token_secret:
        raise HTTPException(status_code=500, detail="Server misconfigured: REFRESH_TOKEN_SECRET is missing")

    # 1) read refresh cookie
    refresh_raw = request.cookies.get(settings.refresh_cookie_name)
    if not refresh_raw:
        raise HTTPException(status_code=401, detail="Missing refresh token")

    now = datetime.now(timezone.utc)
    refresh_hash = hmac_sha256_hex(refresh_raw, settings.refresh_token_secret)

    # 2) validate token
    row = db.execute(
        text("""
            SELECT ut.user_id, expires_at, created_at, used_at, id
            FROM user_tokens ut
            WHERE ut.type = 'refresh'
              AND ut.token = :token
              AND ut.expires_at > NOW()
            LIMIT 1
        """),
        {"token": refresh_hash},
    ).first()

    if not row:
        response.delete_cookie(key=settings.refresh_cookie_name, path=settings.cookie_path)
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

    user_id, expires_at, created_at, used_at, token_id = row

    # Grace window: if two parallel requests hit refresh at the same time,
    # the second one finds used_at set but within 10s → return new access token
    _GRACE_SECONDS = 10
    if used_at is not None:
        used_utc = used_at if used_at.tzinfo else used_at.replace(tzinfo=timezone.utc)
        age = (now - used_utc).total_seconds()
        if age <= _GRACE_SECONDS:
            fresh = db.execute(
                text("""
                    SELECT ut.id FROM user_tokens ut
                    WHERE ut.user_id = :uid AND ut.type = 'refresh'
                      AND ut.used_at IS NULL AND ut.expires_at > NOW()
                    ORDER BY ut.created_at DESC LIMIT 1
                """),
                {"uid": user_id},
            ).first()
            if fresh:
                ur = db.execute(
                    text("SELECT id, email, full_name, system_role, last_password_change FROM users WHERE id = :uid LIMIT 1"),
                    {"uid": user_id},
                ).first()
                if ur:
                    return {
                        "access_token": create_access_token(
                            subject=str(ur[0]),
                            extra={"email": ur[1], "full_name": ur[2], "system_role": ur[3],
                                   "last_password_change": int(ur[4].timestamp()) if ur[4] else None},
                        ),
                        "token_type": "bearer",
                    }
        response.delete_cookie(key=settings.refresh_cookie_name, path=settings.cookie_path)
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

    # 3) get user claims
    user_row = db.execute(
        text("""
            SELECT id, email, full_name, system_role, last_password_change
            FROM users WHERE id = :uid LIMIT 1
        """),
        {"uid": user_id},
    ).first()

    if not user_row:
        response.delete_cookie(key=settings.refresh_cookie_name, path=settings.cookie_path)
        raise HTTPException(status_code=401, detail="User not found")

    uid, email, full_name, system_role, last_password_change = user_row

    # 4) invalidate THIS token only
    db.execute(
        text("UPDATE user_tokens SET used_at = NOW() WHERE id = :tid"),
        {"tid": token_id},
    )

    # 5) mint new refresh token (rotation)
    ttl = expires_at - created_at
    if ttl.total_seconds() <= 0:
        ttl = timedelta(days=settings.refresh_token_expire_days_short)
    now = datetime.now(timezone.utc)
    refresh_expires_at = now + ttl

    new_refresh_raw = secrets.token_urlsafe(48)
    new_refresh_hash = hmac_sha256_hex(new_refresh_raw, settings.refresh_token_secret)

    db.execute(
        text("""
            INSERT INTO user_tokens (user_id, type, token, expires_at, used_at, created_at)
            VALUES (:uid, 'refresh', :token, :expires_at, NULL, NOW())
        """),
        {"uid": uid, "token": new_refresh_hash, "expires_at": refresh_expires_at},
    )

    # 6) set new HttpOnly cookie (rotation)
    _set_refresh_cookie(response, new_refresh_raw, refresh_expires_at)

    # 7) mint new access token
    access_token = create_access_token(
        subject=str(uid),
        extra={
            "email": email,
            "full_name": full_name,
            "system_role": system_role,
            "last_password_change": int(last_password_change.timestamp()) if last_password_change else None,
        },
    )

    db.commit()

    return {
        "access_token": access_token,
        "token_type": "bearer",
    }

def logout_user(*, db: Session, request: Request, response: Response):
    if not settings.refresh_token_secret:
        raise HTTPException(status_code=500, detail="Server misconfigured: REFRESH_TOKEN_SECRET is missing")

    refresh_raw = request.cookies.get(settings.refresh_cookie_name)

    # Always delete the cookie
    response.delete_cookie(
        key=settings.refresh_cookie_name,
        path=settings.cookie_path,
    )

    if not refresh_raw:
        return {"message": "Logged out"}

    refresh_hash = hmac_sha256_hex(refresh_raw, settings.refresh_token_secret)

    row = db.execute(
        text("""
            SELECT user_id
            FROM user_tokens
            WHERE type = 'refresh'
              AND token = :token
              AND used_at IS NULL
            LIMIT 1
        """),
        {"token": refresh_hash},
    ).first()

    if row:
        uid = row[0]
        db.execute(
            text("""
                UPDATE user_tokens
                SET used_at = NOW()
                WHERE user_id = :uid
                  AND type = 'refresh'
                  AND used_at IS NULL
            """),
            {"uid": uid},
        )
        db.commit()

    return {"message": "Logged out"}



def forget_password_request(payload, db):
    # 1) دور على اليوزر بالايميل
    row = db.execute(
        text("SELECT id, full_name, email, is_email_verified FROM users WHERE email = :email"),
        {"email": payload.email},
    ).first()
 
    # 2) رد ثابت سواء الايميل موجود او لا عشان السيكيورتي
    ok_response = {"message": "If this email exists, a reser link has been sent."}

    if not row:
        return ok_response
    
    user_id, full_name, email, is_verified = row

    # 3) نبطل اي ريسيت توكين قديمه لليوزر
    db.execute(
        text(
            """
            UPDATE user_tokens
            SET used_at = NOW()
            WHERE user_id = :uid AND type = 'reset_password' AND used_at IS NULL
            """
        ),
        {"uid": user_id}
    )

    # 4) نكريت توكين قويه 
    resetPass_token = secrets.token_urlsafe(32)

    # 5) الاكسبيريشن دايت هنخليه 15 دقيقه
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(minutes=15)

    # 6) store the token in the DB
    db.execute(
        text(
            """
            INSERT INTO user_tokens
            (user_id, type, token, expires_at, created_at)
            VALUES
            (:uid, :type, :token, :expires_at, NOW())
            """
        ),
        {"uid": user_id, "type": "reset_password", "token": resetPass_token, "expires_at": expires_at}
    ) 
    db.commit()
    
    
    frontend_url = settings.frontend_base_url
    reset_link = f"{frontend_url.rstrip('/')}/#/reset-password?token={resetPass_token}"

    subject = "Learnova – Reset your password"

    text_body = f"""
    Hello {full_name or ''}

    We received a request to reset your Learnova password.

    Reset your password:
    {reset_link}

    This link expires in 15 minutes.

    If you didn't request this, you can safely ignore this email.
    """
    html_body = f"""
    <!DOCTYPE html>
    <html lang="en">
    <body style="margin:0;padding:0;background:#f6f7fb;font-family:Arial,sans-serif;">
        <!-- Preheader -->
        <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">
        Reset your Learnova password
        </div>

        <table width="100%" cellpadding="0" cellspacing="0" style="background:#f6f7fb;">
        <tr>
            <td align="center" style="padding:28px 16px;">

            <table width="560" cellpadding="0" cellspacing="0" style="max-width:560px;">

                <!-- Brand -->
                <tr>
                <td style="padding:0 8px 14px;">
                    <table cellpadding="0" cellspacing="0">
                    <tr>
                        <td>
                        <img src="{settings.email_logo_url}" width="40" height="40" alt="Learnova"
                            style="display:block;border-radius:10px;" />
                        </td>
                        <td style="padding-left:10px;">
                        <div style="font-size:16px;font-weight:800;color:#111827;">
                            Learnova
                        </div>
                        <div style="font-size:12px;color:#6b7280;">
                            Password Reset
                        </div>
                        </td>
                    </tr>
                    </table>
                </td>
                </tr>

                <!-- Card -->
                <tr>
                <td style="background:#ffffff;border:1px solid #e5e7eb;border-radius:16px;">
                    <div style="height:6px;background:#137FEC;border-radius:16px 16px 0 0;"></div>

                    <table width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                        <td style="padding:26px;">
                        <h2 style="margin:0 0 12px;color:#111827;font-size:22px;">
                            Reset your password 🔒
                        </h2>

                        <p style="margin:0 0 18px;color:#374151;line-height:1.7;font-size:14px;">
                            We received a request to reset your password. Click the button
                            below to choose a new one.
                        </p>

                        <!-- Button -->
                        <table cellpadding="0" cellspacing="0">
                            <tr>
                            <td bgcolor="#137FEC" style="border-radius:10px;">
                                <a href="{reset_link}"
                                style="display:inline-block;padding:12px 18px;
                                        font-size:14px;font-weight:700;
                                        color:#ffffff;text-decoration:none;
                                        border-radius:10px;">
                                Reset Password
                                </a>
                            </td>
                            </tr>
                        </table>

                        <!-- Info -->
                        <table cellpadding="0" cellspacing="0" style="margin-top:16px;">
                            <tr>
                            <td style="background:#FFF7ED;border:1px solid #FED7AA;
                                        border-radius:999px;padding:6px 10px;">
                                <span style="font-size:12px;color:#9A3412;">
                                ⏳ Expires in 15 minutes
                                </span>
                            </td>
                            </tr>
                        </table>

                        <p style="margin:16px 0 0;color:#6b7280;font-size:12px;line-height:1.6;">
                            If you didn’t request a password reset, you can safely ignore
                            this email.
                        </p>

                        </td>
                    </tr>

                    <!-- Divider -->
                    <tr>
                        <td style="padding:0 26px;">
                        <div style="height:1px;background:#e5e7eb;"></div>
                        </td>
                    </tr>

                    <!-- Fallback -->
                    <tr>
                        <td style="padding:14px 26px 24px;">
                        <p style="margin:0;color:#9ca3af;font-size:12px;">
                            If the button doesn’t work, copy and paste this link:
                        </p>
                        <p style="margin:8px 0 0;font-size:12px;word-break:break-all;">
                            <a href="{reset_link}"
                            style="color:#137FEC;text-decoration:none;">
                            {reset_link}
                            </a>
                        </p>
                        </td>
                    </tr>

                    </table>
                </td>
                </tr>

                <!-- Footer -->
                <tr>
                <td align="center" style="padding:14px 10px 0;">
                    <p style="margin:0;color:#9ca3af;font-size:12px;">
                    © {datetime.now().year} Learnova. All rights reserved.
                    </p>
                </td>
                </tr>

            </table>
            </td>
        </tr>
        </table>
    </body>
    </html>
    """


    try:
        send_email(
            to=email,
            subject=subject,
            body=text_body,
            html=html_body,
        )
    except Exception:
        HTTPException(status_code=503, detail="Service Unavailable")


    return ok_response

    

def reset_password(payload, db):
    row = db.execute(
        text("""
            SELECT id, user_id, expires_at, used_at
            FROM user_tokens
            WHERE token = :token AND type = 'reset_password'
            LIMIT 1
            """
        ),
        {"token": payload.token},
    ).first()

    if not row:
        raise HTTPException(status_code=400, detail="Invalid or expired token")

    token_id, user_id, expires_at, used_at = row

    # 2) check used
    if used_at is not None:
        raise HTTPException(status_code=400, detail="Invalid or expired token")

    # 3) check expiry
    now = datetime.now(timezone.utc)
    # expires_at غالبًا timezone-aware من postgres
    if expires_at <= now:
        # نقدر نعمل used_at هنا كمان عشان نقفلها
        db.execute(
            text("UPDATE user_tokens SET used_at = NOW() WHERE id = :tid"),
            {"tid": token_id},
        )
        db.commit()
        raise HTTPException(status_code=400, detail="Invalid or expired token")

    # 4) hash new password
    new_hashed = hash_password(payload.new_password)

    # 5) update user password
    db.execute(
        text("""
            UPDATE users
            SET hashed_password = :hp, 
                updated_at = NOW(),
                last_password_change = NOW()
            WHERE id = :uid
            """
        ),
        {"hp": new_hashed, "uid": user_id},
    )

    # 6) mark token used
    db.execute(
        text("UPDATE user_tokens SET used_at = NOW() WHERE id = :tid"),
        {"tid": token_id},
    )

    db.commit()

    return {"message": "Password reset successfully"}