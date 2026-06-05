from __future__ import annotations

from fastapi import APIRouter, Depends, File, Form, UploadFile, status
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app.core.deps import get_current_user
from app.db.session import get_db

from . import service
from .schemas import (
    ExamCorrectionResponse,
    ExamScanAnalyzeResponse,
    ExamScanSubmitRequest,
    ExamScanSubmitResponse,
    OcrHealthResponse,
)

router = APIRouter(prefix="/ocr", tags=["OCR"])


@router.get("/health", response_model=OcrHealthResponse, status_code=status.HTTP_200_OK)
def get_ocr_health(
    current_user: dict = Depends(get_current_user),
):
    service.ensure_instructor(current_user)
    return service.ocr_health()


@router.post(
    "/exam-scan/analyze",
    response_model=ExamScanAnalyzeResponse,
    status_code=status.HTTP_200_OK,
)
async def analyze_exam_scan(
    files: list[UploadFile] = File(..., description="Solved printed exam pages as images or PDFs"),
    lang: str = Form(default="eng", description="OCR language for written answers: eng, ara, or ara+eng"),
    exam_id: int | None = Form(default=None, description="Optional fallback when QR cannot be read"),
    course_id: int | None = Form(default=None, description="Optional fallback when QR cannot be read"),
    student_id_digits: int = Form(default=6, description="Number of Student ID bubble rows printed on the sheet"),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    service.ensure_instructor(current_user)
    normalised_lang = service.normalise_lang(lang)
    payloads = [await file.read() for file in files]

    return await run_in_threadpool(
        service.analyze_exam_scan_files,
        uploaded_files=files,
        file_payloads=payloads,
        lang=normalised_lang,
        db=db,
        current_user=current_user,
        fallback_exam_id=exam_id,
        fallback_course_id=course_id,
        student_id_digits=student_id_digits,
    )


@router.post(
    "/exam-scan/submit",
    response_model=ExamScanSubmitResponse,
    status_code=status.HTTP_201_CREATED,
)
def submit_exam_scan(
    payload: ExamScanSubmitRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    return service.submit_exam_scan(payload=payload, db=db, current_user=current_user)


@router.post(
    "/exam-correction",
    response_model=ExamCorrectionResponse,
    status_code=status.HTTP_200_OK,
)
async def correct_exam_scans(
    files: list[UploadFile] = File(..., description="Exam scan images or scanned PDFs"),
    lang: str = Form(default="eng", description="Tesseract language: eng, ara, or ara+eng"),
    answer_key_json: str | None = Form(default=None, description="Optional JSON answer key"),
    current_user: dict = Depends(get_current_user),
):
    service.ensure_instructor(current_user)
    normalised_lang = service.normalise_lang(lang)
    answer_key = service.parse_answer_key(answer_key_json)
    payloads = [await file.read() for file in files]

    return await run_in_threadpool(
        service.correct_exam_files,
        uploaded_files=files,
        file_payloads=payloads,
        lang=normalised_lang,
        answer_key=answer_key,
    )
