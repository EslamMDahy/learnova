from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError

from .schemas import (TopicCreateRequest
                     ,TopicUpdateRequest)

def create_topic(*, course_id: int, module_id: int, material_id: int, payload: TopicCreateRequest, db: Session, current_user: dict,):
    # =========================
    # 1) Authorization
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can create topics")

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
    # 2) Validate material -> module -> course + ownership
    # =========================
    material_row = db.execute(
        text("""
            SELECT
                m.id AS material_id,
                m.module_id,
                mo.course_id,
                c.created_by
            FROM materials m
            JOIN modules mo
              ON mo.id = m.module_id
            JOIN courses c
              ON c.id = mo.course_id
            WHERE m.id = :material_id
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
        raise HTTPException(status_code=403, detail="You can only manage topics for your own course")

    # =========================
    # 3) Prepare fields
    # =========================
    title = (payload.title or "").strip()
    if not title:
        raise HTTPException(status_code=422, detail="title is required")

    description = payload.description
    if isinstance(description, str):
        description = description.strip() or None

    parent_topic_id = payload.parent_topic_id
    learning_outcome_ids = payload.learning_outcome_ids or []

    # remove duplicates while preserving order
    seen = set()
    normalized_learning_outcome_ids = []
    for lo_id in learning_outcome_ids:
        if not isinstance(lo_id, int) or lo_id <= 0:
            raise HTTPException(status_code=422, detail="learning_outcome_ids must contain valid positive integers")
        if lo_id not in seen:
            seen.add(lo_id)
            normalized_learning_outcome_ids.append(lo_id)

    # =========================
    # 4) Validate parent_topic_id (if provided)
    # =========================
    if parent_topic_id is not None:
        parent_row = db.execute(
            text("""
                SELECT id, material_id
                FROM topics
                WHERE id = :parent_topic_id
                LIMIT 1
            """),
            {"parent_topic_id": parent_topic_id},
        ).mappings().first()

        if not parent_row:
            raise HTTPException(status_code=404, detail="Parent topic not found")

        if int(parent_row["material_id"]) != int(material_id):
            raise HTTPException(status_code=400, detail="Parent topic must belong to the same material")

    # =========================
    # 5) Validate learning outcomes belong to same course
    # =========================
    if normalized_learning_outcome_ids:
        lo_rows = db.execute(
            text("""
                SELECT id, course_id
                FROM learning_outcomes
                WHERE id = ANY(:learning_outcome_ids)
            """),
            {"learning_outcome_ids": normalized_learning_outcome_ids},
        ).mappings().all()

        if len(lo_rows) != len(normalized_learning_outcome_ids):
            raise HTTPException(status_code=404, detail="One or more learning outcomes were not found")

        for row in lo_rows:
            if int(row["course_id"]) != int(course_id):
                raise HTTPException(
                    status_code=400,
                    detail="All learning outcomes must belong to the same course"
                )

    # =========================
    # 6) Compute order_index inside same material
    # =========================
    next_order_index = db.execute(
        text("""
            SELECT COALESCE(MAX(order_index), -1) + 1 AS next_idx
            FROM topics
            WHERE material_id = :material_id
        """),
        {"material_id": material_id},
    ).scalar()

    if next_order_index is None:
        next_order_index = 0

    # =========================
    # 7) Insert topic
    # =========================
    try:
        topic_row = db.execute(
            text("""
                INSERT INTO topics (
                    material_id,
                    title,
                    description,
                    order_index,
                    parent_topic_id,
                    is_ai_generated,
                    is_reviewed,
                    created_at,
                    updated_at
                )
                VALUES (
                    :material_id,
                    :title,
                    :description,
                    :order_index,
                    :parent_topic_id,
                    :is_ai_generated,
                    :is_reviewed,
                    NOW(),
                    NOW()
                )
                RETURNING
                    id,
                    material_id,
                    title,
                    description,
                    order_index,
                    parent_topic_id,
                    is_ai_generated,
                    is_reviewed,
                    created_at,
                    updated_at
            """),
            {
                "material_id": material_id,
                "title": title,
                "description": description,
                "order_index": int(next_order_index),
                "parent_topic_id": parent_topic_id,
                "is_ai_generated": False,
                "is_reviewed": True,
            },
        ).mappings().first()

        if not topic_row:
            db.rollback()
            raise HTTPException(status_code=503, detail="Failed to create topic")

        topic_id = int(topic_row["id"])

        # =========================
        # 8) Insert topic-learning_outcome relations (optional)
        # =========================
        if normalized_learning_outcome_ids:
            for lo_id in normalized_learning_outcome_ids:
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
                        "learning_outcome_id": lo_id,
                    },
                )

        db.commit()
        return dict(topic_row)

    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=409, detail="Conflict while creating topic") from e

    except HTTPException:
        db.rollback()
        raise

    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error") from e
    


def list_material_topics(*, course_id: int, module_id: int, material_id: int, db: Session, current_user: dict,):
    # =========================
    # 1) Authentication
    # =========================
    user_id = current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    if not module_id or module_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid module_id")

    if not material_id or material_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid material_id")

    role = (current_user.get("system_role") or "").strip().lower()

    try:
        # =========================
        # 2) Validate material -> module -> course
        # =========================
        material_row = db.execute(
            text("""
                SELECT
                    m.id AS material_id,
                    m.module_id,
                    mo.course_id,
                    c.created_by
                FROM materials m
                JOIN modules mo
                  ON mo.id = m.module_id
                JOIN courses c
                  ON c.id = mo.course_id
                WHERE m.id = :material_id
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

        # =========================
        # 3) Authorization
        # =========================
        if role == "instructor":
            if int(material_row["created_by"]) != int(user_id):
                raise HTTPException(
                    status_code=403,
                    detail="You can only view topics for your own course"
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
                    detail="You are not allowed to access topics for this course"
                )

        else:
            raise HTTPException(status_code=403, detail="Access denied")

        # =========================
        # 4) Fetch all topics for this material
        # =========================
        topic_rows = db.execute(
            text("""
                SELECT
                    id,
                    material_id,
                    title,
                    description,
                    order_index,
                    parent_topic_id,
                    is_ai_generated,
                    is_reviewed,
                    created_at,
                    updated_at
                FROM topics
                WHERE material_id = :material_id
                ORDER BY order_index ASC, id ASC
            """),
            {"material_id": material_id},
        ).mappings().all()

        return {
            "course_id": course_id,
            "module_id": module_id,
            "material_id": material_id,
            "topics": [dict(row) for row in topic_rows],
        }

    except HTTPException:
        raise

    except SQLAlchemyError as e:
        raise HTTPException(status_code=500, detail="Database error") from e



def get_topic(*, course_id: int, module_id: int, material_id: int, topic_id: int, db: Session, current_user: dict,):
    # =========================
    # 1) Authentication
    # =========================
    user_id = current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    if not module_id or module_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid module_id")

    if not material_id or material_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid material_id")

    if not topic_id or topic_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid topic_id")

    role = (current_user.get("system_role") or "").strip().lower()

    try:
        # =========================
        # 2) Validate topic -> material -> module -> course
        # =========================
        topic_row = db.execute(
            text("""
                SELECT
                    t.id,
                    t.material_id,
                    t.title,
                    t.description,
                    t.order_index,
                    t.parent_topic_id,
                    t.is_ai_generated,
                    t.is_reviewed,
                    t.created_at,
                    t.updated_at,
                    m.module_id,
                    mo.course_id,
                    c.created_by
                FROM topics t
                JOIN materials m
                  ON m.id = t.material_id
                JOIN modules mo
                  ON mo.id = m.module_id
                JOIN courses c
                  ON c.id = mo.course_id
                WHERE t.id = :topic_id
                LIMIT 1
            """),
            {"topic_id": topic_id},
        ).mappings().first()

        if not topic_row:
            raise HTTPException(status_code=404, detail="Topic not found")

        if int(topic_row["material_id"]) != int(material_id):
            raise HTTPException(status_code=400, detail="Topic does not belong to this material")

        if int(topic_row["module_id"]) != int(module_id):
            raise HTTPException(status_code=400, detail="Topic does not belong to this module")

        if int(topic_row["course_id"]) != int(course_id):
            raise HTTPException(status_code=400, detail="Topic does not belong to this course")

        # =========================
        # 3) Authorization
        # =========================
        if role == "instructor":
            if int(topic_row["created_by"]) != int(user_id):
                raise HTTPException(
                    status_code=403,
                    detail="You can only view topics for your own course"
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
                    detail="You are not allowed to access topics for this course"
                )

        else:
            raise HTTPException(status_code=403, detail="Access denied")

        # =========================
        # 4) Fetch related learning outcomes
        # =========================
        learning_outcome_rows = db.execute(
            text("""
                SELECT
                    lo.id,
                    lo.title
                FROM topic_learning_outcomes tlo
                JOIN learning_outcomes lo
                  ON lo.id = tlo.learning_outcome_id
                WHERE tlo.topic_id = :topic_id
                  AND lo.course_id = :course_id
                ORDER BY lo.created_at ASC, lo.id ASC
            """),
            {
                "topic_id": topic_id,
                "course_id": course_id,
            },
        ).mappings().all()

        response = {
            "id": topic_row["id"],
            "material_id": topic_row["material_id"],
            "title": topic_row["title"],
            "description": topic_row["description"],
            "order_index": topic_row["order_index"],
            "parent_topic_id": topic_row["parent_topic_id"],
            "is_ai_generated": topic_row["is_ai_generated"],
            "is_reviewed": topic_row["is_reviewed"],
            "created_at": topic_row["created_at"],
            "updated_at": topic_row["updated_at"],
            "learning_outcomes": [dict(row) for row in learning_outcome_rows],
        }

        return response

    except HTTPException:
        raise

    except SQLAlchemyError as e:
        raise HTTPException(status_code=500, detail="Database error") from e



def update_topic(*, course_id: int, module_id: int, material_id: int, topic_id: int, payload: TopicUpdateRequest, db: Session, current_user: dict,):
    # =========================
    # 1) Authorization
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can update topics")

    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    if not module_id or module_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid module_id")

    if not material_id or material_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid material_id")

    if not topic_id or topic_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid topic_id")

    # =========================
    # 2) Validate topic -> material -> module -> course + ownership
    # =========================
    topic_row = db.execute(
        text("""
            SELECT
                t.id,
                t.material_id,
                t.parent_topic_id,
                m.module_id,
                mo.course_id,
                c.created_by
            FROM topics t
            JOIN materials m
              ON m.id = t.material_id
            JOIN modules mo
              ON mo.id = m.module_id
            JOIN courses c
              ON c.id = mo.course_id
            WHERE t.id = :topic_id
            LIMIT 1
        """),
        {"topic_id": topic_id},
    ).mappings().first()

    if not topic_row:
        raise HTTPException(status_code=404, detail="Topic not found")

    if int(topic_row["material_id"]) != int(material_id):
        raise HTTPException(status_code=400, detail="Topic does not belong to this material")

    if int(topic_row["module_id"]) != int(module_id):
        raise HTTPException(status_code=400, detail="Topic does not belong to this module")

    if int(topic_row["course_id"]) != int(course_id):
        raise HTTPException(status_code=400, detail="Topic does not belong to this course")

    if int(topic_row["created_by"]) != int(instructor_id):
        raise HTTPException(status_code=403, detail="You can only update topics in your own course")

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

    if "parent_topic_id" in provided_fields and payload.parent_topic_id is not None:
        parent_topic_id = payload.parent_topic_id

        if int(parent_topic_id) == int(topic_id):
            raise HTTPException(status_code=400, detail="A topic cannot be its own parent")

        parent_row = db.execute(
            text("""
                SELECT id, material_id, parent_topic_id
                FROM topics
                WHERE id = :parent_topic_id
                LIMIT 1
            """),
            {"parent_topic_id": parent_topic_id},
        ).mappings().first()

        if not parent_row:
            raise HTTPException(status_code=404, detail="Parent topic not found")

        if int(parent_row["material_id"]) != int(material_id):
            raise HTTPException(status_code=400, detail="Parent topic must belong to the same material")

        # prevent simple cycle: parent cannot be one of this topic's descendants
        ancestor_id = parent_row["parent_topic_id"]
        current_parent_id = int(parent_topic_id)

        while ancestor_id is not None:
            if int(ancestor_id) == int(topic_id):
                raise HTTPException(status_code=400, detail="Invalid parent_topic_id: cycle detected")

            ancestor_row = db.execute(
                text("""
                    SELECT parent_topic_id
                    FROM topics
                    WHERE id = :topic_id
                    LIMIT 1
                """),
                {"topic_id": current_parent_id},
            ).mappings().first()

            if not ancestor_row:
                break

            current_parent_id = ancestor_id
            ancestor_id = ancestor_row["parent_topic_id"]

        update_fields["parent_topic_id"] = parent_topic_id

    # =========================
    # 4) Validate learning outcomes if provided
    # =========================
    replace_learning_outcomes = False
    normalized_learning_outcome_ids = []

    if "learning_outcome_ids" in provided_fields and payload.learning_outcome_ids is not None:
        replace_learning_outcomes = True

        seen = set()
        for lo_id in payload.learning_outcome_ids:
            if not isinstance(lo_id, int) or lo_id <= 0:
                raise HTTPException(
                    status_code=422,
                    detail="learning_outcome_ids must contain valid positive integers"
                )
            if lo_id not in seen:
                seen.add(lo_id)
                normalized_learning_outcome_ids.append(lo_id)

        if normalized_learning_outcome_ids:
            lo_rows = db.execute(
                text("""
                    SELECT id, course_id
                    FROM learning_outcomes
                    WHERE id = ANY(:learning_outcome_ids)
                """),
                {"learning_outcome_ids": normalized_learning_outcome_ids},
            ).mappings().all()

            if len(lo_rows) != len(normalized_learning_outcome_ids):
                raise HTTPException(status_code=404, detail="One or more learning outcomes were not found")

            for row in lo_rows:
                if int(row["course_id"]) != int(course_id):
                    raise HTTPException(
                        status_code=400,
                        detail="All learning outcomes must belong to the same course"
                    )

    if not update_fields and not replace_learning_outcomes:
        raise HTTPException(status_code=400, detail="No updatable fields provided")

    # =========================
    # 5) Update topic + optional relations replacement
    # =========================
    try:
        updated_topic = None

        if update_fields:
            set_clauses = []
            params = {"topic_id": topic_id}

            for col in ["title", "description", "parent_topic_id"]:
                if col in update_fields:
                    set_clauses.append(f"{col} = :{col}")
                    params[col] = update_fields[col]

            set_clauses.append("updated_at = NOW()")

            updated_topic = db.execute(
                text(f"""
                    UPDATE topics
                    SET {", ".join(set_clauses)}
                    WHERE id = :topic_id
                    RETURNING
                        id,
                        material_id,
                        title,
                        description,
                        order_index,
                        parent_topic_id,
                        is_ai_generated,
                        is_reviewed,
                        created_at,
                        updated_at
                """),
                params,
            ).mappings().first()

            if not updated_topic:
                db.rollback()
                raise HTTPException(status_code=404, detail="Topic not found")
        else:
            updated_topic = db.execute(
                text("""
                    SELECT
                        id,
                        material_id,
                        title,
                        description,
                        order_index,
                        parent_topic_id,
                        is_ai_generated,
                        is_reviewed,
                        created_at,
                        updated_at
                    FROM topics
                    WHERE id = :topic_id
                    LIMIT 1
                """),
                {"topic_id": topic_id},
            ).mappings().first()

            if not updated_topic:
                db.rollback()
                raise HTTPException(status_code=404, detail="Topic not found")

        if replace_learning_outcomes:
            db.execute(
                text("""
                    DELETE FROM topic_learning_outcomes
                    WHERE topic_id = :topic_id
                """),
                {"topic_id": topic_id},
            )

            for lo_id in normalized_learning_outcome_ids:
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
                        "learning_outcome_id": lo_id,
                    },
                )

        db.commit()
        return dict(updated_topic)

    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=409, detail="Conflict while updating topic") from e

    except HTTPException:
        db.rollback()
        raise

    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error") from e
    


def reorder_topics(*, course_id: int, module_id: int, material_id: int, payload, db: Session, current_user: dict,):
    # =========================
    # 1) Authorization
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can reorder topics")

    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    if not module_id or module_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid module_id")

    if not material_id or material_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid material_id")

    topic_ids = getattr(payload, "topic_ids", None)
    if not isinstance(topic_ids, list) or not topic_ids:
        raise HTTPException(status_code=400, detail="topic_ids must be a non-empty list")

    try:
        topic_ids = [int(tid) for tid in topic_ids]
    except Exception:
        raise HTTPException(status_code=400, detail="topic_ids must contain valid integers")

    if any(tid <= 0 for tid in topic_ids):
        raise HTTPException(status_code=400, detail="topic_ids must contain positive integers only")

    if len(topic_ids) != len(set(topic_ids)):
        raise HTTPException(status_code=400, detail="topic_ids must not contain duplicates")

    # =========================
    # 2) Validate material -> module -> course + ownership
    # =========================
    material_row = db.execute(
        text("""
            SELECT
                m.id AS material_id,
                m.module_id,
                mo.course_id,
                c.created_by
            FROM materials m
            JOIN modules mo
              ON mo.id = m.module_id
            JOIN courses c
              ON c.id = mo.course_id
            WHERE m.id = :material_id
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
        raise HTTPException(status_code=403, detail="You can only reorder topics for your own course")

    # =========================
    # 3) Fetch all material topics
    # =========================
    db_topic_rows = db.execute(
        text("""
            SELECT id
            FROM topics
            WHERE material_id = :material_id
            ORDER BY order_index ASC, id ASC
        """),
        {"material_id": material_id},
    ).mappings().all()

    db_topic_ids = [int(row["id"]) for row in db_topic_rows]

    if not db_topic_ids:
        raise HTTPException(status_code=404, detail="No topics found for this material")

    # request must include all material topics exactly once
    if set(topic_ids) != set(db_topic_ids):
        raise HTTPException(
            status_code=400,
            detail="topic_ids must include all material topics exactly once"
        )

    # =========================
    # 4) Reorder with two-phase update
    #    to avoid unique conflict on (material_id, order_index)
    # =========================
    try:
        # phase 1: move to temporary negative order values
        for idx, topic_id in enumerate(topic_ids):
            db.execute(
                text("""
                    UPDATE topics
                    SET order_index = :temp_order_index,
                        updated_at = NOW()
                    WHERE id = :topic_id
                      AND material_id = :material_id
                """),
                {
                    "temp_order_index": -(idx + 1),
                    "topic_id": topic_id,
                    "material_id": material_id,
                },
            )

        # phase 2: assign final order values
        for idx, topic_id in enumerate(topic_ids):
            db.execute(
                text("""
                    UPDATE topics
                    SET order_index = :final_order_index,
                        updated_at = NOW()
                    WHERE id = :topic_id
                      AND material_id = :material_id
                """),
                {
                    "final_order_index": idx,
                    "topic_id": topic_id,
                    "material_id": material_id,
                },
            )

        db.commit()

        return {
            "course_id": course_id,
            "module_id": module_id,
            "material_id": material_id,
            "topic_ids": topic_ids,
        }

    except HTTPException:
        db.rollback()
        raise

    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error") from e



def delete_topic(*, course_id: int, module_id: int, material_id: int, topic_id: int, db: Session, current_user: dict,):
    # =========================
    # 1) Authorization
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can delete topics")

    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    if not module_id or module_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid module_id")

    if not material_id or material_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid material_id")

    if not topic_id or topic_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid topic_id")

    try:
        # =========================
        # 2) Validate topic -> material -> module -> course + ownership
        # =========================
        topic_row = db.execute(
            text("""
                SELECT
                    t.id,
                    t.material_id,
                    m.module_id,
                    mo.course_id,
                    c.created_by
                FROM topics t
                JOIN materials m
                  ON m.id = t.material_id
                JOIN modules mo
                  ON mo.id = m.module_id
                JOIN courses c
                  ON c.id = mo.course_id
                WHERE t.id = :topic_id
                LIMIT 1
            """),
            {"topic_id": topic_id},
        ).mappings().first()

        if not topic_row:
            raise HTTPException(status_code=404, detail="Topic not found")

        if int(topic_row["material_id"]) != int(material_id):
            raise HTTPException(status_code=400, detail="Topic does not belong to this material")

        if int(topic_row["module_id"]) != int(module_id):
            raise HTTPException(status_code=400, detail="Topic does not belong to this module")

        if int(topic_row["course_id"]) != int(course_id):
            raise HTTPException(status_code=400, detail="Topic does not belong to this course")

        if int(topic_row["created_by"]) != int(instructor_id):
            raise HTTPException(status_code=403, detail="You can only delete topics from your own course")

        # =========================
        # 3) Delete topic relations first
        # =========================
        db.execute(
            text("""
                DELETE FROM topic_learning_outcomes
                WHERE topic_id = :topic_id
            """),
            {"topic_id": topic_id},
        )

        # =========================
        # 4) Delete topic
        # =========================
        deleted_row = db.execute(
            text("""
                DELETE FROM topics
                WHERE id = :topic_id
                RETURNING id
            """),
            {"topic_id": topic_id},
        ).first()

        if not deleted_row:
            db.rollback()
            raise HTTPException(status_code=404, detail="Topic not found")

        db.commit()

    except HTTPException:
        db.rollback()
        raise

    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error") from e
    

