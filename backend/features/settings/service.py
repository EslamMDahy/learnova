from fastapi import HTTPException

from sqlalchemy.orm import Session
from sqlalchemy import text

import secrets
import os

from datetime import datetime, timezone, timedelta
from storage3.types import CreateSignedUploadUrlOptions

from .schemas import UpdateProfileRequest

from app.core.security import hash_password
from app.core.security import verify_password  # عدّل import حسب مكانهم عندك
from app.core.emailer import send_email
from app.core.storage_utils import delete_storage_object
from app.core.supabase_client import supabase
from app.core.config import settings

# 5MB
# _AVATAR_MAX_BYTES = 5 * 1024 * 1024

# _ALLOWED_CONTENT_TYPES = {
#     "image/png",
#     "image/jpeg",
#     "image/jpg",
# }


def update_profile(*, payload: UpdateProfileRequest, db: Session, current_user):
    user_id = current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")

    update_fields = {}

    if payload.full_name is not None and payload.full_name.strip() != "":
        update_fields["full_name"] = payload.full_name.strip()

    if payload.phone is not None:
        update_fields["phone_number"] = payload.phone.strip()

    if payload.bio is not None:
        update_fields["bio"] = payload.bio.strip()

    if payload.language_preference is not None:
        update_fields["language_preference"] = payload.language_preference.strip()

    # NOTE: `student_id` & `university_email` is a reed only data 
    # wich means it get send in the login responce 
    # ✅ NEW: احفظ student_id / university_email / language_preference
    # if getattr(payload, "student_id", None) is not None:
    #     update_fields["student_id"] = payload.student_id.strip()

    # if getattr(payload, "university_email", None) is not None:
    #     update_fields["university_email"] = payload.university_email.strip()


    if not update_fields:
        raise HTTPException(status_code=400, detail="No updatable fields provided")

    set_clauses = []
    params = {"uid": user_id}

    for col in [
        "full_name",
        "phone_number",
        "bio",
        "student_id",
        "university_email",
        "language_preference",
    ]:
        if col in update_fields:
            set_clauses.append(f"{col} = :{col}")
            params[col] = update_fields[col]

    set_clauses.append("updated_at = NOW()")

    row = db.execute(
        text(f"""
            UPDATE users
            SET {", ".join(set_clauses)}
            WHERE id = :uid
            RETURNING
              id, full_name, email, phone_number, bio,
              student_id, university_email, language_preference,
              system_role, is_email_verified, account_status,
              last_login_at, created_at, updated_at
        """),
        params,
    ).first()

    if not row:
        raise HTTPException(status_code=404, detail="User not found")

    db.commit()

    return {
        "id": row[0],
        "full_name": row[1],
        "email": row[2],
        "phone_number": row[3],
        "bio": row[4],
        "student_id": row[5],
        "university_email": row[6],
        "language_preference": row[7],
        "system_role": row[8],
        "is_email_verified": row[9],
        "account_status": row[10],
        "last_login_at": row[11].isoformat() if row[11] else None,
        "created_at": row[12].isoformat() if row[12] else None,
        "updated_at": row[13].isoformat() if row[13] else None,
    }


def create_avatar_upload_url(*, payload, db: Session, current_user):
    """
    payload متوقع منه (في schemas عندك):
      - content_type: str
      - file_size_bytes: int
    """
    user_id = current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")

    content_type = (getattr(payload, "content_type", None) or "").strip().lower()
    file_size_bytes = getattr(payload, "file_size_bytes", None)

    # 5MB
    _AVATAR_MAX_BYTES = 5 * 1024 * 1024

    _ALLOWED_CONTENT_TYPES = {
        "image/png",
        "image/jpeg",
        "image/jpg",
    }

    # validations
    if not content_type:
        raise HTTPException(status_code=400, detail="content_type is required")

    if content_type not in _ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=400,
            detail="Invalid content_type. Allowed: image/png, image/jpeg",
        )

    if file_size_bytes is None:
        raise HTTPException(status_code=400, detail="file_size_bytes is required")

    try:
        file_size_bytes = int(file_size_bytes)
    except Exception:
        raise HTTPException(status_code=400, detail="file_size_bytes must be an integer")

    if file_size_bytes <= 0:
        raise HTTPException(status_code=400, detail="file_size_bytes must be > 0")

    if file_size_bytes > _AVATAR_MAX_BYTES:
        raise HTTPException(status_code=400, detail="Avatar image is too large (max 5MB)")

    bucket = settings.supabase_public_bucket
    key = f"users/{user_id}/avatar"

    # نطلع Signed Upload URL (ينفع تستخدمه الفرونت يرفع من غير api keys)
    # NOTE: بعض إصدارات بايثون بتدعم options/upsert وبعضها بتبقى حساسة.
    # هنحاول بـ upsert=True ولو حصل TypeError نرجع نجرب من غير options.
    options = CreateSignedUploadUrlOptions(upsert="true")
    try:
        signed = supabase.storage.from_(bucket).create_signed_upload_url(
            key,
            options)
    except TypeError:
        signed = supabase.storage.from_(bucket).create_signed_upload_url(key)


    data = None
    error = None

    if isinstance(signed, dict):
        # بعض الإصدارات بتعمل error كـ key
        error = signed.get("error")
        # أغلب الوقت ده هو الـ data نفسه
        if signed.get("signedUrl") or signed.get("signed_url") or signed.get("url"):
            data = signed
    else:
        # لو رجع object
        data = getattr(signed, "data", None)
        error = getattr(signed, "error", None)

    if error:
        msg = error.get("message") if isinstance(error, dict) else str(error)
        raise HTTPException(status_code=400, detail=f"Failed to create signed upload url: {msg}")

    if not data:
        raise HTTPException(status_code=400, detail="Failed to create signed upload url")

    upload_url = data.get("signedUrl") or data.get("signed_url") or data.get("url")
    token = data.get("token")
    path = data.get("path") or key

    if not upload_url:
        raise HTTPException(status_code=400, detail="Signed upload URL is missing from response")

    # مهم جدًا للفرونت:
    # - يرفع بـ PUT/POST حسب ما SDK بتقول
    # - ويبعت headers: Content-Type = content_type
    # - وبعض الفلوهات تحتاج x-upsert أو x-signature (token) حسب نوع الـ signed upload
    return {
        "upload_url": upload_url,
        "path": path,
        "token": token,  # لو الفرونت محتاجه (في بعض طرق الرفع بيستخدم x-signature)
        "content_type": content_type,
        "max_bytes": _AVATAR_MAX_BYTES,
    }


def confirm_avatar_upload(*, payload, db: Session, current_user):
    """
    Endpoint الفرونت يناديه بعد الرفع.

    payload ممكن يبقى فاضي دلوقتي،
    بس مستقبلًا ممكن نحط فيه مثلا:
      - checksum
      - width/height
      - ... إلخ
    """
    user_id = current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")

    bucket = settings.supabase_public_bucket
    key = f"users/{user_id}/avatar"

    # نتأكد إن الملف موجود فعلًا في الستورج
    # أنضف طريقة بدون تحميل الملف: list داخل folder والبحث عن الاسم
    folder = f"users/{user_id}"
    try:
        items = supabase.storage.from_(bucket).list(path=folder)
    except Exception:
        items = None

    exists = False
    if isinstance(items, list):
        for it in items:
            # it غالبًا dict: {"name": "...", ...}
            if (it.get("name") == "avatar"):
                exists = True
                break

    if not exists:
        raise HTTPException(
            status_code=400,
            detail="Avatar upload not found in storage. Upload the file first, then confirm.",
        )

    # دلوقتي نعمل update_at = now() ونحفظ avatar_key
    row = db.execute(
        text("""
            UPDATE users
            SET updated_at = NOW()
            WHERE id = :uid
            RETURNING updated_at
        """),
        {"uid": user_id},
    ).first()

    if not row:
        raise HTTPException(status_code=404, detail="User not found")

    db.commit()

    base_url = supabase.storage.from_(bucket).get_public_url(key)

    # updated_at_iso مثال: "2026-02-22T10:20:30.123456+00:00"
    # هنحوّله لرقم epoch بسيط

    updated_at = row[0].isoformat() if row[0] else datetime.now(timezone.utc).isoformat()

    try:
        dt = datetime.fromisoformat(updated_at.replace("Z", "+00:00"))
        v = int(dt.timestamp())
    except Exception:
        v = int(datetime.now(timezone.utc).timestamp())
        
    avatar_url = f"{base_url}?v={v}"

    return {
        "message": "Avatar updated successfully",
        "avatar_url": avatar_url,
        "updated_at": updated_at,
    }


def change_password(*, payload, db: Session, current_user):
    user_id = current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")

    # 1) basic validation (خفيف)
    if not payload.current_password or not payload.new_password:
        raise HTTPException(status_code=400, detail="Missing password fields")

    if payload.current_password == payload.new_password:
        raise HTTPException(status_code=400, detail="New password must be different")

    # 2) load user hashed password + email/name (نحتاجهم للتحقق + الإيميل)
    row = db.execute(
        text(
            """
            SELECT id, full_name, email, hashed_password
            FROM users
            WHERE id = :uid
            LIMIT 1
        """
        ),
        {"uid": user_id},
    ).first()

    if not row:
        raise HTTPException(status_code=401, detail="Invalid token")

    _, full_name, email, hashed_pw = row

    # 3) verify current password
    if not verify_password(payload.current_password, hashed_pw):
        raise HTTPException(status_code=401, detail="Invalid current password")

    # 4) update password + bump token_version
    new_hashed = hash_password(payload.new_password)

    db.execute(
        text(
            """
            UPDATE users
            SET hashed_password = :hp,
                updated_at = NOW(),
                last_password_change = NOW()
            WHERE id = :uid
        """
        ),
        {"hp": new_hashed, "uid": user_id},
    )

    # 5) invalidate any previous reset_password tokens (زي forget-password)
    db.execute(
        text(
            """
            UPDATE user_tokens
            SET used_at = NOW()
            WHERE user_id = :uid
              AND type = 'reset_password'
              AND used_at IS NULL
        """
        ),
        {"uid": user_id},
    )

    # 6) create a new reset token for "If this wasn't you" link
    reset_token = secrets.token_urlsafe(32)
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=15)

    db.execute(
        text(
            """
            INSERT INTO user_tokens (user_id, type, token, expires_at, created_at)
            VALUES (:uid, 'reset_password', :token, :expires_at, NOW())
        """
        ),
        {"uid": user_id, "token": reset_token, "expires_at": expires_at},
    )

    db.commit()

    # 7) send notification email (best-effort)
    frontend_url = settings.frontend_base_url
    secure_link = f"{frontend_url.rstrip('/')}/#/reset-password?token={reset_token}"

    subject = "Learnova – Password changed"
    text_body = f"""
    Hello {full_name or ''}

    Your Learnova password was just changed.

    If this wasn't you, secure your account immediately by setting a new password using this link:
    {secure_link}

    This link expires in 15 minutes.
    """

    html_body = f"""
    <!DOCTYPE html>
    <html lang="en">
    <body style="margin:0;padding:0;background:#f6f7fb;font-family:Arial,sans-serif;">
        <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">
        Your Learnova password was changed. If this wasn’t you, secure your account now.
        </div>

        <table width="100%" cellpadding="0" cellspacing="0" style="background:#f6f7fb;">
        <tr>
            <td align="center" style="padding:28px 16px;">

            <table width="560" cellpadding="0" cellspacing="0" style="width:560px;max-width:560px;">

                <tr>
                <td style="padding:0 8px 14px;">
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
                            Security Alert
                        </div>
                        </td>
                    </tr>
                    </table>
                </td>
                </tr>

                <tr>
                <td style="background:#ffffff;border:1px solid #e5e7eb;border-radius:16px;overflow:hidden;">
                    <div style="height:6px;background:#137FEC;"></div>

                    <table width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                        <td style="padding:26px 26px 10px;">
                        <h2 style="margin:0;color:#111827;font-size:22px;line-height:1.25;">
                            Your password was changed 🔐
                        </h2>

                        <p style="margin:10px 0 0;color:#374151;line-height:1.7;font-size:14px;">
                            Hello {full_name or ''}, your Learnova password was just changed.
                        </p>

                        <p style="margin:10px 0 0;color:#374151;line-height:1.7;font-size:14px;">
                            If this wasn’t you, please secure your account immediately by setting a new password.
                        </p>

                        <table cellpadding="0" cellspacing="0" style="margin-top:18px;">
                            <tr>
                            <td align="center" bgcolor="#137FEC" style="border-radius:10px;">
                                <a href="{secure_link}"
                                style="display:inline-block;padding:12px 18px;font-size:14px;font-weight:700;
                                        color:#ffffff;text-decoration:none;border-radius:10px;">
                                Secure Account
                                </a>
                            </td>
                            </tr>
                        </table>

                        <table cellpadding="0" cellspacing="0" style="margin-top:16px;">
                            <tr>
                            <td style="background:#FFF7ED;border:1px solid #FED7AA;border-radius:999px;padding:6px 10px;">
                                <span style="font-size:12px;color:#9A3412;">
                                ⏳ Link expires in 15 minutes
                                </span>
                            </td>
                            <td style="width:10px;"></td>
                            <td style="background:#EAF3FF;border:1px solid #BBD9FF;border-radius:999px;padding:6px 10px;">
                                <span style="font-size:12px;color:#1F4B99;">
                                🔒 Security action
                                </span>
                            </td>
                            </tr>
                        </table>

                        </td>
                    </tr>

                    <tr>
                        <td style="padding:0 26px;">
                        <div style="height:1px;background:#E5E7EB;"></div>
                        </td>
                    </tr>

                    <tr>
                        <td style="padding:14px 26px 24px;">
                        <p style="margin:0;color:#6b7280;font-size:12px;line-height:1.6;">
                            If the button doesn’t work, copy and paste this link into your browser:
                        </p>
                        <p style="margin:10px 0 0;font-size:12px;line-height:1.6;">
                            <a href="{secure_link}" style="color:#137FEC;text-decoration:none;word-break:break-all;">
                            {secure_link}
                            </a>
                        </p>

                        <p style="margin:16px 0 0;color:#9ca3af;font-size:12px;line-height:1.6;">
                            If you changed your password, you can safely ignore this email.
                        </p>
                        </td>
                    </tr>
                    </table>
                </td>
                </tr>

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
    try:
        send_email(to=email, subject=subject, body=text_body, html=html_body)
        sent = True
    except Exception:
        pass

    return {
        "message": "Password updated successfully",
        "email_notification_sent": sent,
    }


def request_delete_account(*, payload, db: Session, current_user):
    user_id = current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")

    row = db.execute(
        text(
            """
            SELECT id, full_name, email, hashed_password
            FROM users
            WHERE id = :uid
            LIMIT 1
             """
        ),
        {"uid": user_id},
    ).first()

    if not row:
        raise HTTPException(status_code=401, detail="Invalid token")

    _, full_name, email, hashed_pw = row

    if not payload.current_password or not verify_password(payload.current_password, hashed_pw):
        raise HTTPException(status_code=401, detail="Invalid current password")

    db.execute(
        text(
            """
            UPDATE user_tokens
            SET used_at = NOW()
            WHERE user_id = :uid
              AND type = :type
              AND used_at IS NULL
             """
        ),
        {"uid": user_id, "type": "delete_account_otp"},
    )

    otp = secrets.token_hex(3)
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=10)

    db.execute(
        text(
            """
            INSERT INTO user_tokens (user_id, type, token, expires_at, created_at)
            VALUES (:uid, :type, :token, :expires_at, NOW())
        """
        ),
        {"uid": user_id, "type": "delete_account_otp", "token": otp, "expires_at": expires_at},
    )

    db.commit()

    subject = "Learnova – Confirm account deletion (OTP)"
    text_body = f"""
    Hello {full_name or ''}

    You requested to delete your Learnova account.

    Your OTP code is:
    {otp}

    This code expires in 10 minutes.

    If you didn't request this, you can ignore this email.
    """

    html_body = f"""
    <!DOCTYPE html>
    <html lang="en">
    <body style="margin:0;padding:0;background:#f6f7fb;font-family:Arial,sans-serif;">
        <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">
        Your OTP code to confirm Learnova account deletion (expires in 10 minutes).
        </div>

        <table width="100%" cellpadding="0" cellspacing="0" style="background:#f6f7fb;">
        <tr>
            <td align="center" style="padding:28px 16px;">

            <table width="560" cellpadding="0" cellspacing="0" style="width:560px;max-width:560px;">

                <tr>
                <td style="padding:0 8px 14px;">
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
                            Account Deletion (OTP)
                        </div>
                        </td>
                    </tr>
                    </table>
                </td>
                </tr>

                <tr>
                <td style="background:#ffffff;border:1px solid #e5e7eb;border-radius:16px;overflow:hidden;">
                    <div style="height:6px;background:#137FEC;"></div>

                    <table width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                        <td style="padding:26px 26px 10px;">
                        <h2 style="margin:0;color:#111827;font-size:22px;line-height:1.25;">
                            Confirm account deletion 🧾
                        </h2>

                        <p style="margin:10px 0 0;color:#374151;line-height:1.7;font-size:14px;">
                            Hello {full_name or ''}, you requested to permanently delete your Learnova account.
                        </p>

                        <p style="margin:10px 0 0;color:#374151;line-height:1.7;font-size:14px;">
                            Use the OTP code below to confirm. <strong style="color:#111827;">Do not share this code</strong> with anyone.
                        </p>

                        <table width="100%" cellpadding="0" cellspacing="0" style="margin-top:16px;">
                            <tr>
                            <td align="center"
                                style="background:#F9FAFB;border:1px solid #E5E7EB;border-radius:12px;padding:14px 12px;">
                                <div style="font-size:26px;font-weight:800;letter-spacing:6px;color:#111827;line-height:1.2;">
                                    {otp}
                                </div>
                                <div style="margin-top:6px;font-size:12px;color:#6b7280;line-height:1.4;">
                                    OTP code
                                </div>
                            </td>
                            </tr>
                        </table>

                        <table cellpadding="0" cellspacing="0" style="margin-top:16px;">
                            <tr>
                            <td style="background:#FFF7ED;border:1px solid #FED7AA;border-radius:999px;padding:6px 10px;">
                                <span style="font-size:12px;color:#9A3412;">
                                ⏳ Expires in 10 minutes
                                </span>
                            </td>
                            <td style="width:10px;"></td>
                            <td style="background:#FEE2E2;border:1px solid #FCA5A5;border-radius:999px;padding:6px 10px;">
                                <span style="font-size:12px;color:#991B1B;">
                                ⚠️ Irreversible action
                                </span>
                            </td>
                            </tr>
                        </table>

                        </td>
                    </tr>

                    <tr>
                        <td style="padding:0 26px;">
                        <div style="height:1px;background:#E5E7EB;"></div>
                        </td>
                    </tr>

                    <tr>
                        <td style="padding:14px 26px 24px;">
                        <p style="margin:0;color:#9ca3af;font-size:12px;line-height:1.6;">
                            If you didn’t request this, you can ignore this email. Your account will remain unchanged.
                        </p>
                        </td>
                    </tr>
                    </table>
                </td>
                </tr>

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
    try:
        send_email(to=email, subject=subject, body=text_body, html=html_body)
        sent = True
    except Exception:
        pass

    return {
        "message": "Deletion OTP sent to your email.",
        "email_sent": sent,
    }


def confirm_delete_account(*, payload, db: Session, current_user):
    user_id = current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")

    otp = (payload.otp or "").strip()
    if not otp:
        raise HTTPException(status_code=400, detail="OTP is required")

    if len(otp) != 6:
        raise HTTPException(status_code=400, detail="Invalid OTP format")

    row = db.execute(
        text("""
            SELECT id, expires_at, used_at
            FROM user_tokens
            WHERE user_id = :uid
              AND type = :type
              AND token = :token
            LIMIT 1
        """),
        {"uid": user_id, "type": "delete_account_otp", "token": otp},
    ).first()

    if not row:
        raise HTTPException(status_code=400, detail="Invalid or expired OTP")

    token_id, expires_at, used_at = row

    if used_at is not None:
        raise HTTPException(status_code=400, detail="Invalid or expired OTP")

    now = datetime.now(timezone.utc)
    if expires_at <= now:
        db.execute(
            text("""
                UPDATE user_tokens
                SET used_at = NOW()
                WHERE id = :tid
            """),
            {"tid": token_id},
        )
        db.commit()
        raise HTTPException(status_code=400, detail="Invalid or expired OTP")

    # =========================
    # 1) Fetch avatar key before deleting user
    #    Assumption: users.avatar_key exists
    # =========================
    user_row = db.execute(
        text("""
            SELECT id, avatar_key
            FROM users
            WHERE id = :uid
            LIMIT 1
        """),
        {"uid": user_id},
    ).mappings().first()

    if not user_row:
        raise HTTPException(status_code=404, detail="User not found")

    avatar_key = user_row["avatar_key"]

    try:
        # mark OTP as used
        db.execute(
            text("""
                UPDATE user_tokens
                SET used_at = NOW()
                WHERE id = :tid
            """),
            {"tid": token_id},
        )

        # delete user
        deleted = db.execute(
            text("""
                DELETE FROM users
                WHERE id = :uid
                RETURNING id
            """),
            {"uid": user_id},
        ).first()

        if not deleted:
            db.rollback()
            raise HTTPException(status_code=404, detail="User not found")

        # delete avatar from storage only if exists
        if avatar_key:
            delete_storage_object(
                supabase_client=supabase,
                bucket=settings.supabase_public_bucket,
                storage_key=avatar_key,
            )

        db.commit()

    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to delete account: {str(e)}") from e

    return {"message": "Account deleted successfully"}