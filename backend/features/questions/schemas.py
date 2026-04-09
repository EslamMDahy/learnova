from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field


class QuestionOptionItem(BaseModel):
    id: str = Field(..., min_length=1, max_length=20)
    text: str = Field(..., min_length=1)

    model_config = ConfigDict(extra="forbid")

class QuestionCreateRequest(BaseModel):
    topic_id: int = Field(..., gt=0)
    question_text: str = Field(..., min_length=1)
    type: str = Field(..., min_length=1)
    difficulty: str = Field(..., min_length=1)

    explanation: Optional[str] = None
    options: Optional[List[QuestionOptionItem]] = None
    expected_answer: Optional[List[str] | str] = None
    grading_rubric: Optional[dict] = None

    model_config = ConfigDict(extra="forbid")

class QuestionCreateResponse(BaseModel):
    id: int
    course_id: int
    topic_id: int
    question_text: str
    explanation: Optional[str] = None
    options: Optional[list] = None
    type: str
    difficulty: str
    source: str
    approval_status: str
    expected_answer: Optional[List[str] | str] = None
    grading_rubric: Optional[dict] = None
    max_score: int
    auto_gradable: bool
    usage_count: int
    success_rate: Optional[float] = None
    average_time_seconds: Optional[float] = None
    tags: Optional[list] = None
    created_by: Optional[int] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(extra="forbid")


class QuestionListItem(BaseModel):
    id: int
    course_id: int
    topic_id: int
    question_text: str
    options: Optional[list] = None
    type: str
    difficulty: str
    source: str
    approval_status: str
    auto_gradable: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(extra="forbid")

class TopicQuestionListResponse(BaseModel):
    course_id: int
    topic_id: int
    questions: List[QuestionListItem]

    model_config = ConfigDict(extra="forbid")

class MaterialQuestionListResponse(BaseModel):
    course_id: int
    module_id: int
    material_id: int
    questions: List[QuestionListItem]

    model_config = ConfigDict(extra="forbid")

class ModuleQuestionListResponse(BaseModel):
    course_id: int
    module_id: int
    questions: List[QuestionListItem]

    model_config = ConfigDict(extra="forbid")

class CourseQuestionListResponse(BaseModel):
    course_id: int
    questions: List[QuestionListItem]

    model_config = ConfigDict(extra="forbid")


