from __future__ import annotations

from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict


class TopicCreateRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=255, description="Topic title")
    description: Optional[str] = Field(default=None, description="Optional topic description")
    parent_topic_id: Optional[int] = Field(
        default=None,
        gt=0,
        description="Optional parent topic ID. If provided, the new topic becomes a subtopic."
    )
    learning_outcome_ids: Optional[List[int]] = Field(
        default=None,
        description="Optional list of existing learning outcome IDs to attach to this topic"
    )

    model_config = ConfigDict(extra="forbid")

class TopicCreateResponse(BaseModel):
    id: int
    material_id: int
    title: str
    description: Optional[str] = None
    order_index: int
    parent_topic_id: Optional[int] = None

    is_ai_generated: bool
    is_reviewed: bool

    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(extra="forbid")


class TopicListItem(BaseModel):
    id: int
    material_id: int
    title: str
    description: Optional[str] = None
    order_index: int
    parent_topic_id: Optional[int] = None

    is_ai_generated: bool
    is_reviewed: bool

    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(extra="forbid")

class TopicListResponse(BaseModel):
    course_id: int
    module_id: int
    material_id: int
    topics: List[TopicListItem]

    model_config = ConfigDict(extra="forbid")


class TopicRelatedLearningOutcomeItem(BaseModel):
    id: int
    title: str

    model_config = ConfigDict(extra="forbid")

class TopicGetResponse(BaseModel):
    id: int
    material_id: int
    title: str
    description: Optional[str] = None
    order_index: int
    parent_topic_id: Optional[int] = None

    is_ai_generated: bool
    is_reviewed: bool

    created_at: datetime
    updated_at: datetime

    learning_outcomes: List[TopicRelatedLearningOutcomeItem]

    model_config = ConfigDict(extra="forbid")


class TopicUpdateRequest(BaseModel):
    title: Optional[str] = Field(
        default=None,
        min_length=1,
        max_length=255,
        description="Updated topic title"
    )
    description: Optional[str] = Field(
        default=None,
        description="Updated topic description"
    )
    parent_topic_id: Optional[int] = Field(
        default=None,
        gt=0,
        description="Optional parent topic ID. If provided, topic becomes a subtopic under it."
    )
    learning_outcome_ids: Optional[List[int]] = Field(
        default=None,
        description="Optional full replacement list of linked learning outcome IDs"
    )

    model_config = ConfigDict(extra="forbid")

class TopicUpdateResponse(BaseModel):
    id: int
    material_id: int
    title: str
    description: Optional[str] = None
    order_index: int
    parent_topic_id: Optional[int] = None

    is_ai_generated: bool
    is_reviewed: bool

    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(extra="forbid")


class TopicReorderRequest(BaseModel):
    topic_ids: List[int] = Field(
        ...,
        min_length=1,
        description="Final ordered list of all topics IDs in the course"
    )

    model_config = ConfigDict(extra="forbid")

class TopicReorderResponse(BaseModel):
    course_id: int
    module_id: int
    material_id: int
    topic_ids: List[int]

    model_config = ConfigDict(extra="forbid")


