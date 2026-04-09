from __future__ import annotations

from fastapi import HTTPException
from datetime import datetime, timezone
from sqlalchemy import text
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError, SQLAlchemyError

from app.core.config import settings
from app.core.storage_utils import split_object_key, sanitize_filename, delete_storage_object
from app.core.supabase_client import supabase  # عدّل import حسب مكان supabase client عندك

_PDF_MAX_BYTES = 50 * 1024 * 1024
_ALLOWED_CONTENT_TYPES = {"application/pdf"}

# صلاحية لينك الداونلود (ثواني)
SIGNED_URL_EXPIRES_SECONDS = 60 * 60  # 1 hour



def init_material_upload(*, course_id: int, module_id: int, payload, db: Session, current_user: dict):
    # =========================
    # 1) AuthZ
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can upload materials")

    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")
    if not module_id or module_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid module_id")

    # =========================
    # 2) Validate module belongs to course + course ownership
    # =========================
    mod = db.execute(
        text("""
            SELECT m.id AS module_id, m.course_id, c.created_by
            FROM modules m
            JOIN courses c ON c.id = m.course_id
            WHERE m.id = :mid
            LIMIT 1
        """),
        {"mid": module_id},
    ).mappings().first()

    if not mod:
        raise HTTPException(status_code=404, detail="Module not found")

    if int(mod["course_id"]) != int(course_id):
        raise HTTPException(status_code=400, detail="Module does not belong to this course")

    if mod["created_by"] != instructor_id:
        raise HTTPException(status_code=403, detail="You can only upload materials for your own course")

    # =========================
    # 3) Validate file metadata
    # =========================
    content_type = (getattr(payload, "content_type", None) or "").strip().lower()
    file_size_bytes = getattr(payload, "file_size_bytes", None)
    filename = getattr(payload, "filename", None)

    if not content_type:
        raise HTTPException(status_code=400, detail="content_type is required")

    if content_type not in _ALLOWED_CONTENT_TYPES:
        raise HTTPException(status_code=400, detail="Invalid content_type. Allowed: application/pdf")

    if file_size_bytes is None:
        raise HTTPException(status_code=400, detail="file_size_bytes is required")

    try:
        file_size_bytes = int(file_size_bytes)
    except Exception:
        raise HTTPException(status_code=400, detail="file_size_bytes must be an integer")

    if file_size_bytes <= 0:
        raise HTTPException(status_code=400, detail="file_size_bytes must be > 0")

    if file_size_bytes > _PDF_MAX_BYTES:
        raise HTTPException(status_code=400, detail="File is too large (max 50MB)")

    safe_filename = sanitize_filename(payload.filename,
                                      allowed_extensions={"pdf"},
                                      default_extension="pdf",
                                      keep_original_extension=True,)

    # optional metadata
    title = getattr(payload, "title", None)
    if isinstance(title, str):
        title = title.strip() or None

    description = getattr(payload, "description", None)
    if isinstance(description, str):
        description = description.strip() or None

    bucket = settings.supabase_private_bucket

    # =========================
    # 4) DB: create draft material row to get material_id
    # =========================
    # storage_key is non-null -> put a temporary value, then update it
    temp_key = "tmp"

    try:
        row = db.execute(
            text("""
                INSERT INTO materials (
                    module_id,
                    title,
                    description,
                    type,
                    file_name,
                    file_size,
                    storage_key,
                    mime_type,
                    status,
                    is_ai_processed,
                    uploaded_by,
                    uploaded_at,
                    created_at,
                    updated_at
                )
                VALUES (
                    :module_id,
                    :title,
                    :description,
                    CAST(:type AS material_type_enum),
                    :file_name,
                    :file_size,
                    :storage_key,
                    :mime_type,
                    CAST(:status AS material_status_enum),
                    FALSE,
                    :uploaded_by,
                    NOW(),
                    NOW(),
                    NOW()
                )
                RETURNING id, created_at
            """),
            {
                "module_id": module_id,
                "title": title,
                "description": description,
                "type": "pdf",
                "file_name": safe_filename,
                "file_size": file_size_bytes,
                "storage_key": temp_key,
                "mime_type": content_type,
                "status": "draft_upload",
                "uploaded_by": instructor_id,
            },
        ).mappings().first()

        if not row:
            db.rollback()
            raise HTTPException(status_code=503, detail="Failed to create material record")

        material_id = int(row["id"])
        created_at = row.get("created_at")

        # compute final storage key
        storage_key = (
            f"courses/{course_id}/modules/{module_id}/materials/{material_id}/{safe_filename}"
        )

        # update storage_key to final path
        db.execute(
            text("""
                UPDATE materials
                SET storage_key = :storage_key,
                    updated_at = NOW()
                WHERE id = :mid
            """),
            {"storage_key": storage_key, "mid": material_id},
        )

        db.commit()

    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=409, detail="Conflict while creating material") from e
    except SQLAlchemyError as e:
        db.rollback()
        print(str(e))
        raise HTTPException(status_code=500, detail="Database error") from e

    # =========================
    # 5) Supabase: create signed upload URL (private bucket)
    # =========================
    try:
        signed = supabase.storage.from_(bucket).create_signed_upload_url(storage_key)
    except Exception as e:
        # if storage failed, you may want to mark material as error later (optional)
        raise HTTPException(status_code=400, detail=f"Failed to create signed upload url: {str(e)}")

    data = None
    error = None
    if isinstance(signed, dict):
        error = signed.get("error")
        if signed.get("signedUrl") or signed.get("signed_url") or signed.get("url"):
            data = signed
    else:
        data = getattr(signed, "data", None)
        error = getattr(signed, "error", None)

    if error:
        msg = error.get("message") if isinstance(error, dict) else str(error)
        raise HTTPException(status_code=400, detail=f"Failed to create signed upload url: {msg}")

    if not data:
        raise HTTPException(status_code=400, detail="Failed to create signed upload url")

    upload_url = data.get("signedUrl") or data.get("signed_url") or data.get("url")
    token = data.get("token")
    path = data.get("path") or storage_key

    if not upload_url:
        raise HTTPException(status_code=400, detail="Signed upload URL is missing from response")

    return {
        "material_id": material_id,
        "module_id": module_id,
        "course_id": course_id,
        "upload_url": upload_url,
        "storage_key": storage_key,
        "bucket": bucket,
        "content_type": content_type,
        "max_bytes": _PDF_MAX_BYTES,
        "expires_in_seconds": None,
        "status": "draft_upload",
        "created_at": created_at if created_at else datetime.now(timezone.utc),
        # token/path لو schemas عندك بتعرضهم (اختياري)
        # "token": token,
        # "path": path,
    }



def confirm_material_upload(*, material_id: int, db: Session, current_user: dict):
    # =========================
    # 1) AuthZ
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can confirm material uploads")

    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not material_id or material_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid material_id")

    bucket = settings.supabase_private_bucket

    # =========================
    # 2) Fetch material + ownership (material -> module -> course)
    # =========================
    mat = db.execute(
        text("""
            SELECT
                mt.id AS material_id,
                mt.module_id,
                mt.storage_key,
                mt.status,
                mt.file_name,
                m.course_id,
                c.created_by
            FROM materials mt
            JOIN modules m ON m.id = mt.module_id
            JOIN courses c ON c.id = m.course_id
            WHERE mt.id = :mid
            LIMIT 1
        """),
        {"mid": material_id},
    ).mappings().first()

    if not mat:
        raise HTTPException(status_code=404, detail="Material not found")

    if mat["created_by"] != instructor_id:
        raise HTTPException(status_code=403, detail="You can only manage materials for your own course")

    storage_key = (mat["storage_key"] or "").strip()
    if not storage_key:
        raise HTTPException(status_code=500, detail="Material storage_key is missing")

    current_status = (mat["status"] or "").strip()

    # =========================
    # 3) Idempotency / status check
    # =========================
    if current_status != "draft_upload":
        # لو بالفعل confirmed قبل كده (أو حالة تانية) رجّع 409 أو 200 حسب اللي تفضله
        # أنا هخليه 409 عشان يبين misuse واضح
        raise HTTPException(
            status_code=409,
            detail=f"Material status must be 'draft_upload' to confirm upload (current: '{current_status}')",
        )

    # =========================
    # 4) Verify file exists in storage (no download)
    # =========================
    folder, expected_filename = split_object_key(storage_key)

    try:
        items = supabase.storage.from_(bucket).list(path=folder)
    except Exception:
        items = None

    exists = False
    if isinstance(items, list):
        for it in items:
            # غالبًا dict فيه "name"
            if isinstance(it, dict) and it.get("name") == expected_filename:
                exists = True
                break

    if not exists:
        raise HTTPException(
            status_code=400,
            detail="Uploaded file not found in storage. Upload the file first, then confirm.",
        )

    # =========================
    # 5) Update DB status to READY
    # =========================
    try:
        row = db.execute(
            text("""
                UPDATE materials
                SET
                    status = CAST(:new_status AS material_status_enum),
                    uploaded_at = NOW(),
                    updated_at = NOW()
                WHERE id = :mid
                RETURNING updated_at
            """),
            {"mid": material_id, "new_status": "uploaded"},
        ).first()

        if not row:
            db.rollback()
            raise HTTPException(status_code=503, detail="Failed to confirm material upload")

        db.commit()

    except SQLAlchemyError as e:
        db.rollback()
        # مهم: ده ممكن يطلع لو READY_STATUS مش موجود في enum
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}") from e

    updated_at = row[0].isoformat() if row and row[0] else datetime.now(timezone.utc).isoformat()

    # =========================
    # 6) Create signed download URL (private bucket)
    # =========================
    download_url = None
    try:
        signed = supabase.storage.from_(bucket).create_signed_url(storage_key, SIGNED_URL_EXPIRES_SECONDS)
    except Exception:
        signed = None

    if isinstance(signed, dict):
        download_url = signed.get("signedUrl") or signed.get("signed_url") or signed.get("url")
    else:
        data = getattr(signed, "data", None) if signed is not None else None
        if isinstance(data, dict):
            download_url = data.get("signedUrl") or data.get("signed_url") or data.get("url")

    # download_url اختياري — لو فشل، confirm نفسه يفضل ناجح
    return {
        "material_id": int(mat["material_id"]),
        "module_id": int(mat["module_id"]),
        "course_id": int(mat["course_id"]),
        "status": "uploaded",
        "updated_at": updated_at,
        "download_url": download_url,
        "download_url_expires_in": SIGNED_URL_EXPIRES_SECONDS,
    }



def copy_material(*, source_module_id: int, target_course_id: int, target_module_id: int, db: Session, current_user: dict):
    # =========================
    # 1) AuthZ
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can copy materials")

    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not source_module_id or source_module_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid source_module_id")

    if not target_course_id or target_course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid target_course_id")

    if not target_module_id or target_module_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid target_module_id")

    # =========================
    # 2) Validate target module belongs to target course + ownership
    # =========================
    target_module = db.execute(
        text("""
            SELECT
                m.id AS module_id,
                m.course_id,
                c.created_by
            FROM modules m
            JOIN courses c
              ON c.id = m.course_id
            WHERE m.id = :target_module_id
            LIMIT 1
        """),
        {"target_module_id": target_module_id},
    ).mappings().first()

    if not target_module:
        raise HTTPException(status_code=404, detail="Target module not found")

    if int(target_module["course_id"]) != int(target_course_id):
        raise HTTPException(status_code=400, detail="Target module does not belong to target course")

    if int(target_module["created_by"]) != int(instructor_id):
        raise HTTPException(status_code=403, detail="You can only copy materials into your own course")

    # =========================
    # 3) Validate source module ownership
    # =========================
    source_module = db.execute(
        text("""
            SELECT
                m.id AS module_id,
                m.course_id,
                c.created_by
            FROM modules m
            JOIN courses c
              ON c.id = m.course_id
            WHERE m.id = :source_module_id
            LIMIT 1
        """),
        {"source_module_id": source_module_id},
    ).mappings().first()

    if not source_module:
        raise HTTPException(status_code=404, detail="Source module not found")

    if int(source_module["created_by"]) != int(instructor_id):
        raise HTTPException(status_code=403, detail="You can only copy materials from your own course")

    # =========================
    # 4) Fetch source materials
    # =========================
    source_materials = db.execute(
        text("""
            SELECT
                id,
                title,
                description,
                type,
                file_name,
                file_size,
                storage_key,
                thumbnail_key,
                mime_type,
                status,
                duration_seconds,
                page_count,
                dimensions,
                is_ai_processed,
                ai_processed_at,
                uploaded_by,
                uploaded_at,
                processed_at
            FROM materials
            WHERE module_id = :source_module_id
            ORDER BY id ASC
        """),
        {"source_module_id": source_module_id},
    ).mappings().all()

    if not source_materials:
        return []

    copied_materials = []

    # =========================
    # 5) Copy rows only (reuse same storage_key)
    # =========================
    try:
        for material in source_materials:
            new_row = db.execute(
                text("""
                    INSERT INTO materials (
                        module_id,
                        title,
                        description,
                        type,
                        file_name,
                        file_size,
                        storage_key,
                        thumbnail_key,
                        mime_type,
                        status,
                        duration_seconds,
                        page_count,
                        dimensions,
                        is_ai_processed,
                        ai_processed_at,
                        uploaded_by,
                        uploaded_at,
                        processed_at,
                        created_at,
                        updated_at
                    )
                    VALUES (
                        :module_id,
                        :title,
                        :description,
                        CAST(:type AS material_type_enum),
                        :file_name,
                        :file_size,
                        :storage_key,
                        :thumbnail_key,
                        :mime_type,
                        CAST(:status AS material_status_enum),
                        :duration_seconds,
                        :page_count,
                        CAST(:dimensions AS JSON),
                        :is_ai_processed,
                        :ai_processed_at,
                        :uploaded_by,
                        :uploaded_at,
                        :processed_at,
                        NOW(),
                        NOW()
                    )
                    RETURNING
                        id,
                        module_id,
                        title,
                        description,
                        type,
                        file_name,
                        file_size,
                        storage_key,
                        thumbnail_key,
                        mime_type,
                        status,
                        duration_seconds,
                        page_count,
                        dimensions,
                        is_ai_processed,
                        ai_processed_at,
                        uploaded_by,
                        uploaded_at,
                        processed_at,
                        created_at,
                        updated_at
                """),
                {
                    "module_id": target_module_id,
                    "title": material["title"],
                    "description": material["description"],
                    "type": material["type"],
                    "file_name": material["file_name"],
                    "file_size": material["file_size"],
                    "storage_key": material["storage_key"],
                    "thumbnail_key": material["thumbnail_key"],
                    "mime_type": material["mime_type"],
                    "status": material["status"],
                    "duration_seconds": material["duration_seconds"],
                    "page_count": material["page_count"],
                    "dimensions": material["dimensions"],
                    "is_ai_processed": material["is_ai_processed"],
                    "ai_processed_at": material["ai_processed_at"],
                    "uploaded_by": instructor_id,
                    "uploaded_at": material["uploaded_at"],
                    "processed_at": material["processed_at"],
                },
            ).mappings().first()

            if not new_row:
                db.rollback()
                raise HTTPException(status_code=503, detail="Failed to copy material")

            copied_materials.append(dict(new_row))

        return copied_materials

    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=409, detail="Conflict while copying materials") from e

    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error") from e



def list_module_materials(*, course_id: int, module_id: int, db: Session, current_user: dict):
    user_id = current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    role = (current_user.get("system_role") or "").strip().lower()
    if role not in {"instructor", "student"}:
        raise HTTPException(status_code=403, detail="Only instructors or students can access materials")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")
    if not module_id or module_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid module_id")

    # =========================
    # 1) Ensure module belongs to course + get course owner
    # =========================
    try:
        row = db.execute(
            text("""
                SELECT
                    m.id AS module_id,
                    m.course_id,
                    c.created_by
                FROM modules m
                JOIN courses c ON c.id = m.course_id
                WHERE m.id = :mid
                  AND m.course_id = :cid
                LIMIT 1
            """),
            {"mid": module_id, "cid": course_id},
        ).first()
    except SQLAlchemyError as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}") from e

    if not row:
        # يا إما module مش موجود، يا إما مش تابع للكورس ده
        raise HTTPException(status_code=404, detail="Module not found for this course")

    course_owner_id = row[2]

    # =========================
    # 2) Authorization
    # =========================
    if role == "instructor":
        if course_owner_id != user_id:
            raise HTTPException(status_code=403, detail="You can only access materials of your own course")

        # instructor sees all materials (including drafts / upload states)
        material_filter_sql = ""  # no filter
        filter_params = {}

    else:
        # student must be enrolled and allowed
        allowed_statuses = ("active", "completed")

        try:
            enrollment_status = db.execute(
                text("""
                    SELECT status
                    FROM course_enrollments
                    WHERE student_id = :uid
                      AND course_id = :cid
                    LIMIT 1
                """),
                {"uid": user_id, "cid": course_id},
            ).scalar()
        except SQLAlchemyError as e:
            raise HTTPException(status_code=500, detail=f"Database error: {str(e)}") from e

        if not enrollment_status:
            raise HTTPException(status_code=403, detail="You are not enrolled in this course")

        if enrollment_status not in allowed_statuses:
            raise HTTPException(status_code=403, detail=f"Enrollment status '{enrollment_status}' is not allowed")

        # student sees only published/available materials
        # IMPORTANT: لازم تختار status value موجود فعلاً في enum عندك
        # أنا هسميها "uploaded" هنا لأنك استخدمتها قبل كده. عدّلها لو enum عندك اسم مختلف.
        student_visible_status = "uploaded"

        material_filter_sql = "AND mt.status = CAST(:visible_status AS material_status_enum)"
        filter_params = {"visible_status": student_visible_status}

    # =========================
    # 3) Fetch materials (metadata only)
    # =========================
    try:
        materials_rows = db.execute(
            text(f"""
                SELECT
                    mt.id,
                    mt.module_id,
                    mt.title,
                    mt.description,
                    mt.type,
                    mt.file_name,
                    mt.file_size,
                    mt.mime_type,
                    mt.status,
                    mt.page_count,
                    mt.duration_seconds,
                    mt.uploaded_at,
                    mt.created_at,
                    mt.updated_at
                FROM materials mt
                WHERE mt.module_id = :mid
                {material_filter_sql}
                ORDER BY mt.created_at DESC, mt.id DESC
            """),
            {"mid": module_id, **filter_params},
        ).all()
    except SQLAlchemyError as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}") from e

    materials = [
        {
            "id": r[0],
            "module_id": r[1],
            "title": r[2],
            "description": r[3],
            "type": r[4],
            "file_name": r[5],
            "file_size": r[6],
            "mime_type": r[7],
            "status": r[8],
            "page_count": r[9],
            "duration_seconds": r[10],
            "uploaded_at": r[11],
            "created_at": r[12],
            "updated_at": r[13],
        }
        for r in materials_rows
    ]

    return {
        "course_id": course_id,
        "module_id": module_id,
        "materials": materials,
    }



def get_material_download_url(*, course_id: int, module_id: int, material_id: int, db: Session, current_user: dict,):
    # =========================
    # 1) Auth basics
    # =========================
    user_id = current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    role = (current_user.get("system_role") or "").strip().lower()
    if role not in {"instructor", "student"}:
        raise HTTPException(status_code=403, detail="Only instructors or students can access materials")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")
    if not module_id or module_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid module_id")
    if not material_id or material_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid material_id")

    bucket = settings.supabase_private_bucket

    # =========================
    # 2) Fetch material + relations (must match course/module path)
    # =========================
    try:
        row = db.execute(
            text("""
                SELECT
                    mt.id              AS material_id,
                    mt.storage_key     AS storage_key,
                    mt.status          AS status,
                    m.id               AS module_id,
                    m.course_id        AS course_id,
                    c.created_by       AS course_owner_id
                FROM materials mt
                JOIN modules m ON m.id = mt.module_id
                JOIN courses c ON c.id = m.course_id
                WHERE mt.id = :material_id
                  AND mt.module_id = :module_id
                  AND m.course_id = :course_id
                LIMIT 1
            """),
            {"material_id": material_id, "module_id": module_id, "course_id": course_id},
        ).mappings().first()
    except SQLAlchemyError as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}") from e

    if not row:
        raise HTTPException(status_code=404, detail="Material not found for this module/course")

    storage_key = (row["storage_key"] or "").strip()
    if not storage_key:
        raise HTTPException(status_code=500, detail="Material storage_key is missing")

    course_owner_id = row["course_owner_id"]

    # =========================
    # 3) Authorization
    # =========================
    if role == "instructor":
        if course_owner_id != user_id:
            raise HTTPException(status_code=403, detail="You can only access materials of your own course")
        # Instructor allowed (no status restriction)
    else:
        # Student must be enrolled and allowed
        allowed_enrollment_statuses = ("active", "completed")

        try:
            enrollment_status = db.execute(
                text("""
                    SELECT status
                    FROM course_enrollments
                    WHERE student_id = :uid
                      AND course_id = :cid
                    LIMIT 1
                """),
                {"uid": user_id, "cid": course_id},
            ).scalar()
        except SQLAlchemyError as e:
            raise HTTPException(status_code=500, detail=f"Database error: {str(e)}") from e

        if not enrollment_status:
            raise HTTPException(status_code=403, detail="You are not enrolled in this course")

        if enrollment_status not in allowed_enrollment_statuses:
            raise HTTPException(status_code=403, detail=f"Enrollment status '{enrollment_status}' is not allowed")

        # Student should only access "published/available" materials
        # أنت عندك status "uploaded" شغال. لو غيرته لاحقًا عدّل هنا.
        student_visible_status = "uploaded"
        if (row["status"] or "").strip() != student_visible_status:
            raise HTTPException(status_code=403, detail="Material is not available")

    # =========================
    # 4) Verify file exists in storage (no download)
    # =========================
    folder, filename = split_object_key(storage_key)
    if not filename:
        raise HTTPException(status_code=500, detail="Invalid storage_key")

    try:
        items = supabase.storage.from_(bucket).list(path=folder)
    except Exception:
        items = None

    exists = False
    if isinstance(items, list):
        for it in items:
            if isinstance(it, dict) and it.get("name") == filename:
                exists = True
                break

    if not exists:
        raise HTTPException(
            status_code=400,
            detail="File not found in storage. Please upload/confirm again.",
        )

    # =========================
    # 5) Generate signed download URL
    # =========================
    download_url = None
    try:
        signed = supabase.storage.from_(bucket).create_signed_url(storage_key, SIGNED_URL_EXPIRES_SECONDS)
    except Exception:
        signed = None

    if isinstance(signed, dict):
        download_url = signed.get("signedUrl") or signed.get("signed_url") or signed.get("url")
    else:
        data = getattr(signed, "data", None) if signed is not None else None
        if isinstance(data, dict):
            download_url = data.get("signedUrl") or data.get("signed_url") or data.get("url")

    if not download_url:
        raise HTTPException(status_code=502, detail="Failed to generate signed download URL")

    return {
        "course_id": int(course_id),
        "module_id": int(module_id),
        "material_id": int(material_id),
        "download_url": download_url,
        "expires_in_seconds": SIGNED_URL_EXPIRES_SECONDS,
    }



def reassign_material(*, course_id: int, module_id: int, material_id: int, payload, db: Session, current_user: dict):
    # =========================
    # 1) AuthZ
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can reassign materials")

    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    if not module_id or module_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid module_id")

    if not material_id or material_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid material_id")

    target_module_id = getattr(payload, "target_module_id", None)
    if not target_module_id:
        raise HTTPException(status_code=422, detail="target_module_id is required")

    try:
        target_module_id = int(target_module_id)
    except Exception:
        raise HTTPException(status_code=422, detail="Invalid target_module_id")

    if target_module_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid target_module_id")

    # =========================
    # 2) Validate source material + ownership chain
    # =========================
    material_row = db.execute(
        text("""
            SELECT
                mat.id,
                mat.module_id,
                mat.storage_key,
                src_mod.course_id,
                c.created_by
            FROM materials mat
            JOIN modules src_mod
              ON src_mod.id = mat.module_id
            JOIN courses c
              ON c.id = src_mod.course_id
            WHERE mat.id = :material_id
            LIMIT 1
        """),
        {"material_id": material_id},
    ).mappings().first()

    if not material_row:
        raise HTTPException(status_code=404, detail="Material not found")

    if int(material_row["module_id"]) != int(module_id):
        raise HTTPException(status_code=400, detail="Material does not belong to this module")

    if int(material_row["course_id"]) != int(course_id):
        raise HTTPException(status_code=400, detail="Material does not belong to this course")

    if int(material_row["created_by"]) != int(instructor_id):
        raise HTTPException(status_code=403, detail="You can only reassign materials in your own course")

    # =========================
    # 3) Validate target module
    # =========================
    target_module_row = db.execute(
        text("""
            SELECT
                m.id,
                m.course_id,
                c.created_by
            FROM modules m
            JOIN courses c
              ON c.id = m.course_id
            WHERE m.id = :target_module_id
            LIMIT 1
        """),
        {"target_module_id": target_module_id},
    ).mappings().first()

    if not target_module_row:
        raise HTTPException(status_code=404, detail="Target module not found")

    if int(target_module_row["course_id"]) != int(course_id):
        raise HTTPException(status_code=400, detail="Target module must belong to the same course")

    if int(target_module_row["created_by"]) != int(instructor_id):
        raise HTTPException(status_code=403, detail="You can only reassign materials into your own course")

    # optional but useful
    if int(target_module_id) == int(module_id):
        raise HTTPException(status_code=400, detail="Material is already assigned to this module")

    # =========================
    # 4) Update material.module_id only
    #    Do NOT change storage_key
    # =========================
    try:
        updated_row = db.execute(
            text("""
                UPDATE materials
                SET module_id = :target_module_id,
                    updated_at = NOW()
                WHERE id = :material_id
                RETURNING
                    id,
                    module_id,
                    storage_key
            """),
            {
                "target_module_id": target_module_id,
                "material_id": material_id,
            },
        ).mappings().first()

        if not updated_row:
            db.rollback()
            raise HTTPException(status_code=404, detail="Material not found")

        db.commit()
        return dict(updated_row)

    except HTTPException:
        db.rollback()
        raise

    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=409, detail="Conflict while reassigning material") from e

    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error") from e



def _delete_material_internal(*, material_id: int, db: Session, storage_bucket: str,):
    
    if not material_id or material_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid material_id")

    material_row = db.execute(
        text("""
            SELECT
                id,
                storage_key
            FROM materials
            WHERE id = :material_id
            LIMIT 1
        """),
        {"material_id": material_id},
    ).mappings().first()

    if not material_row:
        raise HTTPException(status_code=404, detail="Material not found")

    storage_key = material_row["storage_key"]

    deleted = db.execute(
        text("""
            DELETE FROM materials
            WHERE id = :material_id
            RETURNING id
        """),
        {"material_id": material_id},
    ).mappings().first()

    if not deleted:
        raise HTTPException(status_code=404, detail="Material not found")

    remaining_refs = db.execute(
        text("""
            SELECT COUNT(*) AS ref_count
            FROM materials
            WHERE storage_key = :storage_key
        """),
        {"storage_key": storage_key},
    ).scalar()

    if remaining_refs is None:
        remaining_refs = 0

    if int(remaining_refs) == 0 and storage_key:
        delete_storage_object(
            supabase_client=supabase,
            bucket=storage_bucket,
            storage_key=storage_key,
        )



def delete_material(*, course_id: int, module_id: int, material_id: int, db: Session, current_user: dict):
    # =========================
    # 1) AuthZ
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can delete materials")

    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")
    if not module_id or module_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid module_id")
    if not material_id or material_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid material_id")

    # =========================
    # 2) Validate ownership chain
    # =========================
    material_row = db.execute(
        text("""
            SELECT
                mat.id,
                mat.module_id,
                m.course_id,
                c.created_by
            FROM materials mat
            JOIN modules m
              ON m.id = mat.module_id
            JOIN courses c
              ON c.id = m.course_id
            WHERE mat.id = :material_id
            LIMIT 1
        """),
        {"material_id": material_id},
    ).mappings().first()

    if not material_row:
        raise HTTPException(status_code=404, detail="Material not found")

    if int(material_row["module_id"]) != int(module_id):
        raise HTTPException(status_code=400, detail="Material does not belong to this module")

    if int(material_row["course_id"]) != int(course_id):
        raise HTTPException(status_code=400, detail="Module does not belong to this course")

    if int(material_row["created_by"]) != int(instructor_id):
        raise HTTPException(status_code=403, detail="You can only delete materials from your own course")

    # =========================
    # 3) Delete material 
    #    with storge opject 
    #    if not used in another material
    # =========================
    try:
        _delete_material_internal(
            material_id=material_id,
            db=db,
            storage_bucket=settings.supabase_private_bucket,
        )

        db.commit()
        return None

    except HTTPException:
        db.rollback()
        raise

    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=409, detail="Conflict while deleting material") from e

    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error") from e

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e)) from e



# def delete_material(*, course_id: int, module_id: int, material_id: int, db: Session, current_user: dict):
#     # =========================
#     # 1) AuthZ
#     # =========================
#     role = (current_user.get("system_role") or "").strip().lower()
#     if role != "instructor":
#         raise HTTPException(status_code=403, detail="Only instructors can delete materials")

#     instructor_id = current_user.get("id")
#     if not instructor_id:
#         raise HTTPException(status_code=401, detail="Unauthorized")

#     if not course_id or course_id <= 0:
#         raise HTTPException(status_code=422, detail="Invalid course_id")
#     if not module_id or module_id <= 0:
#         raise HTTPException(status_code=422, detail="Invalid module_id")
#     if not material_id or material_id <= 0:
#         raise HTTPException(status_code=422, detail="Invalid material_id")

#     # =========================
#     # 2) Validate ownership chain
#     # =========================
#     material_row = db.execute(
#         text("""
#             SELECT
#                 mat.id,
#                 mat.module_id,
#                 mat.storage_key,
#                 m.course_id,
#                 c.created_by
#             FROM materials mat
#             JOIN modules m
#               ON m.id = mat.module_id
#             JOIN courses c
#               ON c.id = m.course_id
#             WHERE mat.id = :material_id
#             LIMIT 1
#         """),
#         {"material_id": material_id},
#     ).mappings().first()

#     if not material_row:
#         raise HTTPException(status_code=404, detail="Material not found")

#     if int(material_row["module_id"]) != int(module_id):
#         raise HTTPException(status_code=400, detail="Material does not belong to this module")

#     if int(material_row["course_id"]) != int(course_id):
#         raise HTTPException(status_code=400, detail="Module does not belong to this course")

#     if int(material_row["created_by"]) != int(instructor_id):
#         raise HTTPException(status_code=403, detail="You can only delete materials from your own course")

#     storage_key = material_row["storage_key"]

#     # =========================
#     # 3) Delete material row
#     # =========================
#     try:
#         deleted = db.execute(
#             text("""
#                 DELETE FROM materials
#                 WHERE id = :material_id
#                 RETURNING id
#             """),
#             {"material_id": material_id},
#         ).mappings().first()

#         if not deleted:
#             db.rollback()
#             raise HTTPException(status_code=404, detail="Material not found")

#         # =========================
#         # 4) Check remaining references to same storage_key
#         # =========================
#         remaining_refs = db.execute(
#             text("""
#                 SELECT COUNT(*) AS ref_count
#                 FROM materials
#                 WHERE storage_key = :storage_key
#             """),
#             {"storage_key": storage_key},
#         ).scalar()

#         if remaining_refs is None:
#             remaining_refs = 0

#         # =========================
#         # 5) Delete physical object only if unreferenced
#         # =========================
#         if int(remaining_refs) == 0 and storage_key:
#             delete_storage_object(
#                 supabase_client=supabase,
#                 bucket=settings.supabase_private_bucket,
#                 storage_key=storage_key,
#             )

#         db.commit()
#         return None

#     except HTTPException:
#         db.rollback()
#         raise

#     except IntegrityError as e:
#         db.rollback()
#         raise HTTPException(status_code=409, detail="Conflict while deleting material") from e

#     except SQLAlchemyError as e:
#         db.rollback()
#         raise HTTPException(status_code=500, detail="Database error") from e

#     except Exception as e:
#         db.rollback()
#         raise HTTPException(status_code=500, detail=str(e)) from e
    


