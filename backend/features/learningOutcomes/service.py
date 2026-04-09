from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError

from .schemas import (LearningOutcomeCreateRequest, 
                      LearningOutcomeUpdateRequest)



def create_learning_outcome(*, course_id: int, payload: LearningOutcomeCreateRequest, db: Session, current_user: dict,):
    # =========================
    # 1) Authorization
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can create learning outcomes")

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

    if int(course_row["created_by"]) != int(instructor_id):
        raise HTTPException(
            status_code=403,
            detail="You can only create learning outcomes for your own course"
        )

    # =========================
    # 3) Prepare fields
    # =========================
    title = (payload.title or "").strip()
    if not title:
        raise HTTPException(status_code=422, detail="title is required")

    description = payload.description
    if isinstance(description, str):
        description = description.strip() or None

    level = (payload.level or "").strip()
    if not level:
        raise HTTPException(status_code=422, detail="level is required")

    topic_ids = payload.topic_ids or []

    # remove duplicates while preserving order
    seen = set()
    normalized_topic_ids = []
    for topic_id in topic_ids:
        if not isinstance(topic_id, int) or topic_id <= 0:
            raise HTTPException(status_code=422, detail="topic_ids must contain valid positive integers")
        if topic_id not in seen:
            seen.add(topic_id)
            normalized_topic_ids.append(topic_id)

    # =========================
    # 4) Validate topics belong to same course
    # =========================
    if normalized_topic_ids:
        topic_rows = db.execute(
            text("""
                SELECT
                    t.id,
                    m.module_id,
                    mo.course_id
                FROM topics t
                JOIN materials m
                  ON m.id = t.material_id
                JOIN modules mo
                  ON mo.id = m.module_id
                WHERE t.id = ANY(:topic_ids)
            """),
            {"topic_ids": normalized_topic_ids},
        ).mappings().all()

        if len(topic_rows) != len(normalized_topic_ids):
            raise HTTPException(status_code=404, detail="One or more topics were not found")

        for row in topic_rows:
            if int(row["course_id"]) != int(course_id):
                raise HTTPException(
                    status_code=400,
                    detail="All topics must belong to the same course"
                )

    # =========================
    # 5) Insert learning outcome
    # =========================
    try:
        learning_outcome_row = db.execute(
            text("""
                INSERT INTO learning_outcomes (
                    course_id,
                    title,
                    description,
                    level,
                    is_ai_generated,
                    is_reviewed,
                    created_at,
                    updated_at
                )
                VALUES (
                    :course_id,
                    :title,
                    :description,
                    :level,
                    :is_ai_generated,
                    :is_reviewed,
                    NOW(),
                    NOW()
                )
                RETURNING
                    id,
                    course_id,
                    title,
                    description,
                    level,
                    is_ai_generated,
                    is_reviewed,
                    created_at,
                    updated_at
            """),
            {
                "course_id": course_id,
                "title": title,
                "description": description,
                "level": level,
                "is_ai_generated": False,
                "is_reviewed": True,
            },
        ).mappings().first()

        if not learning_outcome_row:
            db.rollback()
            raise HTTPException(status_code=503, detail="Failed to create learning outcome")

        learning_outcome_id = int(learning_outcome_row["id"])

        # =========================
        # 6) Insert topic relations (optional)
        # =========================
        if normalized_topic_ids:
            for topic_id in normalized_topic_ids:
                db.execute(
                    text("""
                        INSERT INTO topic_learning_outcomes (
                            topic_id,
                            learning_outcome_id,
                            created_at
                        )
                        VALUES (
                            :topic_id,
                            :learning_outcome_id,
                            NOW()
                        )
                    """),
                    {
                        "topic_id": topic_id,
                        "learning_outcome_id": learning_outcome_id,
                    },
                )

        db.commit()
        return dict(learning_outcome_row)

    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=409, detail="Conflict while creating learning outcome") from e

    except HTTPException:
        db.rollback()
        raise

    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error") from e
    


def list_learning_outcomes(*, course_id: int, db: Session, current_user: dict,):
    # =========================
    # 1) Authentication
    # =========================
    user_id = current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    role = (current_user.get("system_role") or "").strip().lower()

    try:
        # =========================
        # 2) Validate course exists
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

        # =========================
        # 3) Authorization
        # =========================
        if role == "instructor":
            if int(course_row["created_by"]) != int(user_id):
                raise HTTPException(
                    status_code=403,
                    detail="You can only view learning outcomes for your own course"
                )

        elif role == "student":
            enrollment_row = db.execute(
                text("""
                    SELECT 1
                    FROM course_enrollments
                    WHERE course_id = :course_id
                      AND student_id = :student_id
                      AND status IN ('active', 'completed')
                    LIMIT 1
                """),
                {
                    "course_id": course_id,
                    "student_id": user_id,
                },
            ).first()

            if not enrollment_row:
                raise HTTPException(
                    status_code=403,
                    detail="You are not allowed to access learning outcomes for this course"
                )

        else:
            raise HTTPException(status_code=403, detail="Access denied")

        # =========================
        # 4) Fetch learning outcomes
        # =========================
        learning_outcome_rows = db.execute(
            text("""
                SELECT
                    id,
                    course_id,
                    title,
                    description,
                    level,
                    is_ai_generated,
                    is_reviewed,
                    created_at,
                    updated_at
                FROM learning_outcomes
                WHERE course_id = :course_id
                ORDER BY created_at ASC, id ASC
            """),
            {"course_id": course_id},
        ).mappings().all()

        return {
            "course_id": course_id,
            "learning_outcomes": [dict(row) for row in learning_outcome_rows],
        }

    except HTTPException:
        raise

    except SQLAlchemyError as e:
        raise HTTPException(status_code=500, detail="Database error") from e



def get_learning_outcome(*, course_id: int, learning_outcome_id: int, db: Session, current_user: dict,):
    # =========================
    # 1) Authentication
    # =========================
    user_id = current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    if not learning_outcome_id or learning_outcome_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid learning_outcome_id")

    role = (current_user.get("system_role") or "").strip().lower()

    try:
        # =========================
        # 2) Validate course exists
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

        # =========================
        # 3) Authorization
        # =========================
        if role == "instructor":
            if int(course_row["created_by"]) != int(user_id):
                raise HTTPException(
                    status_code=403,
                    detail="You can only view learning outcomes for your own course"
                )

        elif role == "student":
            enrollment_row = db.execute(
                text("""
                    SELECT 1
                    FROM course_enrollments
                    WHERE course_id = :course_id
                      AND student_id = :student_id
                      AND status IN ('active', 'completed')
                    LIMIT 1
                """),
                {
                    "course_id": course_id,
                    "student_id": user_id,
                },
            ).first()

            if not enrollment_row:
                raise HTTPException(
                    status_code=403,
                    detail="You are not allowed to access learning outcomes for this course"
                )

        else:
            raise HTTPException(status_code=403, detail="Access denied")

        # =========================
        # 4) Fetch learning outcome
        # =========================
        learning_outcome_row = db.execute(
            text("""
                SELECT
                    id,
                    course_id,
                    title,
                    description,
                    level,
                    is_ai_generated,
                    is_reviewed,
                    created_at,
                    updated_at
                FROM learning_outcomes
                WHERE id = :learning_outcome_id
                  AND course_id = :course_id
                LIMIT 1
            """),
            {
                "learning_outcome_id": learning_outcome_id,
                "course_id": course_id,
            },
        ).mappings().first()

        if not learning_outcome_row:
            raise HTTPException(status_code=404, detail="Learning outcome not found")

        # =========================
        # 5) Fetch related topics
        # =========================
        topic_rows = db.execute(
            text("""
                SELECT
                    t.id,
                    t.title
                FROM topic_learning_outcomes tlo
                JOIN topics t
                  ON t.id = tlo.topic_id
                JOIN materials m
                  ON m.id = t.material_id
                JOIN modules mo
                  ON mo.id = m.module_id
                WHERE tlo.learning_outcome_id = :learning_outcome_id
                  AND mo.course_id = :course_id
                ORDER BY t.order_index ASC, t.id ASC
            """),
            {
                "learning_outcome_id": learning_outcome_id,
                "course_id": course_id,
            },
        ).mappings().all()

        response = dict(learning_outcome_row)
        response["topics"] = [dict(row) for row in topic_rows]

        return response

    except HTTPException:
        raise

    except SQLAlchemyError as e:
        raise HTTPException(status_code=500, detail="Database error") from e



def update_learning_outcome(*, course_id: int, learning_outcome_id: int, payload: LearningOutcomeUpdateRequest, db: Session, current_user: dict,):
    # =========================
    # 1) Authorization
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can update learning outcomes")

    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    if not learning_outcome_id or learning_outcome_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid learning_outcome_id")

    # =========================
    # 2) Validate learning outcome -> course + ownership
    # =========================
    learning_outcome_row = db.execute(
        text("""
            SELECT
                lo.id,
                lo.course_id,
                c.created_by
            FROM learning_outcomes lo
            JOIN courses c
              ON c.id = lo.course_id
            WHERE lo.id = :learning_outcome_id
            LIMIT 1
        """),
        {"learning_outcome_id": learning_outcome_id},
    ).mappings().first()

    if not learning_outcome_row:
        raise HTTPException(status_code=404, detail="Learning outcome not found")

    if int(learning_outcome_row["course_id"]) != int(course_id):
        raise HTTPException(status_code=400, detail="Learning outcome does not belong to this course")

    if int(learning_outcome_row["created_by"]) != int(instructor_id):
        raise HTTPException(
            status_code=403,
            detail="You can only update learning outcomes in your own course"
        )

    # =========================
    # 3) Build dynamic update fields
    # =========================
    update_fields = {}
    provided_fields = payload.model_fields_set

    if "title" in provided_fields and payload.title is not None:
        title = payload.title.strip()
        if title == "":
            raise HTTPException(status_code=422, detail="title cannot be empty")
        update_fields["title"] = title

    if "description" in provided_fields and payload.description is not None:
        description = payload.description.strip()
        update_fields["description"] = description or None

    if "level" in provided_fields and payload.level is not None:
        level = payload.level.strip()
        if level == "":
            raise HTTPException(status_code=422, detail="level cannot be empty")
        update_fields["level"] = level

    # =========================
    # 4) Validate topics if provided
    # =========================
    replace_topics = False
    normalized_topic_ids = []

    if "topic_ids" in provided_fields and payload.topic_ids is not None:
        replace_topics = True

        seen = set()
        for topic_id in payload.topic_ids:
            if not isinstance(topic_id, int) or topic_id <= 0:
                raise HTTPException(
                    status_code=422,
                    detail="topic_ids must contain valid positive integers"
                )
            if topic_id not in seen:
                seen.add(topic_id)
                normalized_topic_ids.append(topic_id)

        if normalized_topic_ids:
            topic_rows = db.execute(
                text("""
                    SELECT
                        t.id,
                        mo.course_id
                    FROM topics t
                    JOIN materials m
                      ON m.id = t.material_id
                    JOIN modules mo
                      ON mo.id = m.module_id
                    WHERE t.id = ANY(:topic_ids)
                """),
                {"topic_ids": normalized_topic_ids},
            ).mappings().all()

            if len(topic_rows) != len(normalized_topic_ids):
                raise HTTPException(status_code=404, detail="One or more topics were not found")

            for row in topic_rows:
                if int(row["course_id"]) != int(course_id):
                    raise HTTPException(
                        status_code=400,
                        detail="All topics must belong to the same course"
                    )

    if not update_fields and not replace_topics:
        raise HTTPException(status_code=400, detail="No updatable fields provided")

    # =========================
    # 5) Update learning outcome + optional relations replacement
    # =========================
    try:
        updated_learning_outcome = None

        if update_fields:
            set_clauses = []
            params = {"learning_outcome_id": learning_outcome_id}

            for col in ["title", "description", "level"]:
                if col in update_fields:
                    set_clauses.append(f"{col} = :{col}")
                    params[col] = update_fields[col]

            set_clauses.append("updated_at = NOW()")

            updated_learning_outcome = db.execute(
                text(f"""
                    UPDATE learning_outcomes
                    SET {", ".join(set_clauses)}
                    WHERE id = :learning_outcome_id
                    RETURNING
                        id,
                        course_id,
                        title,
                        description,
                        level,
                        is_ai_generated,
                        is_reviewed,
                        created_at,
                        updated_at
                """),
                params,
            ).mappings().first()

            if not updated_learning_outcome:
                db.rollback()
                raise HTTPException(status_code=404, detail="Learning outcome not found")
        else:
            updated_learning_outcome = db.execute(
                text("""
                    SELECT
                        id,
                        course_id,
                        title,
                        description,
                        level,
                        is_ai_generated,
                        is_reviewed,
                        created_at,
                        updated_at
                    FROM learning_outcomes
                    WHERE id = :learning_outcome_id
                    LIMIT 1
                """),
                {"learning_outcome_id": learning_outcome_id},
            ).mappings().first()

            if not updated_learning_outcome:
                db.rollback()
                raise HTTPException(status_code=404, detail="Learning outcome not found")

        if replace_topics:
            db.execute(
                text("""
                    DELETE FROM topic_learning_outcomes
                    WHERE learning_outcome_id = :learning_outcome_id
                """),
                {"learning_outcome_id": learning_outcome_id},
            )

            for topic_id in normalized_topic_ids:
                db.execute(
                    text("""
                        INSERT INTO topic_learning_outcomes (
                            topic_id,
                            learning_outcome_id,
                            created_at
                        )
                        VALUES (
                            :topic_id,
                            :learning_outcome_id,
                            NOW()
                        )
                    """),
                    {
                        "topic_id": topic_id,
                        "learning_outcome_id": learning_outcome_id,
                    },
                )

        db.commit()
        return dict(updated_learning_outcome)

    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=409, detail="Conflict while updating learning outcome") from e

    except HTTPException:
        db.rollback()
        raise

    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error") from e
    


def delete_learning_outcome(*, course_id: int, learning_outcome_id: int, db: Session, current_user: dict,):
    # =========================
    # 1) Authorization
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can delete learning outcomes")

    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    if not learning_outcome_id or learning_outcome_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid learning_outcome_id")

    try:
        # =========================
        # 2) Validate learning outcome -> course + ownership
        # =========================
        learning_outcome_row = db.execute(
            text("""
                SELECT
                    lo.id,
                    lo.course_id,
                    c.created_by
                FROM learning_outcomes lo
                JOIN courses c
                  ON c.id = lo.course_id
                WHERE lo.id = :learning_outcome_id
                LIMIT 1
            """),
            {"learning_outcome_id": learning_outcome_id},
        ).mappings().first()

        if not learning_outcome_row:
            raise HTTPException(status_code=404, detail="Learning outcome not found")

        if int(learning_outcome_row["course_id"]) != int(course_id):
            raise HTTPException(status_code=400, detail="Learning outcome does not belong to this course")

        if int(learning_outcome_row["created_by"]) != int(instructor_id):
            raise HTTPException(
                status_code=403,
                detail="You can only delete learning outcomes from your own course"
            )

        # =========================
        # 3) Delete relations first
        # =========================
        db.execute(
            text("""
                DELETE FROM topic_learning_outcomes
                WHERE learning_outcome_id = :learning_outcome_id
            """),
            {"learning_outcome_id": learning_outcome_id},
        )

        # =========================
        # 4) Delete learning outcome
        # =========================
        deleted_row = db.execute(
            text("""
                DELETE FROM learning_outcomes
                WHERE id = :learning_outcome_id
                RETURNING id
            """),
            {"learning_outcome_id": learning_outcome_id},
        ).first()

        if not deleted_row:
            db.rollback()
            raise HTTPException(status_code=404, detail="Learning outcome not found")

        db.commit()

    except HTTPException:
        db.rollback()
        raise

    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error") from e