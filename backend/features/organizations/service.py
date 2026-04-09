from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text

from typing import Dict, Any, List
import secrets

from app.core.emailer import send_email


def _generate_invite_code() -> str:
    # كود قصير عملي (ممكن تغييره لاحقًا)
    return secrets.token_hex(3)  # 6 chars تقريبًا


def create_organization(payload, db: Session, current_user):
    # 1) السماح للـ owner فقط
    if current_user.get("system_role") != "owner":
        raise HTTPException(status_code=403, detail="Only owners can create organizations")

    owner_id = current_user.get("id")
    if owner_id is None:
        raise HTTPException(status_code=401, detail="Invalid token")

    # 2) توليد invite_code (مع إعادة المحاولة لو حصل collision)
    invite_code = _generate_invite_code()
    for _ in range(5):
        exists = db.execute(
            text("SELECT 1 FROM organizations WHERE invite_code = :code"),
            {"code": invite_code},
        ).first()
        if not exists:
            break
        invite_code = _generate_invite_code()
    else:
        raise HTTPException(status_code=500, detail="Failed to generate invite code")

    # 3) Insert organization
    # ✅ IMPORTANT:
    # لا نرسل subscription_plan_id هنا.
    # لأن DB عندك واضع DEFAULT 1 (كما في model: server_default="1")
    try:
        row = db.execute(
            text("""
                INSERT INTO organizations
                (name, description, logo_url, owner_id, invite_code, subscription_status, created_at, updated_at)
                VALUES
                (:name, :desc, :logo, :owner_id, :invite_code, 'active', NOW(), NOW())
                RETURNING
                id, name, description, logo_url, owner_id, subscription_plan_id, invite_code, subscription_status
            """),
            {
                "name": payload.name,
                "desc": payload.description,
                "logo": payload.logo_url,
                "owner_id": owner_id,
                "invite_code": invite_code,
            },
        ).first()

        db.commit()

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"DB error: {str(e)}")

    if not row:
        raise HTTPException(status_code=400, detail="something went wrong")

    return {
        "organization": {
            "id": row[0],
            "name": row[1],
            "description": row[2],
            "logo_url": row[3],
            "owner_id": row[4],
            "subscription_plan_id": row[5],
            "invite_code": row[6],
            "subscription_status": row[7],
        }
    }


def list_join_requests(*, organization_id: int, view: str, db: Session, current_user) -> Dict[str, Any]:
    """
    Returns join requests for a given organization owned by the current owner.

    view:
      - "pending"  -> status IN ("pending")
      - "accepted" -> status IN ("accepted", "suspended")
    """

    # 1) Owner-only
    if current_user.get("system_role") != "owner":
        raise HTTPException(status_code=403, detail="Only owners can view join requests")

    owner_id = current_user.get("id")
    if owner_id is None:
        raise HTTPException(status_code=401, detail="Invalid token")

    # 2) Validate view
    view = (view or "").strip().lower()
    if view not in {"pending", "accepted"}:
        raise HTTPException(status_code=400, detail="Invalid view")

    statuses = ("pending",) if view == "pending" else ("accepted", "suspended")

    # 3) Ownership check
    org_exists = db.execute(
        text("""
            SELECT 1
            FROM organizations
            WHERE id = :org_id AND owner_id = :owner_id
        """),
        {"org_id": organization_id, "owner_id": owner_id},
    ).first()

    if not org_exists:
        raise HTTPException(status_code=403, detail="Access denied")

    # 4) Fetch users
    rows = db.execute(
        text("""
            SELECT
                u.id,
                u.full_name,
                u.email,
                u.avatar_url,
                u.system_role,
                om.status,
                om.id
            FROM organization_members om
            JOIN users u ON u.id = om.user_id
            WHERE om.organization_id = :org_id
              AND om.status = ANY(:statuses)
            ORDER BY u.id ASC
        """),
        {"org_id": organization_id, "statuses": list(statuses)},
    ).all()

    users: List[Dict[str, Any]] = [
        {
            "id": r[0],
            "org_member_id": r[6],
            "full_name": r[1],
            "email": r[2],
            "avatar_url": r[3],
            "system_role": r[4],
            "status": r[5],
        }
        for r in rows
    ]

    return {"count": len(users), "users": users}


def update_member_status(
    *,
    organization_id: int,
    org_member_id: int,
    new_status: str,
    db: Session,
    current_user,):
    
    # 1) Owner-only
    if current_user.get("system_role") != "owner":
        raise HTTPException(status_code=403, detail="Only owners can update member status")

    owner_id = current_user.get("id")
    if owner_id is None:
        raise HTTPException(status_code=401, detail="Invalid token")

    new_status = (new_status or "").strip().lower()
    allowed_statuses = {"pending", "accepted", "suspended", "declinate"}
    if new_status not in allowed_statuses:
        raise HTTPException(status_code=400, detail="Invalid status")

    # 2) Verify organization ownership
    org_ok = db.execute(
        text("""
            SELECT 1
            FROM organizations
            WHERE id = :org_id AND owner_id = :owner_id
        """),
        {"org_id": organization_id, "owner_id": owner_id},
    ).first()
    if not org_ok:
        raise HTTPException(status_code=403, detail="Access denied")

    # 3) Load membership row + user info
    row = db.execute(
        text("""
            SELECT
                om.id,
                om.organization_id,
                om.user_id,
                om.status,
                u.email,
                u.full_name
            FROM organization_members om
            JOIN users u ON u.id = om.user_id
            WHERE om.id = :om_id
        """),
        {"om_id": org_member_id},
    ).first()

    if not row:
        raise HTTPException(status_code=404, detail="Member not found")

    om_id, om_org_id, user_id, old_status, user_email, user_full_name = row

    if om_org_id != organization_id:
        raise HTTPException(status_code=403, detail="Access denied")

    old_status = (old_status or "").strip().lower()

    # 4) Transition rules
    allowed_transitions = {
        "pending": {"accepted", "declinate"},
        "accepted": {"suspended"},
        "suspended": {"accepted"},
        "declinate": set(),
    }

    if old_status not in allowed_transitions:
        raise HTTPException(status_code=500, detail="Invalid stored status")

    if new_status == old_status:
        return {
            "org_member_id": om_id,
            "user_id": user_id,
            "organization_id": om_org_id,
            "old_status": old_status,
            "new_status": old_status,
        }

    if new_status not in allowed_transitions[old_status]:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid status transition: {old_status} -> {new_status}",
        )

    # 5) Update status (+ joined_at لو أول مرة accepted من pending)
    try:
        if old_status == "pending" and new_status == "accepted":
            db.execute(
                text("""
                    UPDATE organization_members
                    SET status = :new_status,
                        joined_at = COALESCE(joined_at, NOW())
                    WHERE id = :om_id
                """),
                {"new_status": new_status, "om_id": om_id},
            )
        else:
            db.execute(
                text("""
                    UPDATE organization_members
                    SET status = :new_status
                    WHERE id = :om_id
                """),
                {"new_status": new_status, "om_id": om_id},
            )

        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"DB error: {str(e)}")

    # 6) Send email
    subject = "Learnova – Membership update"

    logo_url = ""  # حط لينك اللوجو هنا
    brand_year = 2026
    support_email = "support@learnova.com"

    text_body = f"""
    Hello {user_full_name},

    Your membership status has been updated to: {new_status}

    If you have any questions, contact us at {support_email}.
    """

    html_body = f"""
    <!DOCTYPE html>
    <html lang="en">
    <body style="margin:0;padding:0;background:#f6f7fb;font-family:Arial,sans-serif;">
    <!-- Preheader (hidden) -->
    <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">
        Your Learnova membership status was updated.
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
                        <img src="{logo_url}" width="40" height="40" alt="Learnova"
                        style="display:block;border:0;outline:none;border-radius:10px;" />
                    </td>
                    <td style="vertical-align:middle;padding-left:10px;">
                        <div style="font-size:16px;font-weight:800;color:#111827;line-height:1;">
                        Learnova
                        </div>
                        <div style="font-size:12px;color:#6b7280;margin-top:2px;">
                        Membership Update
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
                        Membership Updated ✅
                        </h2>

                        <p style="margin:10px 0 0;color:#374151;line-height:1.7;font-size:14px;">
                        Hello <strong>{user_full_name}</strong>, your membership status has been updated.
                        </p>

                        <!-- Status box -->
                        <table cellpadding="0" cellspacing="0" style="margin-top:16px;width:100%;">
                        <tr>
                            <td style="background:#F9FAFB;border:1px solid #E5E7EB;border-radius:12px;padding:14px 14px;">
                            <div style="font-size:12px;color:#6b7280;">New status</div>
                            <div style="margin-top:6px;font-size:16px;font-weight:800;color:#111827;">
                                {new_status}
                            </div>
                            </td>
                        </tr>
                        </table>

                        <!-- Info chips -->
                        <table cellpadding="0" cellspacing="0" style="margin-top:16px;">
                        <tr>
                            <td style="background:#EAF3FF;border:1px solid #BBD9FF;border-radius:999px;padding:6px 10px;">
                            <span style="font-size:12px;color:#1F4B99;">
                                ℹ️ Membership notification
                            </span>
                            </td>
                            <td style="width:10px;"></td>
                            <td style="background:#F3F4F6;border:1px solid #E5E7EB;border-radius:999px;padding:6px 10px;">
                            <span style="font-size:12px;color:#374151;">
                                🛟 Support available
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

                    <!-- Footer note -->
                    <tr>
                    <td style="padding:14px 26px 24px;">
                        <p style="margin:0;color:#6b7280;font-size:12px;line-height:1.6;">
                        If you have questions about this change, contact us at
                        <a href="mailto:{support_email}" style="color:#137FEC;text-decoration:none;">{support_email}</a>.
                        </p>
                        <p style="margin:12px 0 0;color:#9ca3af;font-size:12px;line-height:1.6;">
                        This is an automated email, please do not reply.
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
                    © {brand_year} Learnova. All rights reserved.
                </p>
                <p style="margin:6px 0 0;color:#9ca3af;font-size:12px;line-height:1.6;">
                    Need help? Contact us at
                    <a href="mailto:{support_email}" style="color:#137FEC;text-decoration:none;">{support_email}</a>
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
            to=user_email,
            subject=subject,
            body=text_body,
            html=html_body,
        )
    except Exception:
        pass

    return {
        "org_member_id": om_id,
        "user_id": user_id,
        "organization_id": om_org_id,
        "old_status": old_status,
        "new_status": new_status,
    }
