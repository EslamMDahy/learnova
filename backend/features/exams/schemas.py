from __future__ import annotations

from datetime import datetime
from typing import Any, List, Optional

from pydantic import BaseModel, Field


class ExamCreateRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
    instructions: Optional[str] = None
    exam_type: str
    duration_minutes: Optional[int] = Field(default=None, gt=0)
    max_attempts: int = Field(default=1, gt=0)
    passing_score: Optional[float] = Field(default=None, ge=0)
    shuffle_questions: bool = False
    shuffle_options: bool = False
    available_from: Optional[datetime] = None
    available_to: Optional[datetime] = None
    access_code: Optional[str] = Field(default=None, max_length=50)

class ExamResponse(BaseModel):
    id: int
    course_id: int
    title: str
    description: Optional[str]
    instructions: Optional[str]
    exam_type: str
    duration_minutes: Optional[int]
    max_attempts: int
    passing_score: Optional[float]
    total_questions: int
    total_score: float
    is_published: bool
    is_auto_generated: bool
    shuffle_questions: bool
    shuffle_options: bool
    available_from: Optional[datetime]
    available_to: Optional[datetime]
    enable_proctoring: bool
    prevent_copy_paste: bool
    prevent_tab_switch: bool
    require_webcam: bool
    require_microphone: bool
    access_code: Optional[str]
    ip_restrictions: Optional[dict]
    created_by: int
    created_at: datetime
    updated_at: datetime


class ExamAddQuestionsRequest(BaseModel):
    question_ids: List[int] = Field(..., min_length=1)

class ExamQuestionItemResponse(BaseModel):
    id: int
    exam_id: int
    section_id: Optional[int]
    question_id: int
    order_index: int
    points: float
    custom_points: Optional[float]
    custom_instructions: Optional[str]

class ExamAddQuestionsResponse(BaseModel):
    exam_id: int
    course_id: int
    added_count: int
    total_questions: int
    total_score: float
    questions: List[ExamQuestionItemResponse]




class ExamListItemResponse(BaseModel):
    id: int
    course_id: int
    title: str
    description: Optional[str]
    exam_type: str
    duration_minutes: Optional[int]
    max_attempts: int
    passing_score: Optional[float]
    total_questions: int
    total_score: float
    is_published: bool
    is_auto_generated: bool
    shuffle_questions: bool
    shuffle_options: bool
    available_from: Optional[datetime]
    available_to: Optional[datetime]
    created_by: int
    created_at: datetime
    updated_at: datetime


class ExamListResponse(BaseModel):
    course_id: int
    total: int
    exams: List[ExamListItemResponse]


class ExamQuestionDetailResponse(BaseModel):
    exam_question_id: int
    question_id: int
    section_id: Optional[int]
    order_index: int
    points: float
    custom_points: Optional[float]
    custom_instructions: Optional[str]

    topic_id: int
    question_text: str
    explanation: Optional[str]
    options: Optional[Any]
    type: str
    difficulty: str
    source: str
    approval_status: str
    expected_answer: Optional[Any]
    grading_rubric: Optional[Any]
    max_score: float
    auto_gradable: bool
    tags: Optional[Any]


class ExamDetailsResponse(BaseModel):
    id: int
    course_id: int
    title: str
    description: Optional[str]
    instructions: Optional[str]
    exam_type: str
    duration_minutes: Optional[int]
    max_attempts: int
    passing_score: Optional[float]
    total_questions: int
    total_score: float
    is_published: bool
    is_auto_generated: bool
    shuffle_questions: bool
    shuffle_options: bool
    available_from: Optional[datetime]
    available_to: Optional[datetime]
    enable_proctoring: bool
    prevent_copy_paste: bool
    prevent_tab_switch: bool
    require_webcam: bool
    require_microphone: bool
    access_code: Optional[str]
    ip_restrictions: Optional[Any]
    created_by: int
    created_at: datetime
    updated_at: datetime
    questions: List[ExamQuestionDetailResponse]