from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(slots=True)
class Bubble:
    x: int
    y: int
    r: int
    fill_ratio: float
    confidence: float


@dataclass(slots=True)
class StudentIdResult:
    value: str | None
    confidence: float
    digits: list[dict[str, Any]]
    warnings: list[str]


@dataclass(slots=True)
class ObjectiveAnswerResult:
    exam_question_id: int | None
    question_number: int
    type: str
    detected_answer: str | None
    detected_answers: list[str]
    selected_option_index: int | None
    selected_option_indices: list[int] | None
    confidence: float
    status: str
    regions: list[dict[str, Any]]


_OPTION_LABELS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"


def detect_bubbles(image: Any) -> list[Bubble]:
    try:
        import cv2
        import numpy as np
    except Exception:
        return []

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    gray = cv2.medianBlur(gray, 5)
    height, width = gray.shape[:2]
    min_radius = max(7, int(min(width, height) * 0.003))
    max_radius = max(18, int(min(width, height) * 0.012))

    circles = cv2.HoughCircles(
        gray,
        cv2.HOUGH_GRADIENT,
        dp=1.25,
        minDist=max(18, min_radius * 3),
        param1=70,
        param2=18,
        minRadius=min_radius,
        maxRadius=max_radius,
    )

    if circles is None:
        return []

    binary = cv2.adaptiveThreshold(
        gray,
        255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY_INV,
        31,
        9,
    )

    bubbles: list[Bubble] = []
    for raw in np.round(circles[0, :]).astype("int"):
        x, y, r = int(raw[0]), int(raw[1]), int(raw[2])
        if x - r < 0 or y - r < 0 or x + r >= width or y + r >= height:
            continue
        mask = np.zeros(binary.shape, dtype="uint8")
        inner = max(2, int(r * 0.62))
        cv2.circle(mask, (x, y), inner, 255, -1)
        dark_pixels = cv2.countNonZero(cv2.bitwise_and(binary, binary, mask=mask))
        area = max(1, cv2.countNonZero(mask))
        fill_ratio = float(dark_pixels) / float(area)
        # Empty printed rings usually land below 0.18; filled pencil/pen bubbles
        # typically exceed 0.28 after thresholding. Confidence rewards distance
        # from the ambiguous band.
        confidence = min(99.0, abs(fill_ratio - 0.21) * 420.0)
        bubbles.append(Bubble(x=x, y=y, r=r, fill_ratio=fill_ratio, confidence=round(confidence, 2)))

    # Deduplicate Hough duplicates.
    bubbles.sort(key=lambda b: (b.y, b.x))
    deduped: list[Bubble] = []
    for bubble in bubbles:
        duplicate = False
        for kept in deduped:
            if abs(kept.x - bubble.x) <= max(5, bubble.r // 2) and abs(kept.y - bubble.y) <= max(5, bubble.r // 2):
                duplicate = True
                if bubble.confidence > kept.confidence:
                    kept.x, kept.y, kept.r = bubble.x, bubble.y, bubble.r
                    kept.fill_ratio, kept.confidence = bubble.fill_ratio, bubble.confidence
                break
        if not duplicate:
            deduped.append(bubble)
    return deduped


def read_student_id(image: Any, bubbles: list[Bubble], digits: int = 6) -> StudentIdResult:
    height, width = image.shape[:2]
    # Header region printed by the new PDF template. It intentionally sits on the
    # right to avoid colliding with question bubbles.
    region = [
        b for b in bubbles
        if b.x > width * 0.42 and b.y < height * 0.34
    ]
    if len(region) < digits * 5:
        return StudentIdResult(value=None, confidence=0.0, digits=[], warnings=["Student ID bubble grid was not detected."])

    rows = _group_rows(region, tolerance=max(14, int(height * 0.006)))
    rows = [sorted(row, key=lambda b: b.x) for row in rows if len(row) >= 8]
    rows = sorted(rows, key=lambda row: sum(b.y for b in row) / len(row))[:digits]

    if len(rows) < digits:
        return StudentIdResult(value=None, confidence=0.0, digits=[], warnings=["Student ID bubble rows are incomplete."])

    values: list[str] = []
    digit_payloads: list[dict[str, Any]] = []
    confidences: list[float] = []
    warnings: list[str] = []

    for row_index, row in enumerate(rows):
        cols = sorted(row, key=lambda b: b.x)[:10]
        ranked = sorted(enumerate(cols), key=lambda item: item[1].fill_ratio, reverse=True)
        selected_index, selected = ranked[0]
        second_ratio = ranked[1][1].fill_ratio if len(ranked) > 1 else 0.0
        margin = selected.fill_ratio - second_ratio
        is_marked = selected.fill_ratio >= 0.26 and margin >= 0.045
        confidence = min(99.0, max(0.0, (selected.fill_ratio - 0.18) * 360.0 + margin * 520.0))

        if not is_marked:
            values.append("?")
            warnings.append(f"Student ID digit {row_index + 1} is ambiguous.")
        else:
            values.append(str(selected_index))
        confidences.append(confidence)
        digit_payloads.append({
            "position": row_index + 1,
            "value": str(selected_index) if is_marked else None,
            "confidence": round(confidence, 2),
            "fill_ratio": round(selected.fill_ratio, 4),
            "region": _region(selected),
        })

    value = "".join(values) if all(v != "?" for v in values) else None
    overall = round(sum(confidences) / len(confidences), 2) if confidences else 0.0
    return StudentIdResult(value=value, confidence=overall, digits=digit_payloads, warnings=warnings)


def extract_objective_answers(
    *,
    image: Any,
    bubbles: list[Bubble],
    questions: list[dict[str, Any]],
    student_digits: int = 6,
) -> list[ObjectiveAnswerResult]:
    height, width = image.shape[:2]
    answer_bubbles = [
        b for b in bubbles
        if not (b.x > width * 0.42 and b.y < height * 0.34)
        and b.y > height * 0.12
    ]
    rows = _group_rows(answer_bubbles, tolerance=max(14, int(height * 0.006)))
    rows = [sorted(row, key=lambda b: b.x) for row in rows]
    rows = sorted(rows, key=lambda row: sum(b.y for b in row) / len(row))

    results: list[ObjectiveAnswerResult] = []
    cursor = 0
    objective_questions = [q for q in questions if _normal_type(q.get("type")) in {"multiple_choice", "multi_select", "true_false"}]

    for question_index, question in enumerate(objective_questions, start=1):
        qtype = _normal_type(question.get("type"))
        option_count = _option_count(question)
        exam_question_id = _safe_int(question.get("exam_question_id"))
        question_number = _safe_int(question.get("question_number")) or question_index

        if qtype == "true_false":
            needed_rows = 1
            needed_bubbles = 2
        else:
            needed_rows = option_count
            needed_bubbles = 1

        consumed: list[list[Bubble]] = []
        while cursor < len(rows) and len(consumed) < needed_rows:
            row = rows[cursor]
            cursor += 1
            if qtype == "true_false":
                if len(row) >= 2:
                    consumed.append(row[:2])
            else:
                if len(row) >= 1:
                    consumed.append([row[0]])

        if len(consumed) < needed_rows:
            results.append(ObjectiveAnswerResult(
                exam_question_id=exam_question_id,
                question_number=question_number,
                type=qtype,
                detected_answer=None,
                detected_answers=[],
                selected_option_index=None,
                selected_option_indices=None,
                confidence=0.0,
                status="needs_review",
                regions=[],
            ))
            continue

        flat = [bubble for row in consumed for bubble in row[:needed_bubbles]]
        selected_indices = _select_bubbles(flat if qtype == "true_false" else [row[0] for row in consumed], allow_multiple=qtype == "multi_select")
        labels = [_OPTION_LABELS[i] for i in selected_indices if i < len(_OPTION_LABELS)]
        if qtype == "true_false":
            labels = ["true" if i == 0 else "false" for i in selected_indices]

        confidence = _answer_confidence(flat, selected_indices)
        status = "detected" if labels and confidence >= 62 else "needs_review"
        results.append(ObjectiveAnswerResult(
            exam_question_id=exam_question_id,
            question_number=question_number,
            type=qtype,
            detected_answer=labels[0] if len(labels) == 1 else None,
            detected_answers=labels,
            selected_option_index=selected_indices[0] if len(selected_indices) == 1 and qtype != "multi_select" else None,
            selected_option_indices=selected_indices if qtype == "multi_select" else None,
            confidence=round(confidence, 2),
            status=status,
            regions=[_region(b) for b in flat],
        ))

    return results


def _select_bubbles(bubbles: list[Bubble], *, allow_multiple: bool) -> list[int]:
    if not bubbles:
        return []
    if allow_multiple:
        return [index for index, bubble in enumerate(bubbles) if bubble.fill_ratio >= 0.27]

    ranked = sorted(enumerate(bubbles), key=lambda item: item[1].fill_ratio, reverse=True)
    selected_index, selected = ranked[0]
    second_ratio = ranked[1][1].fill_ratio if len(ranked) > 1 else 0.0
    if selected.fill_ratio >= 0.26 and selected.fill_ratio - second_ratio >= 0.04:
        return [selected_index]
    return []


def _answer_confidence(bubbles: list[Bubble], selected_indices: list[int]) -> float:
    if not bubbles or not selected_indices:
        return 0.0
    ratios = [b.fill_ratio for b in bubbles]
    selected = max(ratios[i] for i in selected_indices if i < len(ratios))
    unselected = [ratio for index, ratio in enumerate(ratios) if index not in selected_indices]
    next_ratio = max(unselected) if unselected else 0.0
    margin = selected - next_ratio
    return min(99.0, max(0.0, (selected - 0.18) * 350.0 + margin * 550.0))


def _group_rows(bubbles: list[Bubble], tolerance: int) -> list[list[Bubble]]:
    rows: list[list[Bubble]] = []
    for bubble in sorted(bubbles, key=lambda b: b.y):
        placed = False
        for row in rows:
            row_y = sum(item.y for item in row) / len(row)
            if abs(row_y - bubble.y) <= tolerance:
                row.append(bubble)
                placed = True
                break
        if not placed:
            rows.append([bubble])
    return rows


def _normal_type(value: Any) -> str:
    return str(value or "").strip().lower()


def _option_count(question: dict[str, Any]) -> int:
    if _normal_type(question.get("type")) == "true_false":
        return 2
    options = question.get("options")
    if isinstance(options, list) and options:
        return len(options)
    if isinstance(options, dict):
        for key in ("options", "choices", "answers"):
            value = options.get(key)
            if isinstance(value, list) and value:
                return len(value)
    return 4


def _safe_int(value: Any) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _region(bubble: Bubble) -> dict[str, int | float]:
    size = bubble.r * 2
    return {
        "x": int(bubble.x - bubble.r),
        "y": int(bubble.y - bubble.r),
        "w": int(size),
        "h": int(size),
        "fill_ratio": round(bubble.fill_ratio, 4),
    }
