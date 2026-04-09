from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
import json

from .schemas import QuestionCreateRequest
from .helpers import validate_and_normalize_question_payload


def create_question(*, course_id: int, payload: QuestionCreateRequest, db: Session, current_user: dict,):
    # =========================
    # 1) Authorization
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can create questions")

    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    topic_id = payload.topic_id
    if not topic_id or topic_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid topic_id")

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
            detail="You can only create questions for your own course"
        )

    # =========================
    # 3) Validate topic belongs to same course
    # =========================
    topic_row = db.execute(
        text("""
            SELECT
                t.id,
                mo.course_id
            FROM topics t
            JOIN materials m
              ON m.id = t.material_id
            JOIN modules mo
              ON mo.id = m.module_id
            WHERE t.id = :topic_id
            LIMIT 1
        """),
        {"topic_id": topic_id},
    ).mappings().first()

    if not topic_row:
        raise HTTPException(status_code=404, detail="Topic not found")

    if int(topic_row["course_id"]) != int(course_id):
        raise HTTPException(status_code=400, detail="Topic does not belong to this course")

    # =========================
    # 4) Type-specific validation + normalization
    # =========================
    validation_result = validate_and_normalize_question_payload(payload)
    if not validation_result["ok"]:
        raise HTTPException(
            status_code=validation_result["status_code"],
            detail=validation_result["detail"]
        )

    normalized_data = validation_result["data"]

    # =========================
    # 5) Insert question
    # =========================
    try:
        question_row = db.execute(
            text("""
                INSERT INTO questions (
                    course_id,
                    topic_id,
                    question_text,
                    explanation,
                    options,
                    type,
                    difficulty,
                    source,
                    approval_status,
                    expected_answer,
                    grading_rubric,
                    max_score,
                    auto_gradable,
                    usage_count,
                    success_rate,
                    average_time_seconds,
                    tags,
                    created_by,
                    created_at,
                    updated_at
                )
                VALUES (
                    :course_id,
                    :topic_id,
                    :question_text,
                    :explanation,
                    CAST(:options AS JSONB),
                    :type,
                    :difficulty,
                    :source,
                    :approval_status,
                    CAST(:expected_answer AS JSONB),
                    CAST(:grading_rubric AS JSONB),
                    :max_score,
                    :auto_gradable,
                    :usage_count,
                    :success_rate,
                    :average_time_seconds,
                    CAST(:tags AS JSONB),
                    :created_by,
                    NOW(),
                    NOW()
                )
                RETURNING
                    id,
                    course_id,
                    topic_id,
                    question_text,
                    explanation,
                    options,
                    type,
                    difficulty,
                    source,
                    approval_status,
                    expected_answer,
                    grading_rubric,
                    max_score,
                    auto_gradable,
                    usage_count,
                    success_rate,
                    average_time_seconds,
                    tags,
                    created_by,
                    created_at,
                    updated_at
            """),
            {
                "course_id": course_id,
                "topic_id": topic_id,
                "question_text": normalized_data["question_text"],
                "explanation": normalized_data["explanation"],
                "options": json.dumps(normalized_data["options"]),
                "type": normalized_data["type"],
                "difficulty": normalized_data["difficulty"],
                "source": normalized_data["source"],
                "approval_status": normalized_data["approval_status"],
                "expected_answer": json.dumps(normalized_data["expected_answer"]),
                "grading_rubric": (
                    json.dumps(normalized_data["grading_rubric"])
                    if normalized_data["grading_rubric"] is not None else None
                ),
                "max_score": normalized_data["max_score"],
                "auto_gradable": normalized_data["auto_gradable"],
                "usage_count": normalized_data["usage_count"],
                "success_rate": normalized_data["success_rate"],
                "average_time_seconds": normalized_data["average_time_seconds"],
                "tags": (
                    json.dumps(normalized_data["tags"])
                    if normalized_data["tags"] is not None else None
                ),
                "created_by": instructor_id,
            },
        ).mappings().first()

        if not question_row:
            db.rollback()
            raise HTTPException(status_code=503, detail="Failed to create question")

        db.commit()
        return dict(question_row)

    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=409, detail="Conflict while creating question") from e

    except HTTPException:
        db.rollback()
        raise

    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error") from e
    


def list_topic_questions(*, course_id: int, module_id: int, material_id: int, topic_id: int, db: Session, current_user: dict,):
    # =========================
    # 1) Authorization
    # =========================
    instructor_id = current_user.get("id")
    role = (current_user.get("system_role") or "").strip().lower()

    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can view questions")

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
            raise HTTPException(status_code=403, detail="You can only view questions for your own course")

        # =========================
        # 3) Fetch topic questions
        # =========================
        question_rows = db.execute(
            text("""
                SELECT
                    id,
                    course_id,
                    topic_id,
                    question_text,
                    options,
                    type,
                    difficulty,
                    source,
                    approval_status,
                    auto_gradable,
                    created_at,
                    updated_at
                FROM questions
                WHERE course_id = :course_id
                  AND topic_id = :topic_id
                ORDER BY created_at ASC, id ASC
            """),
            {
                "course_id": course_id,
                "topic_id": topic_id,
            },
        ).mappings().all()

        return {
            "course_id": course_id,
            "topic_id": topic_id,
            "questions": [dict(row) for row in question_rows],
        }

    except HTTPException:
        raise
    except SQLAlchemyError as e:
        raise HTTPException(status_code=500, detail="Database error") from e



def list_material_questions(*, course_id: int, module_id: int, material_id: int, db: Session, current_user: dict,):
    # =========================
    # 1) Authorization
    # =========================
    instructor_id = current_user.get("id")
    role = (current_user.get("system_role") or "").strip().lower()

    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can view questions")

    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")
    if not module_id or module_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid module_id")
    if not material_id or material_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid material_id")

    try:
        # =========================
        # 2) Validate material -> module -> course + ownership
        # =========================
        material_row = db.execute(
            text("""
                SELECT
                    m.id,
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
            raise HTTPException(status_code=403, detail="You can only view questions for your own course")

        # =========================
        # 3) Fetch material questions
        # =========================
        question_rows = db.execute(
            text("""
                SELECT
                    q.id,
                    q.course_id,
                    q.topic_id,
                    q.question_text,
                    q.options,
                    q.type,
                    q.difficulty,
                    q.source,
                    q.approval_status,
                    q.auto_gradable,
                    q.created_at,
                    q.updated_at
                FROM questions q
                JOIN topics t
                  ON t.id = q.topic_id
                WHERE q.course_id = :course_id
                  AND t.material_id = :material_id
                ORDER BY q.created_at ASC, q.id ASC
            """),
            {
                "course_id": course_id,
                "material_id": material_id,
            },
        ).mappings().all()

        return {
            "course_id": course_id,
            "module_id": module_id,
            "material_id": material_id,
            "questions": [dict(row) for row in question_rows],
        }

    except HTTPException:
        raise
    except SQLAlchemyError as e:
        raise HTTPException(status_code=500, detail="Database error") from e



def list_module_questions(*, course_id: int, module_id: int, db: Session, current_user: dict,):
    # =========================
    # 1) Authorization
    # =========================
    instructor_id = current_user.get("id")
    role = (current_user.get("system_role") or "").strip().lower()

    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can view questions")

    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")
    if not module_id or module_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid module_id")

    try:
        # =========================
        # 2) Validate module -> course + ownership
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
            raise HTTPException(status_code=403, detail="You can only view questions for your own course")

        # =========================
        # 3) Fetch module questions
        # =========================
        question_rows = db.execute(
            text("""
                SELECT
                    q.id,
                    q.course_id,
                    q.topic_id,
                    q.question_text,
                    q.options,
                    q.type,
                    q.difficulty,
                    q.source,
                    q.approval_status,
                    q.auto_gradable,
                    q.created_at,
                    q.updated_at
                FROM questions q
                JOIN topics t
                  ON t.id = q.topic_id
                JOIN materials mat
                  ON mat.id = t.material_id
                WHERE q.course_id = :course_id
                  AND mat.module_id = :module_id
                ORDER BY q.created_at ASC, q.id ASC
            """),
            {
                "course_id": course_id,
                "module_id": module_id,
            },
        ).mappings().all()

        return {
            "course_id": course_id,
            "module_id": module_id,
            "questions": [dict(row) for row in question_rows],
        }

    except HTTPException:
        raise
    except SQLAlchemyError as e:
        raise HTTPException(status_code=500, detail="Database error") from e



def list_course_questions(*, course_id: int, db: Session, current_user: dict,):
    # =========================
    # 1) Authorization
    # =========================
    instructor_id = current_user.get("id")
    role = (current_user.get("system_role") or "").strip().lower()

    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can view questions")

    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    try:
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
            raise HTTPException(status_code=403, detail="You can only view questions for your own course")

        # =========================
        # 3) Fetch course questions
        # =========================
        question_rows = db.execute(
            text("""
                SELECT
                    id,
                    course_id,
                    topic_id,
                    question_text,
                    options,
                    type,
                    difficulty,
                    source,
                    approval_status,
                    auto_gradable,
                    created_at,
                    updated_at
                FROM questions
                WHERE course_id = :course_id
                ORDER BY created_at ASC, id ASC
            """),
            {"course_id": course_id},
        ).mappings().all()

        return {
            "course_id": course_id,
            "questions": [dict(row) for row in question_rows],
        }

    except HTTPException:
        raise
    except SQLAlchemyError as e:
        raise HTTPException(status_code=500, detail="Database error") from e



