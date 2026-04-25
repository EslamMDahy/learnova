from __future__ import annotations

from typing import Any


def validate_and_normalize_question_payload(payload) -> dict[str, Any]:
    question_type = (payload.type or "").strip().lower()

    if not question_type:
        return {"ok": False, "status_code": 422, "detail": "type is required"}

    handlers = {
        "multiple_choice": validate_and_normalize_multiple_choice,
        "multi_select": validate_and_normalize_multi_select,
        "true_false": validate_and_normalize_true_false,
        "short_answer": validate_and_normalize_short_answer,
        "essay": validate_and_normalize_essay,
    }

    handler = handlers.get(question_type)
    if not handler:
        return {
            "ok": False,
            "status_code": 422,
            "detail": f"Unsupported question type: {question_type}"
        }

    return handler(payload)


def validate_and_normalize_multiple_choice(payload) -> dict[str, Any]:
    question_text = (payload.question_text or "").strip()
    if not question_text:
        return {"ok": False, "status_code": 422, "detail": "question_text is required"}

    difficulty = (payload.difficulty or "").strip().lower()
    if not difficulty:
        return {"ok": False, "status_code": 422, "detail": "difficulty is required"}

    options = payload.options
    if not isinstance(options, list) or len(options) < 2:
        return {
            "ok": False,
            "status_code": 422,
            "detail": "multiple_choice questions must include at least 2 options"
        }

    normalized_options = []
    seen_ids = set()

    for option in options:
        option_id = (option.id or "").strip()
        option_text = (option.text or "").strip()

        if not option_id:
            return {
                "ok": False,
                "status_code": 422,
                "detail": "Each option must include a non-empty id"
            }

        if not option_text:
            return {
                "ok": False,
                "status_code": 422,
                "detail": "Each option must include non-empty text"
            }

        if option_id in seen_ids:
            return {
                "ok": False,
                "status_code": 422,
                "detail": "Option ids must be unique"
            }

        seen_ids.add(option_id)
        normalized_options.append({
            "id": option_id,
            "text": option_text,
        })

    expected_answer = (payload.expected_answer or "").strip()
    if not expected_answer:
        return {
            "ok": False,
            "status_code": 422,
            "detail": "expected_answer is required for multiple_choice questions"
        }

    if expected_answer not in seen_ids:
        return {
            "ok": False,
            "status_code": 422,
            "detail": "expected_answer must match one of the option ids"
        }

    explanation = payload.explanation
    if isinstance(explanation, str):
        explanation = explanation.strip() or None

    return {
        "ok": True,
        "data": {
            "question_text": question_text,
            "type": question_type_from_payload(payload),
            "difficulty": difficulty,
            "explanation": explanation,
            "options": normalized_options,
            "expected_answer": expected_answer,
            "grading_rubric": None,
            "max_score": 1,
            "auto_gradable": True,
            "source": "manual",
            "approval_status": "approved",
            "usage_count": 0,
            "success_rate": None,
            "average_time_seconds": None,
            "tags": None,
        }
    }



def validate_and_normalize_multi_select(payload) -> dict[str, Any]:
    question_text = (payload.question_text or "").strip()
    if not question_text:
        return {"ok": False, "status_code": 422, "detail": "question_text is required"}

    difficulty = (payload.difficulty or "").strip().lower()
    if not difficulty:
        return {"ok": False, "status_code": 422, "detail": "difficulty is required"}

    options = payload.options
    if not isinstance(options, list) or len(options) < 2:
        return {
            "ok": False,
            "status_code": 422,
            "detail": "multi_select questions must include at least 2 options"
        }

    normalized_options = []
    seen_ids = set()

    for option in options:
        option_id = (option.id or "").strip()
        option_text = (option.text or "").strip()

        if not option_id:
            return {
                "ok": False,
                "status_code": 422,
                "detail": "Each option must include a non-empty id"
            }

        if not option_text:
            return {
                "ok": False,
                "status_code": 422,
                "detail": "Each option must include non-empty text"
            }

        if option_id in seen_ids:
            return {
                "ok": False,
                "status_code": 422,
                "detail": "Option ids must be unique"
            }

        seen_ids.add(option_id)
        normalized_options.append({
            "id": option_id,
            "text": option_text,
        })

    expected_answer = payload.expected_answer
    if not isinstance(expected_answer, list) or not expected_answer:
        return {
            "ok": False,
            "status_code": 422,
            "detail": "expected_answer is required for multi_select questions and must be a non-empty list"
        }

    normalized_expected_answer = []
    seen_answer_ids = set()

    for answer_id in expected_answer:
        if not isinstance(answer_id, str):
            return {
                "ok": False,
                "status_code": 422,
                "detail": "Each expected_answer item must be a string"
            }

        answer_id = answer_id.strip()
        if not answer_id:
            return {
                "ok": False,
                "status_code": 422,
                "detail": "Each expected_answer item must be non-empty"
            }

        if answer_id not in seen_ids:
            return {
                "ok": False,
                "status_code": 422,
                "detail": "Each expected_answer item must match one of the option ids"
            }

        if answer_id in seen_answer_ids:
            return {
                "ok": False,
                "status_code": 422,
                "detail": "expected_answer must not contain duplicates"
            }

        seen_answer_ids.add(answer_id)
        normalized_expected_answer.append(answer_id)

    explanation = payload.explanation
    if isinstance(explanation, str):
        explanation = explanation.strip() or None

    return {
        "ok": True,
        "data": {
            "question_text": question_text,
            "type": question_type_from_payload(payload),
            "difficulty": difficulty,
            "explanation": explanation,
            "options": normalized_options,
            "expected_answer": normalized_expected_answer,
            "grading_rubric": None,
            "max_score": 1,
            "auto_gradable": True,
            "source": "manual",
            "approval_status": "approved",
            "usage_count": 0,
            "success_rate": None,
            "average_time_seconds": None,
            "tags": None,
        }
    }



def validate_and_normalize_true_false(payload) -> dict[str, Any]:
    question_text = (payload.question_text or "").strip()
    if not question_text:
        return {"ok": False, "status_code": 422, "detail": "question_text is required"}

    difficulty = (payload.difficulty or "").strip().lower()
    if not difficulty:
        return {"ok": False, "status_code": 422, "detail": "difficulty is required"}

    expected_answer = payload.expected_answer
    if not isinstance(expected_answer, str):
        return {
            "ok": False,
            "status_code": 422,
            "detail": "expected_answer is required for true_false questions and must be a string"
        }

    expected_answer = expected_answer.strip().lower()
    if expected_answer not in {"true", "false"}:
        return {
            "ok": False,
            "status_code": 422,
            "detail": "expected_answer for true_false must be either 'true' or 'false'"
        }

    explanation = payload.explanation
    if isinstance(explanation, str):
        explanation = explanation.strip() or None

    normalized_options = [
        {"id": "true", "text": "True"},
        {"id": "false", "text": "False"},
    ]

    return {
        "ok": True,
        "data": {
            "question_text": question_text,
            "type": question_type_from_payload(payload),
            "difficulty": difficulty,
            "explanation": explanation,
            "options": normalized_options,
            "expected_answer": expected_answer,
            "grading_rubric": None,
            "max_score": 1,
            "auto_gradable": True,
            "source": "manual",
            "approval_status": "approved",
            "usage_count": 0,
            "success_rate": None,
            "average_time_seconds": None,
            "tags": None,
        }
    }



def validate_and_normalize_short_answer(payload) -> dict[str, Any]:
    question_text = (payload.question_text or "").strip()
    if not question_text:
        return {"ok": False, "status_code": 422, "detail": "question_text is required"}

    difficulty = (payload.difficulty or "").strip().lower()
    if not difficulty:
        return {"ok": False, "status_code": 422, "detail": "difficulty is required"}

    expected_answer = payload.expected_answer
    if not isinstance(expected_answer, str):
        return {
            "ok": False,
            "status_code": 422,
            "detail": "expected_answer is required for short_answer questions and must be a string"
        }

    expected_answer = expected_answer.strip()
    if not expected_answer:
        return {
            "ok": False,
            "status_code": 422,
            "detail": "expected_answer is required for short_answer questions"
        }

    explanation = payload.explanation
    if isinstance(explanation, str):
        explanation = explanation.strip() or None

    grading_rubric = getattr(payload, "grading_rubric", None)
    if grading_rubric is not None and not isinstance(grading_rubric, dict):
        return {
            "ok": False,
            "status_code": 422,
            "detail": "grading_rubric must be an object when provided"
        }

    return {
        "ok": True,
        "data": {
            "question_text": question_text,
            "type": question_type_from_payload(payload),
            "difficulty": difficulty,
            "explanation": explanation,
            "options": None,
            "expected_answer": expected_answer,
            "grading_rubric": grading_rubric,
            "max_score": 1,
            "auto_gradable": False,
            "source": "manual",
            "approval_status": "approved",
            "usage_count": 0,
            "success_rate": None,
            "average_time_seconds": None,
            "tags": None,
        }
    }



def validate_and_normalize_essay(payload) -> dict[str, Any]:
    question_text = (payload.question_text or "").strip()
    if not question_text:
        return {"ok": False, "status_code": 422, "detail": "question_text is required"}

    difficulty = (payload.difficulty or "").strip().lower()
    if not difficulty:
        return {"ok": False, "status_code": 422, "detail": "difficulty is required"}

    expected_answer = payload.expected_answer
    if expected_answer is not None:
        if not isinstance(expected_answer, str):
            return {
                "ok": False,
                "status_code": 422,
                "detail": "expected_answer must be a string when provided for essay questions"
            }

        expected_answer = expected_answer.strip() or None

    explanation = payload.explanation
    if isinstance(explanation, str):
        explanation = explanation.strip() or None

    grading_rubric = getattr(payload, "grading_rubric", None)
    if grading_rubric is not None and not isinstance(grading_rubric, dict):
        return {
            "ok": False,
            "status_code": 422,
            "detail": "grading_rubric must be an object when provided"
        }

    return {
        "ok": True,
        "data": {
            "question_text": question_text,
            "type": question_type_from_payload(payload),
            "difficulty": difficulty,
            "explanation": explanation,
            "options": None,
            "expected_answer": expected_answer,
            "grading_rubric": grading_rubric,
            "max_score": 1,
            "auto_gradable": False,
            "source": "manual",
            "approval_status": "approved",
            "usage_count": 0,
            "success_rate": None,
            "average_time_seconds": None,
            "tags": None,
        }
    }



def question_type_from_payload(payload) -> str:
    return (payload.type or "").strip().lower()