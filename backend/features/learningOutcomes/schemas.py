from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field


class LearningOutcomeCreateRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=255, description="Learning outcome title")
    description: Optional[str] = Field(default=None, description="Optional learning outcome description")
    level: str = Field(..., description="Learning outcome level enum value")
    topic_ids: Optional[List[int]] = Field(
        default=None,
        description="Optional list of existing topic IDs to attach to this learning outcome"
    )

    model_config = ConfigDict(extra="forbid")

class LearningOutcomeCreateResponse(BaseModel):
    id: int
    course_id: int
    title: str
    description: Optional[str] = None
    level: str
    # ai_ref_key: Optional[str] = None

    is_ai_generated: bool
    is_reviewed: bool

    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(extra="forbid")


class LearningOutcomeListItem(BaseModel):
    id: int
    course_id: int
    title: str
    description: Optional[str] = None
    level: str

    is_ai_generated: bool
    is_reviewed: bool

    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(extra="forbid")

class LearningOutcomeListResponse(BaseModel):
    course_id: int
    learning_outcomes: List[LearningOutcomeListItem]

    model_config = ConfigDict(extra="forbid")


class LearningOutcomeRelatedTopicItem(BaseModel):
    id: int
    title: str

    model_config = ConfigDict(extra="forbid")

class LearningOutcomeGetResponse(BaseModel):
    id: int
    course_id: int
    title: str
    description: Optional[str] = None
    level: str
    # ai_ref_key: Optional[str] = None

    is_ai_generated: bool
    is_reviewed: bool

    created_at: datetime
    updated_at: datetime

    topics: List[LearningOutcomeRelatedTopicItem]

    model_config = ConfigDict(extra="forbid")


class LearningOutcomeUpdateRequest(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=255, description="Updated title")
    description: Optional[str] = Field(default=None, description="Updated description")
    level: Optional[str] = Field(default=None, description="Updated learning outcome level enum value")
    topic_ids: Optional[List[int]] = Field(
        default=None,
        description="Optional full replacement list of linked topic IDs"
    )

    model_config = ConfigDict(extra="forbid")


class LearningOutcomeUpdateResponse(BaseModel):
    id: int
    course_id: int
    title: str
    description: Optional[str] = None
    level: str
    # ai_ref_key: Optional[str] = None

    is_ai_generated: bool
    is_reviewed: bool

    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(extra="forbid")