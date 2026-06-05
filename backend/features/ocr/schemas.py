from __future__ import annotations

from typing import Optional
from pydantic import BaseModel, ConfigDict, Field


class OcrHealthResponse(BaseModel):
    available: bool
    engine: str = "tesseract"
    version: Optional[str] = None
    languages: list[str] = Field(default_factory=list)
    detail: Optional[str] = None

    model_config = ConfigDict(extra="forbid")


class ExamParsedAnswer(BaseModel):
    question_number: int = Field(..., ge=1)
    answer: str = Field(..., min_length=1, max_length=8)
    source_text: Optional[str] = None

    model_config = ConfigDict(extra="forbid")


class ExamGradeItem(BaseModel):
    question_number: int = Field(..., ge=1)
    expected_answer: str = Field(..., min_length=1, max_length=8)
    detected_answer: Optional[str] = Field(default=None, max_length=8)
    is_correct: bool = False

    model_config = ConfigDict(extra="forbid")


class ExamFileCorrectionResult(BaseModel):
    filename: str
    mime_type: Optional[str] = None
    pages: int = Field(..., ge=0)
    text: str
    confidence: float = Field(..., ge=0, le=100)
    word_count: int = Field(..., ge=0)
    parsed_answers: list[ExamParsedAnswer] = Field(default_factory=list)
    grade_items: list[ExamGradeItem] = Field(default_factory=list)
    total_questions: int = Field(default=0, ge=0)
    correct_answers: int = Field(default=0, ge=0)
    unanswered_questions: int = Field(default=0, ge=0)
    score_percent: Optional[float] = Field(default=None, ge=0, le=100)
    low_confidence: bool = False
    warnings: list[str] = Field(default_factory=list)

    model_config = ConfigDict(extra="forbid")


class ExamCorrectionSummary(BaseModel):
    files: int = Field(..., ge=0)
    pages: int = Field(..., ge=0)
    graded_files: int = Field(..., ge=0)
    average_confidence: float = Field(..., ge=0, le=100)
    total_questions: int = Field(..., ge=0)
    correct_answers: int = Field(..., ge=0)
    unanswered_questions: int = Field(..., ge=0)
    score_percent: Optional[float] = Field(default=None, ge=0, le=100)

    model_config = ConfigDict(extra="forbid")


class ExamCorrectionResponse(BaseModel):
    language: str
    answer_key_provided: bool
    summary: ExamCorrectionSummary
    results: list[ExamFileCorrectionResult] = Field(default_factory=list)

    model_config = ConfigDict(extra="forbid")


class ExamScanStudent(BaseModel):
    student_id: Optional[str] = None
    user_id: Optional[int] = None
    name: Optional[str] = None
    source: str = "id_bubbles"
    confidence: float = Field(default=0, ge=0, le=100)
    digits: list[dict] = Field(default_factory=list)

    model_config = ConfigDict(extra="forbid")


class ExamScanExam(BaseModel):
    exam_id: Optional[int] = None
    course_id: Optional[int] = None
    title: Optional[str] = None
    exam_type: Optional[str] = None
    template_version: str = "v1"

    model_config = ConfigDict(extra="forbid")


class ExamScanPage(BaseModel):
    page_number: int = Field(..., ge=1)
    filename: str
    alignment_status: str
    alignment_confidence: float = Field(default=0, ge=0, le=100)
    qr_detected: bool = False
    bubble_count: int = Field(default=0, ge=0)
    warnings: list[str] = Field(default_factory=list)

    model_config = ConfigDict(extra="forbid")


class ExamScanAnswer(BaseModel):
    exam_question_id: Optional[int] = None
    question_number: int = Field(..., ge=1)
    type: str
    detected_answer: Optional[str] = None
    detected_answers: list[str] = Field(default_factory=list)
    selected_option_index: Optional[int] = None
    selected_option_indices: Optional[list[int]] = None
    answer_text: Optional[str] = None
    confidence: float = Field(default=0, ge=0, le=100)
    status: str
    is_correct: Optional[bool] = None
    points_earned: Optional[float] = None
    max_score: Optional[float] = None
    regions: list[dict] = Field(default_factory=list)
    answer_region: Optional[dict] = None
    ai_grading_payload: Optional[dict] = None
    ai_score: Optional[float] = None

    model_config = ConfigDict(extra="forbid")


class ExamScanGradePreview(BaseModel):
    score_so_far: float = 0
    total_score: float = 0
    auto_gradable_questions: int = 0
    detected_questions: int = 0
    written_questions: int = 0
    needs_review: int = 0
    ai_ready: int = 0

    model_config = ConfigDict(extra="forbid")


class ExamScanAnalyzeResponse(BaseModel):
    scan_id: str
    status: str
    language: str
    exam: ExamScanExam
    student: ExamScanStudent
    pages: list[ExamScanPage] = Field(default_factory=list)
    answers: list[ExamScanAnswer] = Field(default_factory=list)
    grade_preview: ExamScanGradePreview
    warnings: list[str] = Field(default_factory=list)

    model_config = ConfigDict(extra="forbid")


class ExamScanSubmitAnswer(BaseModel):
    exam_question_id: int
    type: str
    selected_option_index: Optional[int] = None
    selected_option_indices: Optional[list[int]] = None
    answer_text: Optional[str] = None
    is_correct: Optional[bool] = None
    points_earned: Optional[float] = None
    auto_graded: bool = False
    teacher_feedback: Optional[str] = None

    model_config = ConfigDict(extra="forbid")


class ExamScanSubmitRequest(BaseModel):
    scan_id: str
    exam_id: int
    student_id: int
    answers: list[ExamScanSubmitAnswer] = Field(default_factory=list)
    total_score: Optional[float] = None
    percentage_score: Optional[float] = None
    teacher_feedback: Optional[str] = None

    model_config = ConfigDict(extra="forbid")


class ExamScanSubmitResponse(BaseModel):
    attempt_id: int
    exam_id: int
    student_id: int
    answer_count: int
    status: str

    model_config = ConfigDict(extra="forbid")
