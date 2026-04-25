from __future__ import annotations

from fastapi import HTTPException, status
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session


def bulk_insert_ai_learning_outcomes(
    *,
    db: Session,
    course_id: int,
    learning_outcomes: list[dict],
) -> dict[str, int]:
    if not isinstance(course_id, int) or course_id <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid course_id for AI learning outcomes insertion",
        )

    if not isinstance(learning_outcomes, list):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="learning_outcomes must be a list",
        )

    learning_outcome_id_map: dict[str, int] = {}

    try:
        for item in learning_outcomes:
            if not isinstance(item, dict):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Each learning outcome item must be an object",
                )

            temp_id = (item.get("temp_id") or "").strip()
            title = (item.get("title") or "").strip()
            level = (item.get("level") or "").strip().lower()

            description = item.get("description")
            if isinstance(description, str):
                description = description.strip() or None
            else:
                description = None

            if not temp_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Each learning outcome must include a non-empty temp_id",
                )

            if not title:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Each learning outcome must include a non-empty title",
                )

            if not level:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Each learning outcome must include a non-empty level",
                )

            if temp_id in learning_outcome_id_map:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Duplicate learning outcome temp_id: {temp_id}",
                )

            row = db.execute(
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
                        TRUE,
                        FALSE,
                        NOW(),
                        NOW()
                    )
                    RETURNING id
                """),
                {
                    "course_id": course_id,
                    "title": title,
                    "description": description,
                    "level": level,
                },
            ).mappings().first()

            if not row:
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="Failed to insert AI learning outcome",
                )

            learning_outcome_id_map[temp_id] = int(row["id"])

        return learning_outcome_id_map

    except HTTPException:
        raise
    except SQLAlchemyError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database error while inserting AI learning outcomes",
        ) from exc