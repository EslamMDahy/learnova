from __future__ import annotations

from fastapi import HTTPException, status
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session


def insert_topic_learning_outcome_relations(
    *,
    db: Session,
    relations: list[dict],
    topic_id_map: dict[str, int],
    learning_outcome_id_map: dict[str, int],
) -> int:
    if not isinstance(relations, list):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="relations must be a list",
        )

    inserted_count = 0
    seen_pairs: set[tuple[int, int]] = set()

    try:
        for item in relations:
            if not isinstance(item, dict):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Each topic-learning-outcome relation item must be an object",
                )

            topic_temp_id = (item.get("topic_temp_id") or "").strip()
            learning_outcome_temp_id = (item.get("learning_outcome_temp_id") or "").strip()

            if not topic_temp_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Each relation must include a non-empty topic_temp_id",
                )

            if not learning_outcome_temp_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Each relation must include a non-empty learning_outcome_temp_id",
                )

            topic_id = topic_id_map.get(topic_temp_id)
            if topic_id is None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Unknown topic_temp_id in relation: {topic_temp_id}",
                )

            learning_outcome_id = learning_outcome_id_map.get(learning_outcome_temp_id)
            if learning_outcome_id is None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=(
                        "Unknown learning_outcome_temp_id in relation: "
                        f"{learning_outcome_temp_id}"
                    ),
                )

            pair = (topic_id, learning_outcome_id)
            if pair in seen_pairs:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=(
                        "Duplicate topic-learning-outcome relation after mapping: "
                        f"{topic_temp_id} -> {learning_outcome_temp_id}"
                    ),
                )

            seen_pairs.add(pair)

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
                    ON CONFLICT (topic_id, learning_outcome_id) DO NOTHING
                """),
                {
                    "topic_id": topic_id,
                    "learning_outcome_id": learning_outcome_id,
                },
            )

            inserted_count += 1

        return inserted_count

    except HTTPException:
        raise
    except IntegrityError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Conflict while inserting AI topic-learning-outcome relations",
        ) from exc
    except SQLAlchemyError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database error while inserting AI topic-learning-outcome relations",
        ) from exc


def mark_material_ai_processing_completed(
    *,
    db: Session,
    material_id: int,
) -> None:
    if not isinstance(material_id, int) or material_id <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid material_id for AI processing completion update",
        )

    try:
        row = db.execute(
            text("""
                UPDATE materials
                SET
                    is_ai_processed = TRUE,
                    ai_processed_at = NOW(),
                    updated_at = NOW()
                WHERE id = :material_id
                RETURNING id
            """),
            {
                "material_id": material_id,
            },
        ).mappings().first()

        if not row:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Material not found while marking AI processing as completed",
            )

    except HTTPException:
        raise
    except SQLAlchemyError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database error while updating material AI processing state",
        ) from exc