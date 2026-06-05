from __future__ import annotations

import json
import re
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path
from typing import Any, Iterable, Optional

from fastapi import HTTPException, UploadFile

from app.core.config import settings


_IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".tif", ".tiff", ".bmp"}
_PDF_EXTENSIONS = {".pdf"}
_ALLOWED_IMAGE_MIME_TYPES = {
    "image/png",
    "image/jpeg",
    "image/jpg",
    "image/webp",
    "image/tiff",
    "image/bmp",
    "application/octet-stream",
    "",
}
_ALLOWED_PDF_MIME_TYPES = {
    "application/pdf",
    "application/octet-stream",
    "",
}
_ALLOWED_LANGS = {"eng", "ara", "ara+eng", "eng+ara"}
_ANSWER_RE = re.compile(
    r"(?im)^\s*(?:q(?:uestion)?\s*)?(\d{1,3})\s*[\).:\-]?\s*([A-E])\b"
)
_KEY_RE = re.compile(r"(?i)^\s*(?:q(?:uestion)?\s*)?(\d{1,3})\s*[=:\-\).,\s]+\s*([A-E])\s*$")


@dataclass(slots=True)
class _PageOcr:
    text: str
    confidence: float
    word_count: int


@dataclass(slots=True)
class _LoadedDocument:
    pages: list[Any]
    warnings: list[str]


def ensure_instructor(current_user: dict) -> None:
    role = (current_user.get("system_role") or "").strip().lower()
    if role != "instructor":
        raise HTTPException(status_code=403, detail="Only instructors can use exam OCR correction")


def normalise_lang(lang: str) -> str:
    value = (lang or "eng").strip().lower().replace(" ", "")
    if value == "eng+ara":
        value = "ara+eng"
    if value not in _ALLOWED_LANGS:
        raise HTTPException(status_code=400, detail="Unsupported OCR language")
    return value


def parse_answer_key(raw: Optional[str]) -> dict[int, str]:
    if raw is None or not raw.strip():
        return {}

    try:
        decoded = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail="answer_key_json must be valid JSON") from exc

    if isinstance(decoded, dict):
        items = decoded.items()
    elif isinstance(decoded, list):
        items = []
        for item in decoded:
            if not isinstance(item, dict):
                raise HTTPException(status_code=400, detail="answer key list items must be objects")
            question = item.get("question_number") or item.get("question") or item.get("q")
            answer = item.get("answer") or item.get("expected_answer")
            items.append((question, answer))
    else:
        raise HTTPException(status_code=400, detail="answer_key_json must be an object or list")

    answer_key: dict[int, str] = {}
    for question, answer in items:
        try:
            qn = int(str(question).strip())
        except (TypeError, ValueError) as exc:
            raise HTTPException(status_code=400, detail="answer key question numbers must be integers") from exc
        ans = str(answer or "").strip().upper()
        if not re.fullmatch(r"[A-E]", ans):
            raise HTTPException(status_code=400, detail="answer key answers must be A, B, C, D or E")
        if qn <= 0:
            raise HTTPException(status_code=400, detail="answer key question numbers must be positive")
        answer_key[qn] = ans
    return answer_key


def parse_answer_key_text(raw: str) -> dict[int, str]:
    answer_key: dict[int, str] = {}
    for line in raw.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        match = _KEY_RE.match(stripped)
        if not match:
            raise HTTPException(status_code=400, detail=f"Invalid answer key line: {stripped}")
        answer_key[int(match.group(1))] = match.group(2).upper()
    return answer_key


def ocr_health() -> dict[str, Any]:
    try:
        pytesseract = _import_pytesseract()
        version = str(pytesseract.get_tesseract_version())
        try:
            langs = sorted(str(lang) for lang in pytesseract.get_languages(config=""))
        except Exception:
            langs = []
        return {
            "available": True,
            "engine": "tesseract",
            "version": version,
            "languages": langs,
            "detail": None,
        }
    except Exception as exc:
        return {
            "available": False,
            "engine": "tesseract",
            "version": None,
            "languages": [],
            "detail": str(exc),
        }


def correct_exam_files(
    *,
    uploaded_files: list[UploadFile],
    file_payloads: list[bytes],
    lang: str,
    answer_key: dict[int, str],
) -> dict[str, Any]:
    if not uploaded_files:
        raise HTTPException(status_code=400, detail="At least one file is required")

    max_files = int(getattr(settings, "ocr_max_files", 12))
    if len(uploaded_files) > max_files:
        raise HTTPException(status_code=400, detail=f"A maximum of {max_files} files is allowed per request")

    lang = normalise_lang(lang)
    _assert_engine_ready(lang)

    results: list[dict[str, Any]] = []
    for upload, raw in zip(uploaded_files, file_payloads, strict=True):
        results.append(_process_one_file(upload, raw, lang, answer_key))

    pages = sum(int(result["pages"]) for result in results)
    confidence_values = [float(result["confidence"]) for result in results if int(result["word_count"]) > 0]
    avg_confidence = round(sum(confidence_values) / len(confidence_values), 2) if confidence_values else 0.0
    graded = [r for r in results if r["total_questions"] > 0]
    total_questions = sum(int(result["total_questions"]) for result in results)
    correct_answers = sum(int(result["correct_answers"]) for result in results)
    unanswered = sum(int(result["unanswered_questions"]) for result in results)
    score_percent = round((correct_answers / total_questions) * 100, 2) if total_questions else None

    return {
        "language": lang,
        "answer_key_provided": bool(answer_key),
        "summary": {
            "files": len(results),
            "pages": pages,
            "graded_files": len(graded),
            "average_confidence": avg_confidence,
            "total_questions": total_questions,
            "correct_answers": correct_answers,
            "unanswered_questions": unanswered,
            "score_percent": score_percent,
        },
        "results": results,
    }


def _process_one_file(
    upload: UploadFile,
    raw: bytes,
    lang: str,
    answer_key: dict[int, str],
) -> dict[str, Any]:
    filename = (upload.filename or "scan").strip() or "scan"
    mime_type = (upload.content_type or "").strip().lower()
    max_file_bytes = int(getattr(settings, "ocr_max_file_bytes", 15 * 1024 * 1024))

    if not raw:
        raise HTTPException(status_code=400, detail=f"{filename}: empty file")
    if len(raw) > max_file_bytes:
        mb = max_file_bytes // (1024 * 1024)
        raise HTTPException(status_code=413, detail=f"{filename}: file exceeds {mb} MB limit")

    document = _load_document(raw=raw, filename=filename, mime_type=mime_type)
    if not document.pages:
        raise HTTPException(status_code=400, detail=f"{filename}: no readable pages found")

    page_results = [_ocr_page(page, lang) for page in document.pages]
    text_parts = [result.text for result in page_results if result.text.strip()]
    text = "\n\n".join(text_parts).strip()
    word_count = sum(result.word_count for result in page_results)
    confidence = _weighted_confidence(page_results)
    parsed_answers = _parse_answers(text)
    grade_items = _grade_answers(answer_key, parsed_answers)

    warnings = list(document.warnings)
    low_confidence_threshold = float(getattr(settings, "ocr_low_confidence_threshold", 55.0))
    low_confidence = confidence < low_confidence_threshold or word_count == 0
    if low_confidence:
        warnings.append("Low OCR confidence. Review the extracted text before using the grade.")
    if not text:
        warnings.append("No text was extracted. Try a sharper scan with higher contrast.")
    if answer_key and not parsed_answers:
        warnings.append("No objective answers were detected. Check scan layout or grade manually from OCR text.")

    total_questions = len(grade_items)
    correct_answers = sum(1 for item in grade_items if item["is_correct"])
    unanswered = sum(1 for item in grade_items if not item.get("detected_answer"))
    score_percent = round((correct_answers / total_questions) * 100, 2) if total_questions else None

    return {
        "filename": filename,
        "mime_type": mime_type or None,
        "pages": len(document.pages),
        "text": text,
        "confidence": confidence,
        "word_count": word_count,
        "parsed_answers": parsed_answers,
        "grade_items": grade_items,
        "total_questions": total_questions,
        "correct_answers": correct_answers,
        "unanswered_questions": unanswered,
        "score_percent": score_percent,
        "low_confidence": low_confidence,
        "warnings": warnings,
    }


def _load_document(*, raw: bytes, filename: str, mime_type: str) -> _LoadedDocument:
    suffix = Path(filename).suffix.lower()
    if suffix in _PDF_EXTENSIONS or mime_type == "application/pdf":
        if mime_type not in _ALLOWED_PDF_MIME_TYPES:
            raise HTTPException(status_code=400, detail=f"{filename}: unsupported PDF content type")
        return _load_pdf(raw)

    if suffix in _IMAGE_EXTENSIONS or mime_type.startswith("image/"):
        if mime_type not in _ALLOWED_IMAGE_MIME_TYPES and not mime_type.startswith("image/"):
            raise HTTPException(status_code=400, detail=f"{filename}: unsupported image content type")
        return _load_image(raw)

    raise HTTPException(status_code=400, detail=f"{filename}: only image and PDF files are supported")


def _load_image(raw: bytes) -> _LoadedDocument:
    cv2, np = _import_cv2_numpy()
    arr = np.frombuffer(raw, np.uint8)
    image = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if image is None:
        raise HTTPException(status_code=400, detail="Invalid image file")
    return _LoadedDocument(pages=[image], warnings=[])


def _load_pdf(raw: bytes) -> _LoadedDocument:
    try:
        import fitz  # PyMuPDF
    except Exception as exc:
        raise HTTPException(status_code=503, detail="PDF OCR requires PyMuPDF. Install pymupdf.") from exc

    cv2, np = _import_cv2_numpy()
    max_pages = int(getattr(settings, "ocr_max_pdf_pages", 8))
    dpi = int(getattr(settings, "ocr_pdf_render_dpi", 300))
    warnings: list[str] = []

    try:
        document = fitz.open(stream=raw, filetype="pdf")
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Invalid PDF file") from exc

    if document.page_count > max_pages:
        warnings.append(f"Only the first {max_pages} pages were processed from a {document.page_count}-page PDF.")

    pages: list[Any] = []
    zoom = max(72, dpi) / 72.0
    matrix = fitz.Matrix(zoom, zoom)
    for page_index in range(min(document.page_count, max_pages)):
        page = document.load_page(page_index)
        pixmap = page.get_pixmap(matrix=matrix, alpha=False)
        png_bytes = pixmap.tobytes("png")
        arr = np.frombuffer(png_bytes, np.uint8)
        image = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if image is not None:
            pages.append(image)

    document.close()
    return _LoadedDocument(pages=pages, warnings=warnings)


def _ocr_page(image: Any, lang: str) -> _PageOcr:
    pytesseract = _import_pytesseract()
    cv2, np = _import_cv2_numpy()
    from pytesseract import Output

    image = _normalise_orientation(image)
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    gray = _resize_for_ocr(gray)
    gray = cv2.fastNlMeansDenoising(gray, None, 10, 7, 21)

    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(gray)
    thresholded = cv2.adaptiveThreshold(
        enhanced,
        255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY,
        31,
        11,
    )

    candidates = [
        (thresholded, "--oem 3 --psm 6"),
        (enhanced, "--oem 3 --psm 6"),
        (thresholded, "--oem 3 --psm 11"),
    ]

    best: _PageOcr | None = None
    for candidate, config in candidates:
        try:
            data = pytesseract.image_to_data(candidate, lang=lang, config=config, output_type=Output.DICT)
        except Exception as exc:
            raise HTTPException(status_code=503, detail=f"OCR engine failed: {exc}") from exc
        current = _page_from_tesseract_data(data)
        if best is None or _ocr_quality(current) > _ocr_quality(best):
            best = current

    return best or _PageOcr(text="", confidence=0.0, word_count=0)


def _normalise_orientation(image: Any) -> Any:
    pytesseract = _import_pytesseract()
    cv2, _ = _import_cv2_numpy()
    try:
        osd = pytesseract.image_to_osd(image)
    except Exception:
        return image

    angle_match = re.search(r"Rotate:\s+(\d+)", osd)
    if not angle_match:
        return image

    angle = int(angle_match.group(1)) % 360
    if angle == 90:
        return cv2.rotate(image, cv2.ROTATE_90_CLOCKWISE)
    if angle == 180:
        return cv2.rotate(image, cv2.ROTATE_180)
    if angle == 270:
        return cv2.rotate(image, cv2.ROTATE_90_COUNTERCLOCKWISE)
    return image


def _resize_for_ocr(gray: Any) -> Any:
    cv2, _ = _import_cv2_numpy()
    height, width = gray.shape[:2]
    longest = max(height, width)
    if longest < 1600:
        scale = 1600 / longest
    elif longest > 3600:
        scale = 3600 / longest
    else:
        scale = 1.0
    if abs(scale - 1.0) < 0.01:
        return gray
    return cv2.resize(gray, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)


def _page_from_tesseract_data(data: dict[str, list[Any]]) -> _PageOcr:
    tokens: list[str] = []
    confidences: list[float] = []
    lines: dict[tuple[int, int, int], list[str]] = {}

    text_values = data.get("text", [])
    conf_values = data.get("conf", [])
    blocks = data.get("block_num", [])
    paragraphs = data.get("par_num", [])
    line_numbers = data.get("line_num", [])

    for index, text in enumerate(text_values):
        token = str(text or "").strip()
        if not token:
            continue

        try:
            conf = float(conf_values[index])
        except (IndexError, TypeError, ValueError):
            conf = -1.0

        try:
            key = (int(blocks[index]), int(paragraphs[index]), int(line_numbers[index]))
        except (IndexError, TypeError, ValueError):
            key = (0, 0, index)

        tokens.append(token)
        lines.setdefault(key, []).append(token)
        if conf >= 0:
            confidences.append(conf)

    ordered_lines = [" ".join(lines[key]) for key in sorted(lines)]
    text = _clean_ocr_text("\n".join(ordered_lines))
    confidence_value = round(sum(confidences) / len(confidences), 2) if confidences else 0.0
    return _PageOcr(text=text, confidence=confidence_value, word_count=len(tokens))


def _clean_ocr_text(raw: str) -> str:
    text = re.sub(r"[ \t]+", " ", raw)
    text = re.sub(r"\s+([).,:;])", r"\1", text)
    text = re.sub(r"([\n\r]){3,}", "\n\n", text)
    return text.strip()


def _weighted_confidence(results: Iterable[_PageOcr]) -> float:
    weighted = 0.0
    weight = 0
    for result in results:
        page_weight = max(1, result.word_count)
        weighted += result.confidence * page_weight
        weight += page_weight
    return round(weighted / weight, 2) if weight else 0.0


def _ocr_quality(result: _PageOcr) -> float:
    return (result.confidence * 1.2) + min(result.word_count, 400) * 0.25 + len(result.text) * 0.005


def _parse_answers(text: str) -> list[dict[str, Any]]:
    answers: dict[int, dict[str, Any]] = {}
    for match in _ANSWER_RE.finditer(text or ""):
        qn = int(match.group(1))
        if qn in answers:
            continue
        answer = match.group(2).upper()
        source_start = max(0, match.start() - 20)
        source_end = min(len(text), match.end() + 40)
        answers[qn] = {
            "question_number": qn,
            "answer": answer,
            "source_text": text[source_start:source_end].strip(),
        }
    return [answers[key] for key in sorted(answers)]


def _grade_answers(
    answer_key: dict[int, str],
    parsed_answers: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    if not answer_key:
        return []
    detected = {
        int(item["question_number"]): str(item["answer"]).strip().upper()
        for item in parsed_answers
    }
    grade_items: list[dict[str, Any]] = []
    for question_number in sorted(answer_key):
        expected = answer_key[question_number]
        actual = detected.get(question_number)
        grade_items.append({
            "question_number": question_number,
            "expected_answer": expected,
            "detected_answer": actual,
            "is_correct": actual == expected,
        })
    return grade_items


def _assert_engine_ready(lang: str) -> None:
    health = ocr_health()
    if not health["available"]:
        raise HTTPException(status_code=503, detail=f"OCR engine unavailable: {health['detail']}")

    installed = set(health.get("languages") or [])
    missing = [part for part in lang.split("+") if installed and part not in installed]
    if missing:
        raise HTTPException(status_code=503, detail=f"Missing Tesseract language data: {', '.join(missing)}")


def _import_pytesseract():
    try:
        import pytesseract
        return pytesseract
    except Exception as exc:
        raise HTTPException(status_code=503, detail="OCR requires pytesseract and Tesseract to be installed") from exc


def _import_cv2_numpy():
    try:
        import cv2
        import numpy as np
        return cv2, np
    except Exception as exc:
        raise HTTPException(status_code=503, detail="OCR requires opencv-python and numpy") from exc

# =============================================================================
# Production scan pipeline: QR exam detection + Student-ID OMR + answer OMR/OCR
# =============================================================================


def analyze_exam_scan_files(
    *,
    uploaded_files: list[UploadFile],
    file_payloads: list[bytes],
    lang: str,
    db: Any,
    current_user: dict,
    fallback_exam_id: int | None = None,
    fallback_course_id: int | None = None,
    student_id_digits: int = 6,
) -> dict[str, Any]:
    """Analyze printed Learnova answer sheets.

    This is intentionally template-aware. Objective answers and the Student ID are
    read with OMR; handwritten/free-text answers are cropped and OCR'd for the AI
    grading service.
    """
    import uuid
    from sqlalchemy import text

    from .alignment import align_exam_page
    from .omr import detect_bubbles, extract_objective_answers, read_student_id
    from .qr import read_qr_from_image, verify_payload
    from .written_ocr import extract_written_answers

    ensure_instructor(current_user)
    if not uploaded_files:
        raise HTTPException(status_code=400, detail="At least one file is required")

    max_files = int(getattr(settings, "ocr_max_files", 12))
    if len(uploaded_files) > max_files:
        raise HTTPException(status_code=400, detail=f"A maximum of {max_files} files is allowed per request")

    lang = normalise_lang(lang)
    _assert_engine_ready(lang)

    scan_id = f"scan_{uuid.uuid4().hex[:16]}"
    warnings: list[str] = []
    page_payloads: list[dict[str, Any]] = []
    detected_metadata: dict[str, Any] = {}
    detected_student: dict[str, Any] | None = None
    all_objective_answers: list[dict[str, Any]] = []
    all_written_answers: list[dict[str, Any]] = []

    # Load files/pages first; detect QR before and after alignment.
    page_number = 0
    for upload, raw in zip(uploaded_files, file_payloads, strict=True):
        filename = (upload.filename or "scan").strip() or "scan"
        mime_type = (upload.content_type or "").strip().lower()
        max_file_bytes = int(getattr(settings, "ocr_max_file_bytes", 15 * 1024 * 1024))
        if not raw:
            raise HTTPException(status_code=400, detail=f"{filename}: empty file")
        if len(raw) > max_file_bytes:
            mb = max_file_bytes // (1024 * 1024)
            raise HTTPException(status_code=413, detail=f"{filename}: file exceeds {mb} MB limit")

        document = _load_document(raw=raw, filename=filename, mime_type=mime_type)
        for raw_page in document.pages:
            page_number += 1
            page_warnings = list(document.warnings)
            qr_payload = read_qr_from_image(raw_page)
            alignment = align_exam_page(raw_page)
            if alignment.warnings:
                page_warnings.extend(alignment.warnings)
            qr_payload = qr_payload or read_qr_from_image(alignment.image)
            qr_detected = bool(qr_payload)
            if qr_payload:
                if verify_payload(qr_payload):
                    detected_metadata.update(qr_payload)
                else:
                    page_warnings.append("QR code was detected but its signature is invalid.")

            bubbles = detect_bubbles(alignment.image)
            page_payloads.append({
                "page_number": page_number,
                "filename": filename,
                "image": alignment.image,
                "alignment_status": alignment.status,
                "alignment_confidence": alignment.confidence,
                "qr_detected": qr_detected,
                "bubbles": bubbles,
                "warnings": page_warnings,
            })

    exam_id = _safe_int(detected_metadata.get("exam_id")) or fallback_exam_id
    course_id = _safe_int(detected_metadata.get("course_id")) or fallback_course_id
    template_version = str(detected_metadata.get("template_version") or "v1")

    if not exam_id:
        warnings.append("Exam QR was not detected and no fallback exam_id was provided. Objective answers will be extracted without exam-question binding.")
    if exam_id and not course_id:
        course_id = _lookup_course_id_for_exam(db=db, exam_id=exam_id)

    exam_payload = _load_exam_payload(db=db, exam_id=exam_id, course_id=course_id) if exam_id and course_id else {}
    questions = _load_exam_questions_for_scan(db=db, exam_id=exam_id, course_id=course_id) if exam_id and course_id else []

    # Student ID appears on the first page only in the new print template.
    if page_payloads:
        student_result = read_student_id(
            page_payloads[0]["image"],
            page_payloads[0]["bubbles"],
            digits=max(1, int(student_id_digits or 6)),
        )
        if student_result.warnings:
            warnings.extend(student_result.warnings)
        detected_student = {
            "student_id": student_result.value,
            "user_id": None,
            "name": None,
            "source": "id_bubbles",
            "confidence": student_result.confidence,
            "digits": student_result.digits,
        }
        if student_result.value:
            student_row = _lookup_student(db=db, student_identifier=student_result.value, course_id=course_id)
            if student_row:
                detected_student.update({
                    "user_id": student_row.get("id"),
                    "student_id": student_row.get("student_id") or str(student_row.get("id")),
                    "name": student_row.get("full_name"),
                })
            else:
                warnings.append(f"Student ID {student_result.value} was read but no matching student was found.")

    # Extract objective answers with OMR. Dedupe across pages by question id/order.
    for page in page_payloads:
        objective_results = extract_objective_answers(
            image=page["image"],
            bubbles=page["bubbles"],
            questions=questions,
            student_digits=max(1, int(student_id_digits or 6)),
        )
        for item in objective_results:
            payload = {
                "exam_question_id": item.exam_question_id,
                "question_number": item.question_number,
                "type": item.type,
                "detected_answer": item.detected_answer,
                "detected_answers": item.detected_answers,
                "selected_option_index": item.selected_option_index,
                "selected_option_indices": item.selected_option_indices,
                "answer_text": None,
                "confidence": item.confidence,
                "status": item.status,
                "regions": item.regions,
                "answer_region": None,
                "ai_grading_payload": None,
                "ai_score": None,
            }
            _apply_objective_grade(payload, questions)
            all_objective_answers.append(payload)

    # OCR free-text boxes for AI grading. Dedupe by question id/order.
    for page in page_payloads:
        written_results = extract_written_answers(
            image=page["image"],
            questions=questions,
            lang=lang,
        )
        for item in written_results:
            all_written_answers.append({
                "exam_question_id": item.exam_question_id,
                "question_number": item.question_number,
                "type": item.type,
                "detected_answer": None,
                "detected_answers": [],
                "selected_option_index": None,
                "selected_option_indices": None,
                "answer_text": item.answer_text,
                "confidence": item.confidence,
                "status": item.status,
                "is_correct": None,
                "points_earned": None,
                "max_score": _question_points(item.exam_question_id, questions),
                "regions": [],
                "answer_region": item.region,
                "ai_grading_payload": item.ai_grading_payload,
                "ai_score": None,
            })

    answers = _dedupe_answers(all_objective_answers + all_written_answers)
    grade_preview = _build_scan_grade_preview(answers=answers, questions=questions, exam_payload=exam_payload)

    page_responses = [
        {
            "page_number": int(page["page_number"]),
            "filename": page["filename"],
            "alignment_status": page["alignment_status"],
            "alignment_confidence": float(page["alignment_confidence"]),
            "qr_detected": bool(page["qr_detected"]),
            "bubble_count": len(page["bubbles"]),
            "warnings": page["warnings"],
        }
        for page in page_payloads
    ]

    scan_status = "ready" if answers and grade_preview["needs_review"] == 0 and detected_student and detected_student.get("user_id") else "needs_review"
    return {
        "scan_id": scan_id,
        "status": scan_status,
        "language": lang,
        "exam": {
            "exam_id": exam_id,
            "course_id": course_id,
            "title": exam_payload.get("title"),
            "exam_type": exam_payload.get("exam_type"),
            "template_version": template_version,
        },
        "student": detected_student or {"student_id": None, "user_id": None, "name": None, "source": "id_bubbles", "confidence": 0, "digits": []},
        "pages": page_responses,
        "answers": answers,
        "grade_preview": grade_preview,
        "warnings": warnings,
    }


def submit_exam_scan(*, payload: Any, db: Any, current_user: dict) -> dict[str, Any]:
    from sqlalchemy import text

    ensure_instructor(current_user)
    instructor_id = current_user.get("id")
    if not instructor_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    exam_row = db.execute(
        text("""
            SELECT e.id, e.course_id, e.passing_score, e.created_by
            FROM exams e
            JOIN courses c ON c.id = e.course_id
            WHERE e.id = :exam_id
            LIMIT 1
        """),
        {"exam_id": payload.exam_id},
    ).mappings().first()
    if not exam_row:
        raise HTTPException(status_code=404, detail="Exam not found")
    if int(exam_row["created_by"]) != int(instructor_id):
        raise HTTPException(status_code=403, detail="You can only submit scans for your own exams")

    try:
        next_attempt = db.execute(
            text("""
                SELECT COALESCE(MAX(attempt_number), 0) + 1 AS attempt_number
                FROM student_exam_attempts
                WHERE student_id = :student_id AND exam_id = :exam_id
            """),
            {"student_id": payload.student_id, "exam_id": payload.exam_id},
        ).mappings().first()
        attempt_number = int(next_attempt["attempt_number"] if next_attempt else 1)
        total_score = float(payload.total_score or 0)
        percentage_score = payload.percentage_score
        if percentage_score is None:
            exam_total = db.execute(
                text("SELECT COALESCE(total_score, 0) AS total_score FROM exams WHERE id = :exam_id"),
                {"exam_id": payload.exam_id},
            ).mappings().first()
            max_total = float(exam_total["total_score"] or 0) if exam_total else 0
            percentage_score = round((total_score / max_total) * 100, 2) if max_total else None

        is_passed = None
        if percentage_score is not None and exam_row.get("passing_score") is not None:
            is_passed = float(percentage_score) >= float(exam_row["passing_score"])

        attempt = db.execute(
            text("""
                INSERT INTO student_exam_attempts (
                    student_id, exam_id, attempt_number, status,
                    started_at, submitted_at, graded_at,
                    total_score, percentage_score, is_passed,
                    teacher_feedback, teacher_reviewed_at, session_data
                ) VALUES (
                    :student_id, :exam_id, :attempt_number, 'graded',
                    NOW(), NOW(), NOW(),
                    :total_score, :percentage_score, :is_passed,
                    :teacher_feedback, NOW(), CAST(:session_data AS JSON)
                ) RETURNING id
            """),
            {
                "student_id": payload.student_id,
                "exam_id": payload.exam_id,
                "attempt_number": attempt_number,
                "total_score": total_score,
                "percentage_score": percentage_score,
                "is_passed": is_passed,
                "teacher_feedback": payload.teacher_feedback,
                "session_data": json.dumps({"source": "learnova_exam_scan", "scan_id": payload.scan_id}),
            },
        ).mappings().first()
        attempt_id = int(attempt["id"])

        for answer in payload.answers:
            db.execute(
                text("""
                    INSERT INTO student_answers (
                        attempt_id, exam_question_id, selected_option_index,
                        selected_option_indices, answer_text, is_correct,
                        points_earned, auto_graded, teacher_feedback,
                        teacher_reviewed_at, created_at, updated_at
                    ) VALUES (
                        :attempt_id, :exam_question_id, :selected_option_index,
                        CAST(:selected_option_indices AS JSON), :answer_text, :is_correct,
                        :points_earned, :auto_graded, :teacher_feedback,
                        NOW(), NOW(), NOW()
                    )
                """),
                {
                    "attempt_id": attempt_id,
                    "exam_question_id": answer.exam_question_id,
                    "selected_option_index": answer.selected_option_index,
                    "selected_option_indices": json.dumps(answer.selected_option_indices) if answer.selected_option_indices is not None else None,
                    "answer_text": answer.answer_text,
                    "is_correct": answer.is_correct,
                    "points_earned": answer.points_earned,
                    "auto_graded": bool(answer.auto_graded),
                    "teacher_feedback": answer.teacher_feedback,
                },
            )

        db.commit()
        return {
            "attempt_id": attempt_id,
            "exam_id": int(payload.exam_id),
            "student_id": int(payload.student_id),
            "answer_count": len(payload.answers),
            "status": "graded",
        }
    except HTTPException:
        db.rollback()
        raise
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to submit scan correction") from exc


def _lookup_course_id_for_exam(*, db: Any, exam_id: int) -> int | None:
    from sqlalchemy import text

    row = db.execute(text("SELECT course_id FROM exams WHERE id = :exam_id LIMIT 1"), {"exam_id": exam_id}).mappings().first()
    return int(row["course_id"]) if row else None


def _load_exam_payload(*, db: Any, exam_id: int, course_id: int) -> dict[str, Any]:
    from sqlalchemy import text

    row = db.execute(
        text("""
            SELECT id AS exam_id, course_id, title, exam_type, total_score
            FROM exams
            WHERE id = :exam_id AND course_id = :course_id
            LIMIT 1
        """),
        {"exam_id": exam_id, "course_id": course_id},
    ).mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Exam not found")
    return dict(row)


def _load_exam_questions_for_scan(*, db: Any, exam_id: int, course_id: int) -> list[dict[str, Any]]:
    from sqlalchemy import text

    exam_row = db.execute(
        text("SELECT is_published FROM exams WHERE id = :exam_id AND course_id = :course_id LIMIT 1"),
        {"exam_id": exam_id, "course_id": course_id},
    ).mappings().first()
    if not exam_row:
        raise HTTPException(status_code=404, detail="Exam not found")

    if bool(exam_row["is_published"]):
        query = text("""
            SELECT
                eq.id AS exam_question_id, eq.question_id, eq.section_id, eq.order_index,
                eq.points, eq.snapshot_question_text AS question_text,
                eq.snapshot_options AS options, eq.snapshot_type AS type,
                eq.snapshot_expected_answer AS expected_answer,
                eq.snapshot_grading_rubric AS grading_rubric,
                eq.snapshot_max_score AS max_score
            FROM exam_questions eq
            JOIN exam_sections es ON es.id = eq.section_id AND es.exam_id = eq.exam_id
            WHERE eq.exam_id = :exam_id
            ORDER BY es.order_index ASC, eq.order_index ASC, eq.id ASC
        """)
        rows = db.execute(query, {"exam_id": exam_id}).mappings().all()
    else:
        query = text("""
            SELECT
                eq.id AS exam_question_id, eq.question_id, eq.section_id, eq.order_index,
                eq.points, q.question_text, q.options, q.type,
                q.expected_answer, q.grading_rubric, q.max_score
            FROM exam_questions eq
            JOIN exam_sections es ON es.id = eq.section_id AND es.exam_id = eq.exam_id
            JOIN questions q ON q.id = eq.question_id
            WHERE eq.exam_id = :exam_id AND q.course_id = :course_id
            ORDER BY es.order_index ASC, eq.order_index ASC, eq.id ASC
        """)
        rows = db.execute(query, {"exam_id": exam_id, "course_id": course_id}).mappings().all()

    questions: list[dict[str, Any]] = []
    for index, row in enumerate(rows, start=1):
        question = dict(row)
        question["question_number"] = index
        questions.append(question)
    return questions


def _lookup_student(*, db: Any, student_identifier: str, course_id: int | None) -> dict[str, Any] | None:
    from sqlalchemy import text

    user_id = _safe_int(student_identifier)
    params: dict[str, Any] = {"student_identifier": student_identifier, "user_id": user_id}
    if course_id:
        params["course_id"] = course_id
        row = db.execute(
            text("""
                SELECT u.id, u.full_name, u.student_id
                FROM users u
                JOIN course_enrollments ce ON ce.student_id = u.id
                WHERE ce.course_id = :course_id
                  AND (u.student_id = :student_identifier OR u.id = :user_id)
                LIMIT 1
            """),
            params,
        ).mappings().first()
        if row:
            return dict(row)

    row = db.execute(
        text("""
            SELECT id, full_name, student_id
            FROM users
            WHERE student_id = :student_identifier OR id = :user_id
            LIMIT 1
        """),
        params,
    ).mappings().first()
    return dict(row) if row else None


def _apply_objective_grade(answer: dict[str, Any], questions: list[dict[str, Any]]) -> None:
    question = _find_question(answer.get("exam_question_id"), answer.get("question_number"), questions)
    answer["max_score"] = _question_points(answer.get("exam_question_id"), questions)
    if not question:
        answer["is_correct"] = None
        answer["points_earned"] = None
        return

    expected = _normalise_expected_answer(question.get("expected_answer"), question.get("type"))
    detected = _normalise_detected_answer(answer)
    if expected is None or detected is None:
        answer["is_correct"] = None
        answer["points_earned"] = None
        return

    is_correct = expected == detected
    answer["is_correct"] = is_correct
    answer["points_earned"] = float(question.get("points") or question.get("max_score") or 0) if is_correct else 0.0


def _normalise_expected_answer(raw: Any, question_type: Any) -> Any:
    qtype = str(question_type or "").strip().lower()
    if raw is None:
        return None
    if isinstance(raw, dict):
        value = raw.get("answer") or raw.get("correct_answer") or raw.get("expected_answer")
        values = raw.get("answers") or raw.get("correct_answers") or raw.get("correct_option_indices") or raw.get("correct_option_ids")
        if values is not None:
            raw = values
        elif value is not None:
            raw = value
    if qtype == "multi_select":
        if not isinstance(raw, list):
            raw = [raw]
        return sorted(_normalise_one_answer(item) for item in raw if _normalise_one_answer(item) is not None)
    return _normalise_one_answer(raw)


def _normalise_detected_answer(answer: dict[str, Any]) -> Any:
    qtype = str(answer.get("type") or "").strip().lower()
    if qtype == "multi_select":
        values = answer.get("detected_answers") or answer.get("selected_option_indices") or []
        return sorted(_normalise_one_answer(item) for item in values if _normalise_one_answer(item) is not None)
    return _normalise_one_answer(answer.get("detected_answer") if answer.get("detected_answer") is not None else answer.get("selected_option_index"))


def _normalise_one_answer(value: Any) -> Any:
    if value is None:
        return None
    if isinstance(value, int):
        return value
    text_value = str(value).strip().lower()
    if text_value in {"true", "t"}:
        return "true"
    if text_value in {"false", "f"}:
        return "false"
    if len(text_value) == 1 and "a" <= text_value <= "z":
        return ord(text_value) - ord("a")
    try:
        return int(text_value)
    except ValueError:
        return text_value.upper()


def _dedupe_answers(answers: list[dict[str, Any]]) -> list[dict[str, Any]]:
    best: dict[tuple[Any, Any, Any], dict[str, Any]] = {}
    for answer in answers:
        key = (answer.get("exam_question_id"), answer.get("question_number"), answer.get("type"))
        current = best.get(key)
        if current is None or float(answer.get("confidence") or 0) > float(current.get("confidence") or 0):
            best[key] = answer
    return sorted(best.values(), key=lambda item: (_safe_int(item.get("exam_question_id")) or 10**9, _safe_int(item.get("question_number")) or 10**9, str(item.get("type") or "")))


def _build_scan_grade_preview(*, answers: list[dict[str, Any]], questions: list[dict[str, Any]], exam_payload: dict[str, Any]) -> dict[str, Any]:
    score = sum(float(answer.get("points_earned") or 0) for answer in answers)
    total_score = float(exam_payload.get("total_score") or sum(float(q.get("points") or q.get("max_score") or 0) for q in questions))
    objective_types = {"multiple_choice", "multi_select", "true_false"}
    return {
        "score_so_far": round(score, 2),
        "total_score": round(total_score, 2),
        "auto_gradable_questions": sum(1 for q in questions if str(q.get("type") or "").lower() in objective_types),
        "detected_questions": sum(1 for answer in answers if answer.get("status") == "detected"),
        "written_questions": sum(1 for answer in answers if str(answer.get("type") or "").lower() in {"short_answer", "essay"}),
        "needs_review": sum(1 for answer in answers if answer.get("status") == "needs_review"),
        "ai_ready": sum(1 for answer in answers if answer.get("status") == "ai_ready"),
    }


def _find_question(exam_question_id: Any, question_number: Any, questions: list[dict[str, Any]]) -> dict[str, Any] | None:
    eqid = _safe_int(exam_question_id)
    qn = _safe_int(question_number)
    for question in questions:
        if eqid is not None and _safe_int(question.get("exam_question_id")) == eqid:
            return question
    for question in questions:
        if qn is not None and _safe_int(question.get("question_number")) == qn:
            return question
    return None


def _question_points(exam_question_id: Any, questions: list[dict[str, Any]]) -> float | None:
    question = _find_question(exam_question_id, None, questions)
    if not question:
        return None
    try:
        return float(question.get("points") or question.get("max_score") or 0)
    except (TypeError, ValueError):
        return None


def _safe_int(value: Any) -> int | None:
    try:
        if value is None or value == "":
            return None
        return int(str(value).strip())
    except (TypeError, ValueError):
        return None
