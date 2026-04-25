from __future__ import annotations

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.ai_service_integration.ai_callback_verifier import (
    VerifiedAICallbackRequest,
)

from app.features.topics.helpers import bulk_insert_ai_topics
from app.features.learningOutcomes.helpers import bulk_insert_ai_learning_outcomes
from app.features.ai.helpers import (
    insert_topic_learning_outcome_relations,
    mark_material_ai_processing_completed,
)


def handle_content_structure_generation(
    *,
    db: Session,
    verified_callback: VerifiedAICallbackRequest,
    request_log: dict,
) -> dict:
    payload = verified_callback.payload
    body = _extract_callback_body(payload)

    callback_status = _extract_required_str(
        payload,
        "status",
        "Missing status in callback payload",
    ).lower()

    if callback_status != "completed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="content_structure_generation callback status must be 'completed'",
        )

    course_id = _extract_required_positive_int(
        payload,
        "course_id",
        "Missing or invalid course_id in callback payload",
    )

    module_id = _extract_required_positive_int(
        body,
        "module_id",
        "Missing or invalid module_id in callback body",
    )

    material_id = _extract_required_positive_int(
        body,
        "material_id",
        "Missing or invalid material_id in callback body",
    )

    topics = _extract_required_list(
        body,
        "topics",
        "Missing topics list in callback body",
    )

    learning_outcomes = _extract_required_list(
        body,
        "learning_outcomes",
        "Missing learning_outcomes list in callback body",
    )

    relations = _extract_required_list(
        body,
        "topic_learning_outcome_relations",
        "Missing topic_learning_outcome_relations list in callback body",
    )

    _validate_request_log_context(
        request_log=request_log,
        course_id=course_id,
        material_id=material_id,
    )

    topic_temp_ids = _validate_topics_payload(topics)
    learning_outcome_temp_ids = _validate_learning_outcomes_payload(learning_outcomes)
    _validate_relations_payload(
        relations=relations,
        topic_temp_ids=topic_temp_ids,
        learning_outcome_temp_ids=learning_outcome_temp_ids,
    )

    learning_outcome_id_map = bulk_insert_ai_learning_outcomes(
        db=db,
        course_id=course_id,
        learning_outcomes=learning_outcomes,
    )

    topic_id_map = bulk_insert_ai_topics(
        db=db,
        material_id=material_id,
        topics=topics,
    )

    inserted_relations_count = insert_topic_learning_outcome_relations(
        db=db,
        relations=relations,
        topic_id_map=topic_id_map,
        learning_outcome_id_map=learning_outcome_id_map,
    )

    mark_material_ai_processing_completed(
        db=db,
        material_id=material_id,
    )

    return {
        "course_id": course_id,
        "module_id": module_id,
        "material_id": material_id,
        "inserted_learning_outcomes": len(learning_outcome_id_map),
        "inserted_topics": len(topic_id_map),
        "inserted_topic_learning_outcome_relations": inserted_relations_count,
    }


def _extract_callback_body(payload: dict) -> dict:
    body = payload.get("body")

    if not isinstance(body, dict):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Callback payload body must be a JSON object",
        )

    return body


def _extract_required_str(source: dict, key: str, error_message: str) -> str:
    value = source.get(key)

    if not isinstance(value, str):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error_message,
        )

    value = value.strip()
    if not value:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error_message,
        )

    return value


def _extract_required_positive_int(source: dict, key: str, error_message: str) -> int:
    value = source.get(key)

    if not isinstance(value, int) or value <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error_message,
        )

    return value


def _extract_required_list(source: dict, key: str, error_message: str) -> list:
    value = source.get(key)

    if not isinstance(value, list):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error_message,
        )

    return value


def _validate_request_log_context(
    *,
    request_log: dict,
    course_id: int,
    material_id: int,
) -> None:
    request_log_course_id = request_log.get("course_id")
    request_log_primary_entity_type = (request_log.get("primary_entity_type") or "").strip().lower()
    request_log_primary_entity_id = request_log.get("primary_entity_id")

    if request_log_course_id is None or int(request_log_course_id) != int(course_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Callback course_id does not match AI request log",
        )

    if request_log_primary_entity_type != "material":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="AI request log primary_entity_type must be 'material'",
        )

    if request_log_primary_entity_id is None or int(request_log_primary_entity_id) != int(material_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Callback material_id does not match AI request log",
        )


def _validate_topics_payload(topics: list[dict]) -> set[str]:
    seen_temp_ids: set[str] = set()

    for item in topics:
        if not isinstance(item, dict):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Each topic item must be an object",
            )

        temp_id = _extract_required_str(
            item,
            "temp_id",
            "Each topic must include a non-empty temp_id",
        )

        _extract_required_str(
            item,
            "title",
            "Each topic must include a non-empty title",
        )

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

        if temp_id in seen_temp_ids:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Duplicate topic temp_id: {temp_id}",
            )

        seen_temp_ids.add(temp_id)

    return seen_temp_ids


def _validate_learning_outcomes_payload(learning_outcomes: list[dict]) -> set[str]:
    seen_temp_ids: set[str] = set()

    for item in learning_outcomes:
        if not isinstance(item, dict):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Each learning outcome item must be an object",
            )

        temp_id = _extract_required_str(
            item,
            "temp_id",
            "Each learning outcome must include a non-empty temp_id",
        )

        _extract_required_str(
            item,
            "title",
            "Each learning outcome must include a non-empty title",
        )

        _extract_required_str(
            item,
            "level",
            "Each learning outcome must include a non-empty level",
        )

        if temp_id in seen_temp_ids:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Duplicate learning outcome temp_id: {temp_id}",
            )

        seen_temp_ids.add(temp_id)

    return seen_temp_ids


def _validate_relations_payload(
    *,
    relations: list[dict],
    topic_temp_ids: set[str],
    learning_outcome_temp_ids: set[str],
) -> None:
    seen_pairs: set[tuple[str, str]] = set()

    for item in relations:
        if not isinstance(item, dict):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Each topic-learning-outcome relation item must be an object",
            )

        topic_temp_id = _extract_required_str(
            item,
            "topic_temp_id",
            "Each relation must include a non-empty topic_temp_id",
        )

        learning_outcome_temp_id = _extract_required_str(
            item,
            "learning_outcome_temp_id",
            "Each relation must include a non-empty learning_outcome_temp_id",
        )

        if topic_temp_id not in topic_temp_ids:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Relation references unknown topic_temp_id: {topic_temp_id}",
            )

        if learning_outcome_temp_id not in learning_outcome_temp_ids:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Relation references unknown learning_outcome_temp_id: "
                    f"{learning_outcome_temp_id}"
                ),
            )

        pair = (topic_temp_id, learning_outcome_temp_id)
        if pair in seen_pairs:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Duplicate topic-learning-outcome relation: "
                    f"{topic_temp_id} -> {learning_outcome_temp_id}"
                ),
            )

        seen_pairs.add(pair)