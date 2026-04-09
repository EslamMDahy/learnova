from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from datetime import datetime, timezone

from .schemas import (ModuleCreateRequest,
                      ModuleUpdateRequest)

from app.core.config import settings

from app.features.materials.service import copy_material, _delete_material_internal



def create_module(*, course_id: int, payload: ModuleCreateRequest, db: Session, current_user: dict):
    # =========================
    # 1) Authorization
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can create modules")

    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    # =========================
    # 2) Validate course exists + ownership
    # =========================
    course_row = db.execute(
        text("""
            SELECT id, created_by
            FROM courses
            WHERE id = :course_id
            LIMIT 1
        """),
        {"course_id": course_id},
    ).mappings().first()

    if not course_row:
        raise HTTPException(status_code=404, detail="Course not found")

    if course_row["created_by"] != instructor_id:
        raise HTTPException(status_code=403, detail="You can only manage modules for your own course")

    # =========================
    # 3) Prepare fields
    # =========================
    title = (payload.title or "").strip()
    if not title:
        raise HTTPException(status_code=422, detail="title is required")

    description = payload.description
    if isinstance(description, str):
        description = description.strip() or None

    # if omitted => default False (MVP-friendly)
    is_published = bool(payload.is_published) if payload.is_published is not None else False

    # published_at only when published
    published_at = datetime.now(timezone.utc) if is_published else None

    # =========================
    # 4) Compute order_index (append)
    #    COALESCE(MAX, -1) + 1 => 0 when empty
    # =========================
    next_order_index = db.execute(
        text("""
            SELECT COALESCE(MAX(order_index), -1) + 1 AS next_idx
            FROM modules
            WHERE course_id = :course_id
        """),
        {"course_id": course_id},
    ).scalar()

    if next_order_index is None:
        next_order_index = 0

    # =========================
    # 5) Insert module
    # =========================
    try:
        row = db.execute(
            text("""
                INSERT INTO modules (
                    course_id,
                    title,
                    description,
                    order_index,
                    is_published,
                    published_at,
                    created_at,
                    updated_at
                )
                VALUES (
                    :course_id,
                    :title,
                    :description,
                    :order_index,
                    :is_published,
                    :published_at,
                    NOW(),
                    NOW()
                )
                RETURNING
                    id,
                    course_id,
                    title,
                    description,
                    order_index,
                    is_published,
                    created_at,
                    updated_at
            """),
            {
                "course_id": course_id,
                "title": title,
                "description": description,
                "order_index": int(next_order_index),
                "is_published": is_published,
                "published_at": published_at,
            },
        ).mappings().first()

        if not row:
            db.rollback()
            raise HTTPException(status_code=503, detail="Failed to create module")

        db.commit()
        return dict(row)

    except IntegrityError as e:
        db.rollback()
        # مثال: unique constraint على (course_id, order_index) لو حصل concurrency
        raise HTTPException(status_code=409, detail="Conflict while creating module") from e

    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error") from e



def update_module(*, course_id: int, module_id: int, payload: ModuleUpdateRequest, db: Session, current_user: dict):
    # =========================
    # 1) Authorization
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can update modules")

    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    if not module_id or module_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid module_id")

    # =========================
    # 2) Validate module belongs to course + ownership
    # =========================
    module_row = db.execute(
        text("""
            SELECT
                m.id,
                m.course_id,
                c.created_by
            FROM modules m
            JOIN courses c
              ON c.id = m.course_id
            WHERE m.id = :module_id
            LIMIT 1
        """),
        {"module_id": module_id},
    ).mappings().first()

    if not module_row:
        raise HTTPException(status_code=404, detail="Module not found")

    if int(module_row["course_id"]) != int(course_id):
        raise HTTPException(status_code=400, detail="Module does not belong to this course")

    if int(module_row["created_by"]) != int(instructor_id):
        raise HTTPException(status_code=403, detail="You can only update modules in your own course")

    # =========================
    # 3) Build dynamic update fields
    #    Ignore missing fields and ignore null values
    # =========================
    update_fields = {}

    if payload.title is not None and payload.title.strip() != "":
        update_fields["title"] = payload.title.strip()

    if payload.description is not None:
        update_fields["description"] = payload.description.strip() or None

    if payload.is_published is not None:
        update_fields["is_published"] = bool(payload.is_published)
        update_fields["published_at"] = datetime.now(timezone.utc) if payload.is_published else None

    if not update_fields:
        raise HTTPException(status_code=400, detail="No updatable fields provided")

    set_clauses = []
    params = {"module_id": module_id}

    for col in ["title", "description", "is_published", "published_at"]:
        if col in update_fields:
            set_clauses.append(f"{col} = :{col}")
            params[col] = update_fields[col]

    set_clauses.append("updated_at = NOW()")

    # =========================
    # 4) Update module
    # =========================
    try:
        row = db.execute(
            text(f"""
                UPDATE modules
                SET {", ".join(set_clauses)}
                WHERE id = :module_id
                RETURNING
                    id,
                    course_id,
                    title,
                    description,
                    order_index,
                    is_published,
                    published_at,
                    created_at,
                    updated_at
            """),
            params,
        ).mappings().first()

        if not row:
            db.rollback()
            raise HTTPException(status_code=404, detail="Module not found")

        db.commit()
        return dict(row)

    except HTTPException:
        db.rollback()
        raise

    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error") from e



def copy_module(*, target_course_id: int, source_module_id: int, db: Session, current_user: dict):
    # =========================
    # 1) Authorization
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can copy modules")

    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not target_course_id or target_course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid target course_id")

    if not source_module_id or source_module_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid module_id")

    # =========================
    # 2) Validate source module
    # =========================
    source_module = db.execute(
        text("""
            SELECT id, course_id, title, description, is_published, published_at
            FROM modules
            WHERE id = :mid
            LIMIT 1
        """),
        {"mid": source_module_id},
    ).mappings().first()

    if not source_module:
        raise HTTPException(status_code=404, detail="Source module not found")

    source_course_id = source_module["course_id"]

    # =========================
    # 3) Validate ownership of source course
    # =========================
    source_course = db.execute(
        text("""
            SELECT id, created_by
            FROM courses
            WHERE id = :cid
            LIMIT 1
        """),
        {"cid": source_course_id},
    ).mappings().first()

    if not source_course:
        raise HTTPException(status_code=404, detail="Source course not found")

    if source_course["created_by"] != instructor_id:
        raise HTTPException(status_code=403, detail="You can only copy modules from your own courses")

    # =========================
    # 4) Validate ownership of target course
    # =========================
    target_course = db.execute(
        text("""
            SELECT id, created_by
            FROM courses
            WHERE id = :cid
            LIMIT 1
        """),
        {"cid": target_course_id},
    ).mappings().first()

    if not target_course:
        raise HTTPException(status_code=404, detail="Target course not found")

    if target_course["created_by"] != instructor_id:
        raise HTTPException(status_code=403, detail="You can only copy modules into your own courses")

    # =========================
    # 5) Compute new order_index
    # =========================
    next_order_index = db.execute(
        text("""
            SELECT COALESCE(MAX(order_index), -1) + 1 AS next_idx
            FROM modules
            WHERE course_id = :cid
        """),
        {"cid": target_course_id},
    ).scalar()

    if next_order_index is None:
        next_order_index = 0

    # =========================
    # 6) Insert copied module
    # =========================
    try:
        new_module = db.execute(
            text("""
                INSERT INTO modules (
                    course_id,
                    title,
                    description,
                    order_index,
                    is_published,
                    published_at,
                    created_at,
                    updated_at
                )
                VALUES (
                    :course_id,
                    :title,
                    :description,
                    :order_index,
                    :is_published,
                    :published_at,
                    NOW(),
                    NOW()
                )
                RETURNING
                    id,
                    course_id,
                    title,
                    description,
                    order_index,
                    is_published,
                    published_at,
                    created_at,
                    updated_at
            """),
            {
                "course_id": target_course_id,
                "title": source_module["title"],
                "description": source_module["description"],
                "order_index": int(next_order_index),
                "is_published": source_module["is_published"],
                "published_at": source_module["published_at"],
            },
        ).mappings().first()

        if not new_module:
            db.rollback()
            raise HTTPException(status_code=503, detail="Failed to copy module")

        copy_material(
            source_module_id=source_module_id,
            target_course_id=target_course_id,
            target_module_id=int(new_module["id"]),
            db=db,
            current_user=current_user,)
        db.commit()

        return dict(new_module)

    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=409, detail="Conflict while copying module") from e

    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error") from e



def reorder_modules(*, course_id: int, payload, db: Session, current_user: dict):
    # =========================
    # 1) Authorization
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can reorder modules")

    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    module_ids = getattr(payload, "module_ids", None)
    if not isinstance(module_ids, list) or not module_ids:
        raise HTTPException(status_code=400, detail="module_ids must be a non-empty list")

    try:
        module_ids = [int(mid) for mid in module_ids]
    except Exception:
        raise HTTPException(status_code=400, detail="module_ids must contain valid integers")

    if any(mid <= 0 for mid in module_ids):
        raise HTTPException(status_code=400, detail="module_ids must contain positive integers only")

    if len(module_ids) != len(set(module_ids)):
        raise HTTPException(status_code=400, detail="module_ids must not contain duplicates")

    # =========================
    # 2) Validate course exists + ownership
    # =========================
    course_row = db.execute(
        text("""
            SELECT id, created_by
            FROM courses
            WHERE id = :course_id
            LIMIT 1
        """),
        {"course_id": course_id},
    ).mappings().first()

    if not course_row:
        raise HTTPException(status_code=404, detail="Course not found")

    if int(course_row["created_by"]) != int(instructor_id):
        raise HTTPException(status_code=403, detail="You can only reorder modules for your own course")

    # =========================
    # 3) Fetch all course modules
    # =========================
    db_module_rows = db.execute(
        text("""
            SELECT id
            FROM modules
            WHERE course_id = :course_id
            ORDER BY order_index ASC, id ASC
        """),
        {"course_id": course_id},
    ).mappings().all()

    db_module_ids = [int(row["id"]) for row in db_module_rows]

    if not db_module_ids:
        raise HTTPException(status_code=404, detail="No modules found for this course")

    # request must include all modules exactly once
    if set(module_ids) != set(db_module_ids):
        raise HTTPException(
            status_code=400,
            detail="module_ids must include all course modules exactly once"
        )

    # =========================
    # 4) Reorder with two-phase update
    #    to avoid unique conflict on (course_id, order_index)
    # =========================
    try:
        # phase 1: move to temporary negative order values
        for idx, module_id in enumerate(module_ids):
            db.execute(
                text("""
                    UPDATE modules
                    SET order_index = :temp_order_index,
                        updated_at = NOW()
                    WHERE id = :module_id
                      AND course_id = :course_id
                """),
                {
                    "temp_order_index": -(idx + 1),
                    "module_id": module_id,
                    "course_id": course_id,
                },
            )

        # phase 2: assign final order values
        for idx, module_id in enumerate(module_ids):
            db.execute(
                text("""
                    UPDATE modules
                    SET order_index = :final_order_index,
                        updated_at = NOW()
                    WHERE id = :module_id
                      AND course_id = :course_id
                """),
                {
                    "final_order_index": idx,
                    "module_id": module_id,
                    "course_id": course_id,
                },
            )

        db.commit()

        return {
            "course_id": course_id,
            "module_ids": module_ids,
        }

    except HTTPException:
        db.rollback()
        raise

    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error") from e



def list_course_modules(*, course_id: int, db: Session, current_user: dict):
    user_id = current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    role = (current_user.get("system_role") or "").strip().lower()
    if role not in {"instructor", "student"}:
        raise HTTPException(status_code=403, detail="Only instructors or students can access course modules")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    # =========================
    # 1) Ensure course exists + get owner
    # =========================
    course = db.execute(
        text("""
            SELECT id, created_by
            FROM courses
            WHERE id = :cid
            LIMIT 1
        """),
        {"cid": course_id},
    ).first()

    if not course:
        raise HTTPException(status_code=404, detail="Course not found")

    course_owner_id = course[1]

    # =========================
    # 2) Authorization
    # =========================
    is_owner = (role == "instructor" and course_owner_id == user_id)

    if role == "student":
        # allowed statuses for viewing
        allowed_statuses = ("active", "completed")

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

        if not enrollment_status:
            raise HTTPException(status_code=403, detail="You are not enrolled in this course")

        if enrollment_status not in allowed_statuses:
            raise HTTPException(status_code=403, detail=f"Enrollment status '{enrollment_status}' is not allowed")

    elif role == "instructor":
        if not is_owner:
            # In MVP: instructor can only see modules of their own courses
            raise HTTPException(status_code=403, detail="You can only access modules of your own course")

    # =========================
    # 3) Query modules (filter published for students)
    # =========================
    try:
        if role == "student":
            rows = db.execute(
                text("""
                    SELECT
                        id, course_id, title, description, order_index,
                        is_published, published_at, created_at, updated_at
                    FROM modules
                    WHERE course_id = :cid
                      AND is_published = TRUE
                    ORDER BY order_index ASC, id ASC
                """),
                {"cid": course_id},
            ).all()
        else:
            # instructor owner
            rows = db.execute(
                text("""
                    SELECT
                        id, course_id, title, description, order_index,
                        is_published, published_at, created_at, updated_at
                    FROM modules
                    WHERE course_id = :cid
                    ORDER BY order_index ASC, id ASC
                """),
                {"cid": course_id},
            ).all()

    except SQLAlchemyError as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}") from e

    modules = [
        {
            "id": r[0],
            "course_id": r[1],
            "title": r[2],
            "description": r[3],
            "order_index": r[4],
            "is_published": r[5],
            "published_at": r[6],
            "created_at": r[7],
            "updated_at": r[8],
        }
        for r in rows
    ]

    return {
        "course_id": course_id,
        "modules": modules,
    }



def delete_module(*, course_id: int, module_id: int, db: Session, current_user: dict):
    # =========================
    # 1) Authorization
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can delete modules")

    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    if not module_id or module_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid module_id")

    # =========================
    # 2) Validate module belongs to course + ownership
    # =========================
    module_row = db.execute(
        text("""
            SELECT
                m.id,
                m.course_id,
                c.created_by
            FROM modules m
            JOIN courses c
              ON c.id = m.course_id
            WHERE m.id = :module_id
            LIMIT 1
        """),
        {"module_id": module_id},
    ).mappings().first()

    if not module_row:
        raise HTTPException(status_code=404, detail="Module not found")

    if int(module_row["course_id"]) != int(course_id):
        raise HTTPException(status_code=400, detail="Module does not belong to this course")

    if int(module_row["created_by"]) != int(instructor_id):
        raise HTTPException(status_code=403, detail="You can only delete modules from your own course")

    # =========================
    # 3) Fetch all material IDs first
    # =========================
    material_rows = db.execute(
        text("""
            SELECT id
            FROM materials
            WHERE module_id = :module_id
            ORDER BY id ASC
        """),
        {"module_id": module_id},
    ).mappings().all()

    material_ids = [int(row["id"]) for row in material_rows]

    try:
        # =========================
        # 4) Delete all module materials safely
        # =========================
        for material_id in material_ids:
            _delete_material_internal(
                material_id=material_id,
                db=db,
                storage_bucket=settings.supabase_private_bucket,
            )

        # =========================
        # 5) Delete module row
        # =========================
        deleted_module = db.execute(
            text("""
                DELETE FROM modules
                WHERE id = :module_id
                  AND course_id = :course_id
                RETURNING id
            """),
            {
                "module_id": module_id,
                "course_id": course_id,
            },
        ).mappings().first()

        if not deleted_module:
            db.rollback()
            raise HTTPException(status_code=404, detail="Module not found")

        db.commit()
        return None

    except HTTPException:
        db.rollback()
        raise

    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=409, detail="Conflict while deleting module") from e

    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error") from e

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e)) from e