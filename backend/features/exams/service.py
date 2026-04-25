from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError

from .schemas import (ExamCreateRequest,
                     ExamAddQuestionsRequest)


ALLOWED_EXAM_TYPES = {"quiz", "midterm", "final", "practice"}


def create_exam(*, course_id: int, payload: ExamCreateRequest, db: Session, current_user: dict,):
    # =========================
    # 1) Authorization
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can create exams")

    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    title = payload.title.strip()
    if not title:
        raise HTTPException(status_code=422, detail="Exam title is required")

    exam_type = payload.exam_type.strip().lower()
    if exam_type not in ALLOWED_EXAM_TYPES:
        raise HTTPException(status_code=422, detail="Invalid exam_type")

    if payload.available_from and payload.available_to:
        if payload.available_to <= payload.available_from:
            raise HTTPException(
                status_code=400,
                detail="available_to must be after available_from",
            )

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
            detail="You can only create exams for your own course",
        )

    # =========================
    # 3) Insert exam metadata only
    # =========================
    try:
        exam_row = db.execute(
            text("""
                INSERT INTO exams (
                    course_id,
                    title,
                    description,
                    instructions,
                    exam_type,
                    duration_minutes,
                    max_attempts,
                    passing_score,
                    total_questions,
                    total_score,
                    is_published,
                    is_auto_generated,
                    shuffle_questions,
                    shuffle_options,
                    available_from,
                    available_to,
                    enable_proctoring,
                    prevent_copy_paste,
                    prevent_tab_switch,
                    require_webcam,
                    require_microphone,
                    access_code,
                    ip_restrictions,
                    created_by,
                    created_at,
                    updated_at
                )
                VALUES (
                    :course_id,
                    :title,
                    :description,
                    :instructions,
                    :exam_type,
                    :duration_minutes,
                    :max_attempts,
                    :passing_score,
                    :total_questions,
                    :total_score,
                    :is_published,
                    :is_auto_generated,
                    :shuffle_questions,
                    :shuffle_options,
                    :available_from,
                    :available_to,
                    :enable_proctoring,
                    :prevent_copy_paste,
                    :prevent_tab_switch,
                    :require_webcam,
                    :require_microphone,
                    :access_code,
                    CAST(:ip_restrictions AS JSON),
                    :created_by,
                    NOW(),
                    NOW()
                )
                RETURNING
                    id,
                    course_id,
                    title,
                    description,
                    instructions,
                    exam_type,
                    duration_minutes,
                    max_attempts,
                    passing_score,
                    total_questions,
                    total_score,
                    is_published,
                    is_auto_generated,
                    shuffle_questions,
                    shuffle_options,
                    available_from,
                    available_to,
                    enable_proctoring,
                    prevent_copy_paste,
                    prevent_tab_switch,
                    require_webcam,
                    require_microphone,
                    access_code,
                    ip_restrictions,
                    created_by,
                    created_at,
                    updated_at
            """),
            {
                "course_id": course_id,
                "title": title,
                "description": payload.description.strip() if payload.description else None,
                "instructions": payload.instructions.strip() if payload.instructions else None,
                "exam_type": exam_type,
                "duration_minutes": payload.duration_minutes,
                "max_attempts": payload.max_attempts,
                "passing_score": payload.passing_score,
                "total_questions": 0,
                "total_score": 0,
                "is_published": False,
                "is_auto_generated": False,
                "shuffle_questions": payload.shuffle_questions,
                "shuffle_options": payload.shuffle_options,
                "available_from": payload.available_from,
                "available_to": payload.available_to,
                "enable_proctoring": False,
                "prevent_copy_paste": False,
                "prevent_tab_switch": False,
                "require_webcam": False,
                "require_microphone": False,
                "access_code": payload.access_code.strip() if payload.access_code else None,
                "ip_restrictions": None,
                "created_by": instructor_id,
            },
        ).mappings().first()

        if not exam_row:
            db.rollback()
            raise HTTPException(status_code=503, detail="Failed to create exam")

        db.commit()
        return dict(exam_row)

    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=409, detail="Conflict while creating exam") from e

    except HTTPException:
        db.rollback()
        raise

    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error") from e
    


def add_questions_to_exam(*, course_id: int, exam_id: int, payload: ExamAddQuestionsRequest, db: Session, current_user: dict,):
    # =========================
    # 1) Authorization
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can add questions to exams")

    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    if not exam_id or exam_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid exam_id")

    question_ids = payload.question_ids

    if not question_ids:
        raise HTTPException(status_code=422, detail="question_ids is required")

    if any((not qid or qid <= 0) for qid in question_ids):
        raise HTTPException(status_code=422, detail="Invalid question_id in question_ids")

    if len(question_ids) != len(set(question_ids)):
        raise HTTPException(status_code=400, detail="Duplicate question_ids are not allowed")

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
            raise HTTPException(
                status_code=403,
                detail="You can only manage exams for your own course",
            )

        # =========================
        # 3) Validate exam belongs to course
        # =========================
        exam_row = db.execute(
            text("""
                SELECT id, course_id, created_by
                FROM exams
                WHERE id = :exam_id
                  AND course_id = :course_id
                LIMIT 1
            """),
            {
                "exam_id": exam_id,
                "course_id": course_id,
            },
        ).mappings().first()

        if not exam_row:
            raise HTTPException(status_code=404, detail="Exam not found")

        if int(exam_row["created_by"]) != int(instructor_id):
            raise HTTPException(
                status_code=403,
                detail="You can only add questions to your own exam",
            )

        # =========================
        # 4) Validate all questions belong to same course
        # =========================
        question_rows = db.execute(
            text("""
                SELECT
                    id,
                    course_id,
                    max_score
                FROM questions
                WHERE course_id = :course_id
                  AND id = ANY(:question_ids)
            """),
            {
                "course_id": course_id,
                "question_ids": question_ids,
            },
        ).mappings().all()

        found_question_ids = {int(row["id"]) for row in question_rows}
        requested_question_ids = set(question_ids)

        missing_question_ids = requested_question_ids - found_question_ids
        if missing_question_ids:
            raise HTTPException(
                status_code=400,
                detail={
                    "message": "Some questions were not found or do not belong to this course",
                    "question_ids": sorted(missing_question_ids),
                },
            )

        # =========================
        # 5) Prevent already-added questions
        # =========================
        existing_rows = db.execute(
            text("""
                SELECT question_id
                FROM exam_questions
                WHERE exam_id = :exam_id
                  AND question_id = ANY(:question_ids)
            """),
            {
                "exam_id": exam_id,
                "question_ids": question_ids,
            },
        ).mappings().all()

        existing_question_ids = [int(row["question_id"]) for row in existing_rows]

        if existing_question_ids:
            raise HTTPException(
                status_code=409,
                detail={
                    "message": "Some questions are already added to this exam",
                    "question_ids": existing_question_ids,
                },
            )

        # =========================
        # 6) Calculate next order_index
        # =========================
        max_order_row = db.execute(
            text("""
                SELECT COALESCE(MAX(order_index), 0) AS max_order_index
                FROM exam_questions
                WHERE exam_id = :exam_id
            """),
            {"exam_id": exam_id},
        ).mappings().first()

        if not max_order_row:
            raise HTTPException(status_code=500, detail="Failed to calculate exam question order")

        next_order_index = int(max_order_row["max_order_index"] or 0) + 1

        question_points_by_id = {
            int(row["id"]): float(row["max_score"]) if row["max_score"] is not None else 1.0
            for row in question_rows
        }

        # =========================
        # 7) Insert exam questions
        # =========================
        inserted_rows = []

        for index, question_id in enumerate(question_ids):
            points = question_points_by_id.get(int(question_id), 1.0)

            inserted_row = db.execute(
                text("""
                    INSERT INTO exam_questions (
                        exam_id,
                        section_id,
                        question_id,
                        order_index,
                        points,
                        custom_points,
                        custom_instructions
                    )
                    VALUES (
                        :exam_id,
                        :section_id,
                        :question_id,
                        :order_index,
                        :points,
                        :custom_points,
                        :custom_instructions
                    )
                    RETURNING
                        id,
                        exam_id,
                        section_id,
                        question_id,
                        order_index,
                        points,
                        custom_points,
                        custom_instructions
                """),
                {
                    "exam_id": exam_id,
                    "section_id": None,
                    "question_id": question_id,
                    "order_index": next_order_index + index,
                    "points": points,
                    "custom_points": None,
                    "custom_instructions": None,
                },
            ).mappings().first()

            if not inserted_row:
                db.rollback()
                raise HTTPException(status_code=503, detail="Failed to add question to exam")

            inserted_rows.append(dict(inserted_row))

        # =========================
        # 8) Update exam totals
        # =========================
        totals_row = db.execute(
            text("""
                SELECT
                    COUNT(*) AS total_questions,
                    COALESCE(SUM(points), 0) AS total_score
                FROM exam_questions
                WHERE exam_id = :exam_id
            """),
            {"exam_id": exam_id},
        ).mappings().first()

        if not totals_row:
            raise HTTPException(status_code=500, detail="Failed to calculate exam totals")

        total_questions = int(totals_row["total_questions"] or 0)
        total_score = float(totals_row["total_score"] or 0)

        db.execute(
            text("""
                UPDATE exams
                SET
                    total_questions = :total_questions,
                    total_score = :total_score,
                    updated_at = NOW()
                WHERE id = :exam_id
                  AND course_id = :course_id
            """),
            {
                "exam_id": exam_id,
                "course_id": course_id,
                "total_questions": total_questions,
                "total_score": total_score,
            },
        )

        db.commit()

        return {
            "exam_id": exam_id,
            "course_id": course_id,
            "added_count": len(inserted_rows),
            "total_questions": total_questions,
            "total_score": total_score,
            "questions": inserted_rows,
        }

    except HTTPException:
        db.rollback()
        raise

    except IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=409, detail="Conflict while adding questions to exam") from e

    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error") from e
    


def list_exams(*, course_id: int, db: Session, current_user: dict,):
    # =========================
    # 1) Authorization
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can view exams")

    instructor_id = current_user.get("id")
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
            raise HTTPException(
                status_code=403,
                detail="You can only view exams for your own course",
            )

        # =========================
        # 3) Fetch exams
        # =========================
        exam_rows = db.execute(
            text("""
                SELECT
                    id,
                    course_id,
                    title,
                    description,
                    exam_type,
                    duration_minutes,
                    max_attempts,
                    passing_score,
                    total_questions,
                    total_score,
                    is_published,
                    is_auto_generated,
                    shuffle_questions,
                    shuffle_options,
                    available_from,
                    available_to,
                    created_by,
                    created_at,
                    updated_at
                FROM exams
                WHERE course_id = :course_id
                ORDER BY created_at DESC, id DESC
            """),
            {"course_id": course_id},
        ).mappings().all()

        exams = [dict(row) for row in exam_rows]

        return {
            "course_id": course_id,
            "total": len(exams),
            "exams": exams,
        }

    except HTTPException:
        raise

    except SQLAlchemyError as e:
        raise HTTPException(status_code=500, detail="Database error") from e



def get_exam(*, course_id: int, exam_id: int, db: Session, current_user: dict,):
    # =========================
    # 1) Authorization
    # =========================
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can view exams")

    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    if not exam_id or exam_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid exam_id")

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
            raise HTTPException(
                status_code=403,
                detail="You can only view exams for your own course",
            )

        # =========================
        # 3) Fetch exam
        # =========================
        exam_row = db.execute(
            text("""
                SELECT
                    id,
                    course_id,
                    title,
                    description,
                    instructions,
                    exam_type,
                    duration_minutes,
                    max_attempts,
                    passing_score,
                    total_questions,
                    total_score,
                    is_published,
                    is_auto_generated,
                    shuffle_questions,
                    shuffle_options,
                    available_from,
                    available_to,
                    enable_proctoring,
                    prevent_copy_paste,
                    prevent_tab_switch,
                    require_webcam,
                    require_microphone,
                    access_code,
                    ip_restrictions,
                    created_by,
                    created_at,
                    updated_at
                FROM exams
                WHERE id = :exam_id
                  AND course_id = :course_id
                LIMIT 1
            """),
            {
                "exam_id": exam_id,
                "course_id": course_id,
            },
        ).mappings().first()

        if not exam_row:
            raise HTTPException(status_code=404, detail="Exam not found")

        if int(exam_row["created_by"]) != int(instructor_id):
            raise HTTPException(
                status_code=403,
                detail="You can only view your own exam",
            )

        # =========================
        # 4) Fetch exam questions
        # =========================
        question_rows = db.execute(
            text("""
                SELECT
                    eq.id AS exam_question_id,
                    eq.question_id,
                    eq.section_id,
                    eq.order_index,
                    eq.points,
                    eq.custom_points,
                    eq.custom_instructions,

                    q.topic_id,
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
                    q.tags
                FROM exam_questions eq
                JOIN questions q
                  ON q.id = eq.question_id
                WHERE eq.exam_id = :exam_id
                  AND q.course_id = :course_id
                ORDER BY eq.order_index ASC, eq.id ASC
            """),
            {
                "exam_id": exam_id,
                "course_id": course_id,
            },
        ).mappings().all()

        exam_data = dict(exam_row)
        exam_data["questions"] = [dict(row) for row in question_rows]

        return exam_data

    except HTTPException:
        raise

    except SQLAlchemyError as e:
        raise HTTPException(status_code=500, detail="Database error") from e  



 