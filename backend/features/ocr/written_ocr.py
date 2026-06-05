from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .service import _ocr_page, normalise_lang


@dataclass(slots=True)
class WrittenAnswerResult:
    exam_question_id: int | None
    question_number: int
    type: str
    answer_text: str
    confidence: float
    status: str
    region: dict[str, int] | None
    ai_grading_payload: dict[str, Any]


def extract_written_answers(
    *,
    image: Any,
    questions: list[dict[str, Any]],
    lang: str,
) -> list[WrittenAnswerResult]:
    """Crop and OCR written answer regions.

    A full production scanner should persist exact box coordinates at PDF render
    time. This implementation works with the new print template by detecting the
    large answer boxes/line groups, then assigning them to written questions in
    reading order.
    """
    lang = normalise_lang(lang)
    regions = _detect_written_regions(image)
    written_questions = [
        q for q in questions
        if str(q.get("type") or "").strip().lower() in {"short_answer", "essay"}
    ]

    results: list[WrittenAnswerResult] = []
    for index, question in enumerate(written_questions):
        region = regions[index] if index < len(regions) else None
        if region is None:
            text = ""
            confidence = 0.0
            status = "needs_review"
        else:
            crop = _crop(image, region)
            page = _ocr_page(crop, lang)
            text = page.text
            confidence = page.confidence
            status = "ai_ready" if text.strip() and confidence >= 45 else "needs_review"

        payload = build_ai_grading_payload(question=question, answer_text=text, region=region, confidence=confidence)
        results.append(WrittenAnswerResult(
            exam_question_id=_safe_int(question.get("exam_question_id")),
            question_number=_safe_int(question.get("question_number")) or (index + 1),
            type=str(question.get("type") or "written"),
            answer_text=text,
            confidence=round(confidence, 2),
            status=status,
            region=region,
            ai_grading_payload=payload,
        ))

    return results


def build_ai_grading_payload(*, question: dict[str, Any], answer_text: str, region: dict[str, int] | None, confidence: float) -> dict[str, Any]:
    return {
        "operation_type": "exam_written_answer_grading",
        "exam_question_id": question.get("exam_question_id"),
        "question_id": question.get("question_id"),
        "question_type": question.get("type"),
        "question_text": question.get("question_text"),
        "expected_answer": question.get("expected_answer"),
        "grading_rubric": question.get("grading_rubric"),
        "max_score": question.get("points") or question.get("max_score"),
        "student_answer_text": answer_text,
        "ocr_confidence": round(confidence, 2),
        "answer_region": region,
        "review_policy": "Return score, feedback, confidence, and needs_review=true when handwriting/OCR is ambiguous.",
    }


def _detect_written_regions(image: Any) -> list[dict[str, int]]:
    try:
        import cv2
    except Exception:
        return []

    height, width = image.shape[:2]
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    binary = cv2.adaptiveThreshold(
        gray,
        255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY_INV,
        31,
        9,
    )

    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    regions: list[dict[str, int]] = []
    for contour in contours:
        x, y, w, h = cv2.boundingRect(contour)
        area = w * h
        if y < height * 0.12:
            continue
        if w < width * 0.42 or h < height * 0.025:
            continue
        if area < width * height * 0.012:
            continue
        if h > height * 0.45:
            continue
        regions.append({"x": int(x), "y": int(y), "w": int(w), "h": int(h)})

    regions = _merge_regions(regions)
    regions.sort(key=lambda r: (r["y"], r["x"]))
    return regions


def _merge_regions(regions: list[dict[str, int]]) -> list[dict[str, int]]:
    merged: list[dict[str, int]] = []
    for region in sorted(regions, key=lambda r: (r["y"], r["x"])):
        matched = None
        for current in merged:
            vertical_close = abs((current["y"] + current["h"]) - region["y"]) < 20 or abs((region["y"] + region["h"]) - current["y"]) < 20
            x_overlap = not (region["x"] + region["w"] < current["x"] or current["x"] + current["w"] < region["x"])
            if vertical_close and x_overlap:
                matched = current
                break
        if matched is None:
            merged.append(dict(region))
        else:
            x1 = min(matched["x"], region["x"])
            y1 = min(matched["y"], region["y"])
            x2 = max(matched["x"] + matched["w"], region["x"] + region["w"])
            y2 = max(matched["y"] + matched["h"], region["y"] + region["h"])
            matched.update({"x": x1, "y": y1, "w": x2 - x1, "h": y2 - y1})
    return merged


def _crop(image: Any, region: dict[str, int]):
    height, width = image.shape[:2]
    pad = 10
    x1 = max(0, region["x"] + pad)
    y1 = max(0, region["y"] + pad)
    x2 = min(width, region["x"] + region["w"] - pad)
    y2 = min(height, region["y"] + region["h"] - pad)
    return image[y1:y2, x1:x2]


def _safe_int(value: Any) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None
