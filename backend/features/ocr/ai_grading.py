from __future__ import annotations

from typing import Any


def estimate_written_ai_preview(answer: dict[str, Any]) -> dict[str, Any]:
    """Local preview only. Real scoring is delegated to the external AI grader.

    The frontend needs a production-friendly status before submit; this function
    never pretends to be final grading.
    """
    text = str(answer.get("answer_text") or "").strip()
    confidence = float(answer.get("confidence") or 0)
    if not text:
        return {"score": None, "confidence": 0, "status": "needs_review", "feedback": "No written text was confidently extracted."}
    status = "ai_ready" if confidence >= 55 else "needs_review"
    return {"score": None, "confidence": round(confidence, 2), "status": status, "feedback": "Ready for AI grading with image crop/OCR text context."}
