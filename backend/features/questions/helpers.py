from __future__ import annotations

from typing import Any, Optional
from types import SimpleNamespace
import json

from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text, bindparam
from sqlalchemy.exc import SQLAlchemyError

from .handlers import validate_and_normalize_question_payload


def validate_and_prepare_ai_generated_questions(*, course_id: int, questions: list[dict[str, Any]], db: Session,):
    # =========================
    # 1) Validate input shape
    # =========================
    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    if not isinstance(questions, list) or not questions:
        raise HTTPException(status_code=422, detail="questions is required")

    topic_ids = []
    seen_topic_ids = set()

    for question_data in questions:
        if not isinstance(question_data, dict):
            raise HTTPException(status_code=422, detail="Each question must be an object")

        topic_id = question_data.get("topic_id")
        if not topic_id or int(topic_id) <= 0:
            raise HTTPException(status_code=422, detail="Invalid topic_id")

        topic_id = int(topic_id)
        if topic_id not in seen_topic_ids:
            seen_topic_ids.add(topic_id)
            topic_ids.append(topic_id)

    # =========================
    # 2) Validate topics belong to same course
    # =========================
    topic_query = text("""
        SELECT
            t.id,
            mo.course_id
        FROM topics t
        JOIN materials m
          ON m.id = t.material_id
        JOIN modules mo
          ON mo.id = m.module_id
        WHERE t.id IN :topic_ids
    """).bindparams(bindparam("topic_ids", expanding=True))

    topic_rows = db.execute(
        topic_query,
        {"topic_ids": topic_ids},
    ).mappings().all()

    if len(topic_rows) != len(topic_ids):
        found_topic_ids = {int(row["id"]) for row in topic_rows}
        missing_topic_ids = [topic_id for topic_id in topic_ids if topic_id not in found_topic_ids]

        raise HTTPException(
            status_code=404,
            detail=f"Topics not found: {missing_topic_ids}"
        )

    for topic_row in topic_rows:
        if int(topic_row["course_id"]) != int(course_id):
            raise HTTPException(status_code=400, detail="One or more topics do not belong to this course")

    # =========================
    # 3) Validate + normalize questions
    # =========================
    prepared_questions = []

    for question_data in questions:
        options = question_data.get("options")

        if isinstance(options, list):
            options = [
                SimpleNamespace(**option)
                if isinstance(option, dict) else option
                for option in options
            ]

        question_payload = SimpleNamespace(
            topic_id=question_data.get("topic_id"),
            question_text=question_data.get("question_text"),
            explanation=question_data.get("explanation"),
            options=options,
            type=question_data.get("type"),
            difficulty=question_data.get("difficulty"),
            expected_answer=question_data.get("expected_answer"),
            grading_rubric=question_data.get("grading_rubric"),
        )

        validation_result = validate_and_normalize_question_payload(question_payload)
        if not validation_result["ok"]:
            raise HTTPException(
                status_code=validation_result["status_code"],
                detail=validation_result["detail"]
            )

        normalized_data = validation_result["data"]
        normalized_data["source"] = "ai_generated"
        normalized_data["approval_status"] = "pending"

        prepared_questions.append({
            "topic_id": int(question_data["topic_id"]),
            "data": normalized_data,
        })

    return prepared_questions



def insert_ai_generated_questions(*, course_id: int, prepared_questions: list[dict[str, Any]], db: Session, created_by: Optional[int] = None,):
    # =========================
    # 1) Validate prepared questions
    # =========================
    if not course_id or course_id <= 0:
        raise HTTPException(status_code=422, detail="Invalid course_id")

    if not isinstance(prepared_questions, list) or not prepared_questions:
        raise HTTPException(status_code=422, detail="prepared_questions is required")

    inserted_question_ids = []

    try:
        # =========================
        # 2) Insert questions
        # =========================
        for prepared_question in prepared_questions:
            topic_id = prepared_question.get("topic_id")
            normalized_data = prepared_question.get("data")

            if not topic_id or int(topic_id) <= 0:
                raise HTTPException(status_code=422, detail="Invalid topic_id")

            if not isinstance(normalized_data, dict):
                raise HTTPException(status_code=422, detail="Invalid normalized question data")

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
                    RETURNING id
                """),
                {
                    "course_id": course_id,
                    "topic_id": int(topic_id),
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
                    "created_by": created_by,
                },
            ).mappings().first()

            if not question_row:
                raise HTTPException(status_code=503, detail="Failed to insert AI generated question")

            inserted_question_ids.append(question_row["id"])

        # =========================
        # 3) Build result
        # =========================
        return {
            "inserted_count": len(inserted_question_ids),
            "question_ids": inserted_question_ids,
        }

    except HTTPException:
        raise

    except SQLAlchemyError as e:
        raise HTTPException(status_code=500, detail="Database error") from e