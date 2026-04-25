from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
import json

from .schemas import QuestionCreateRequest
from .handlers import validate_and_normalize_question_payload


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



def get_question(*, course_id: int, question_id: int, db: Session, current_user: dict,):
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

    if not question_id or question_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid question_id")

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
        # 3) Fetch question details + topic info
        # =========================
        question_row = db.execute(
            text("""
                SELECT
                    q.id,
                    q.course_id,
                    q.topic_id,
                    t.title AS topic_title,
                    q.question_text,
                    q.explanation,
                    q.options,
                    q.type,
                    q.difficulty,
                    q.source,
                    q.approval_status,
                    q.expected_answer,
                    q.grading_rubric,
                    q.max_score,
                    q.auto_gradable,
                    q.usage_count,
                    q.success_rate,
                    q.average_time_seconds,
                    q.tags,
                    q.created_by,
                    q.created_at,
                    q.updated_at
                FROM questions q
                JOIN topics t
                  ON t.id = q.topic_id
                JOIN materials m
                  ON m.id = t.material_id
                JOIN modules mo
                  ON mo.id = m.module_id
                WHERE q.id = :question_id
                  AND q.course_id = :course_id
                  AND mo.course_id = :course_id
                LIMIT 1
            """),
            {
                "question_id": question_id,
                "course_id": course_id,
            },
        ).mappings().first()

        if not question_row:
            raise HTTPException(status_code=404, detail="Question not found")

        # =========================
        # 4) Fetch related learning outcomes through topic
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
                "topic_id": question_row["topic_id"],
                "course_id": course_id,
            },
        ).mappings().all()

        # =========================
        # 5) Build response
        # =========================
        return {
            "id": question_row["id"],
            "course_id": question_row["course_id"],
            "topic_id": question_row["topic_id"],
            "topic": {
                "id": question_row["topic_id"],
                "title": question_row["topic_title"],
            },
            "learning_outcomes": [dict(row) for row in learning_outcome_rows],
            "question_text": question_row["question_text"],
            "explanation": question_row["explanation"],
            "options": question_row["options"],
            "type": question_row["type"],
            "difficulty": question_row["difficulty"],
            "source": question_row["source"],
            "approval_status": question_row["approval_status"],
            "expected_answer": question_row["expected_answer"],
            "grading_rubric": question_row["grading_rubric"],
            "max_score": question_row["max_score"],
            "auto_gradable": question_row["auto_gradable"],
            "usage_count": question_row["usage_count"],
            "success_rate": question_row["success_rate"],
            "average_time_seconds": question_row["average_time_seconds"],
            "tags": question_row["tags"],
            "created_by": question_row["created_by"],
            "created_at": question_row["created_at"],
            "updated_at": question_row["updated_at"],
        }

    except HTTPException:
        raise
    except SQLAlchemyError as e:
        raise HTTPException(status_code=500, detail="Database error") from e



def update_question(*, course_id: int, question_id: int, payload, db: Session, current_user: dict):
    # =========================
    # 1) Authorization
    # =========================
    instructor_id = current_user.get("id")
    role = (current_user.get("system_role") or "").strip().lower()

    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can update questions")

    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    if not question_id or question_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid question_id")

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
            raise HTTPException(status_code=403, detail="You can only update questions for your own course")

        # =========================
        # 3) Fetch current question
        # =========================
        current_question = db.execute(
            text("""
                SELECT
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
                FROM questions
                WHERE id = :question_id
                  AND course_id = :course_id
                LIMIT 1
            """),
            {
                "question_id": question_id,
                "course_id": course_id,
            },
        ).mappings().first()

        if not current_question:
            raise HTTPException(status_code=404, detail="Question not found")

        # =========================
        # 4) Build dynamic patch fields
        # =========================
        raw_patch = payload.model_dump(exclude_unset=True)

        update_fields = {}

        if "topic_id" in raw_patch and raw_patch["topic_id"] is not None:
            update_fields["topic_id"] = raw_patch["topic_id"]

        if "question_text" in raw_patch and raw_patch["question_text"] is not None:
            question_text = raw_patch["question_text"].strip()
            if question_text:
                update_fields["question_text"] = question_text

        if "difficulty" in raw_patch and raw_patch["difficulty"] is not None:
            difficulty = raw_patch["difficulty"].strip().lower()
            if difficulty:
                update_fields["difficulty"] = difficulty

        if "explanation" in raw_patch:
            explanation = raw_patch["explanation"]
            if explanation is None:
                update_fields["explanation"] = None
            else:
                update_fields["explanation"] = explanation.strip() or None

        if "options" in raw_patch:
            update_fields["options"] = raw_patch["options"]

        if "expected_answer" in raw_patch:
            update_fields["expected_answer"] = raw_patch["expected_answer"]

        if "grading_rubric" in raw_patch:
            update_fields["grading_rubric"] = raw_patch["grading_rubric"]

        if "tags" in raw_patch:
            update_fields["tags"] = raw_patch["tags"]

        if not update_fields:
            raise HTTPException(status_code=400, detail="No updatable fields provided")

        # =========================
        # 5) Validate new topic belongs to same course if topic_id is updated
        # =========================
        if "topic_id" in update_fields:
            topic_id = update_fields["topic_id"]

            if not topic_id or topic_id <= 0:
                raise HTTPException(status_code=422, detail="Invalid topic_id")

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
        # 6) Merge current question + patch
        #    type comes from DB only
        # =========================
        merged_question_data = {
            "topic_id": update_fields.get("topic_id", current_question["topic_id"]),
            "question_text": update_fields.get("question_text", current_question["question_text"]),
            "type": current_question["type"],
            "difficulty": update_fields.get("difficulty", current_question["difficulty"]),
            "explanation": update_fields.get("explanation", current_question["explanation"]),
            "options": update_fields.get("options", current_question["options"]),
            "expected_answer": update_fields.get("expected_answer", current_question["expected_answer"]),
            "grading_rubric": update_fields.get("grading_rubric", current_question["grading_rubric"]),
        }

        merged_payload = type("MergedQuestionPayload", (), merged_question_data)()

        # =========================
        # 7) Validate final merged state using existing handlers
        # =========================
        validation_result = validate_and_normalize_question_payload(merged_payload)

        if not validation_result["ok"]:
            raise HTTPException(
                status_code=validation_result["status_code"],
                detail=validation_result["detail"],
            )

        normalized_data = validation_result["data"]

        # =========================
        # 8) Build SQL update dynamically
        #    Only update fields that were actually requested
        # =========================
        db_update_fields = {}

        if "topic_id" in update_fields:
            db_update_fields["topic_id"] = update_fields["topic_id"]

        if "question_text" in update_fields:
            db_update_fields["question_text"] = normalized_data["question_text"]

        if "difficulty" in update_fields:
            db_update_fields["difficulty"] = normalized_data["difficulty"]

        if "explanation" in update_fields:
            db_update_fields["explanation"] = normalized_data["explanation"]

        if "options" in update_fields:
            db_update_fields["options"] = json.dumps(normalized_data["options"])

        if "expected_answer" in update_fields:
            db_update_fields["expected_answer"] = json.dumps(normalized_data["expected_answer"])

        if "grading_rubric" in update_fields:
            db_update_fields["grading_rubric"] = (
                json.dumps(normalized_data["grading_rubric"])
                if normalized_data["grading_rubric"] is not None else None
            )

        if "tags" in update_fields:
            db_update_fields["tags"] = (
                json.dumps(update_fields["tags"])
                if update_fields["tags"] is not None else None
            )

        if not db_update_fields:
            raise HTTPException(status_code=400, detail="No updatable fields provided")

        set_clauses = []
        params = {
            "question_id": question_id,
            "course_id": course_id,
        }

        jsonb_columns = {"options", "expected_answer", "grading_rubric", "tags"}

        for col, value in db_update_fields.items():
            if col in jsonb_columns:
                set_clauses.append(f"{col} = CAST(:{col} AS JSONB)")
            else:
                set_clauses.append(f"{col} = :{col}")
            params[col] = value

        set_clauses.append("updated_at = NOW()")

        # =========================
        # 9) Update + return full question row
        # =========================
        updated_question = db.execute(
            text(f"""
                UPDATE questions
                SET {", ".join(set_clauses)}
                WHERE id = :question_id
                  AND course_id = :course_id
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
            params,
        ).mappings().first()

        if not updated_question:
            db.rollback()
            raise HTTPException(status_code=404, detail="Question not found")

        db.commit()
        return dict(updated_question)

    except HTTPException:
        db.rollback()
        raise

    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=409, detail="Conflict while updating question") from e

    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error") from e
    

