from __future__ import annotations

from fastapi import HTTPException, status
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session


def bulk_insert_ai_topics(
    *,
    db: Session,
    material_id: int,
    topics: list[dict],
) -> dict[str, int]:
    if not isinstance(material_id, int) or material_id <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid material_id for AI topics insertion",
        )

    if not isinstance(topics, list):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="topics must be a list",
        )

    topic_id_map: dict[str, int] = {}
    pending_parent_links: list[tuple[int, str]] = []

    try:
        # =========================
        # Pass 1: insert all topics without parent_topic_id
        # =========================
        for item in topics:
            if not isinstance(item, dict):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Each topic item must be an object",
                )

            temp_id = (item.get("temp_id") or "").strip()
            title = (item.get("title") or "").strip()

            description = item.get("description")
            if isinstance(description, str):
                description = description.strip() or None
            else:
                description = None

            order_index = item.get("order_index")
            if not isinstance(order_index, int) or order_index < 0:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Each topic must include a valid non-negative order_index",
                )

            parent_temp_id = item.get("parent_temp_id")
            if parent_temp_id is not None:
                if not isinstance(parent_temp_id, str) or not parent_temp_id.strip():
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="topic.parent_temp_id must be null or a non-empty string",
                    )
                parent_temp_id = parent_temp_id.strip()

            if not temp_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Each topic must include a non-empty temp_id",
                )

            if not title:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Each topic must include a non-empty title",
                )

            if temp_id in topic_id_map:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Duplicate topic temp_id: {temp_id}",
                )

            row = db.execute(
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
                        NULL,
                        TRUE,
                        FALSE,
                        NOW(),
                        NOW()
                    )
                    RETURNING id
                """),
                {
                    "material_id": material_id,
                    "title": title,
                    "description": description,
                    "order_index": order_index,
                },
            ).mappings().first()

            if not row:
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="Failed to insert AI topic",
                )

            topic_id = int(row["id"])
            topic_id_map[temp_id] = topic_id

            if parent_temp_id is not None:
                pending_parent_links.append((topic_id, parent_temp_id))

        # =========================
        # Pass 2: resolve and update parent_topic_id
        # =========================
        for topic_id, parent_temp_id in pending_parent_links:
            parent_topic_id = topic_id_map.get(parent_temp_id)

            if parent_topic_id is None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Unknown parent_temp_id referenced by topic: {parent_temp_id}",
                )

            if parent_topic_id == topic_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="A topic cannot reference itself as parent",
                )

            db.execute(
                text("""
                    UPDATE topics
                    SET
                        parent_topic_id = :parent_topic_id,
                        updated_at = NOW()
                    WHERE id = :topic_id
                """),
                {
                    "topic_id": topic_id,
                    "parent_topic_id": parent_topic_id,
                },
            )

        return topic_id_map

    except HTTPException:
        raise
    except SQLAlchemyError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database error while inserting AI topics",
        ) from exc