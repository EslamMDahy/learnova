from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(slots=True)
class AlignmentResult:
    image: Any
    confidence: float
    status: str
    warnings: list[str]


def align_exam_page(image: Any) -> AlignmentResult:
    """Deskew/perspective-normalise a printed exam page.

    The function is deliberately conservative: it applies a transform only when
    it detects a stable page contour. A bad transform is worse than no transform
    for answer extraction.
    """
    try:
        import cv2
        import numpy as np
    except Exception:
        return AlignmentResult(image=image, confidence=0.0, status="not_available", warnings=["OpenCV is unavailable; page alignment skipped."])

    if image is None:
        return AlignmentResult(image=image, confidence=0.0, status="failed", warnings=["Empty page image."])

    height, width = image.shape[:2]
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    edges = cv2.Canny(blurred, 50, 150)
    contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return AlignmentResult(image=image, confidence=60.0, status="fallback", warnings=["Page contour not found; used original scan."])

    page_area = float(height * width)
    best = None
    best_area = 0.0
    for contour in contours:
        area = float(cv2.contourArea(contour))
        if area < page_area * 0.25:
            continue
        perimeter = cv2.arcLength(contour, True)
        approx = cv2.approxPolyDP(contour, 0.02 * perimeter, True)
        if len(approx) == 4 and area > best_area:
            best = approx.reshape(4, 2)
            best_area = area

    if best is None:
        return AlignmentResult(image=image, confidence=70.0, status="fallback", warnings=["Stable page contour not detected; used original scan."])

    ordered = _order_points(best)
    target_width = 2480
    target_height = 3508
    destination = np.array(
        [[0, 0], [target_width - 1, 0], [target_width - 1, target_height - 1], [0, target_height - 1]],
        dtype="float32",
    )
    matrix = cv2.getPerspectiveTransform(ordered, destination)
    warped = cv2.warpPerspective(image, matrix, (target_width, target_height))

    confidence = min(99.0, max(75.0, (best_area / page_area) * 100.0))
    return AlignmentResult(image=warped, confidence=round(confidence, 2), status="aligned", warnings=[])


def _order_points(points: Any):
    import numpy as np

    rect = np.zeros((4, 2), dtype="float32")
    s = points.sum(axis=1)
    rect[0] = points[np.argmin(s)]
    rect[2] = points[np.argmax(s)]
    diff = np.diff(points, axis=1)
    rect[1] = points[np.argmin(diff)]
    rect[3] = points[np.argmax(diff)]
    return rect
