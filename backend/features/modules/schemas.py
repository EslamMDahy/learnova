from __future__ import annotations

from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict

class ModuleCreateRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=255, description="Module title")
    description: Optional[str] = Field(default=None, description="Optional module description")

    # Optional: you can keep this for later; if you don't want it now, remove it.
    is_published: Optional[bool] = Field(
        default=None,
        description="Optional. If omitted, server sets default (recommended: False).",
    )

    model_config = ConfigDict(extra="forbid")

class ModuleCreateResponse(BaseModel):
    id: int
    course_id: int
    title: str
    description: Optional[str] = None
    order_index: int
    is_published: bool

    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(extra="forbid")


class ModuleUpdateRequest(BaseModel):
    title: Optional[str] = Field(
        default=None,
        min_length=1,
        max_length=255,
        description="Updated module title"
    )
    description: Optional[str] = Field(
        default=None,
        description="Updated module description"
    )
    is_published: Optional[bool] = Field(
        default=None,
        description="Updated module publish state"
    )

    model_config = ConfigDict(extra="forbid")

class ModuleUpdateResponse(BaseModel):
    id: int
    course_id: int
    title: str
    description: Optional[str] = None
    order_index: int

    is_published: bool
    published_at: Optional[datetime] = None

    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(extra="forbid")


class ModuleCopyResponse(BaseModel):
    id: int
    course_id: int

    title: str
    description: Optional[str] = None
    order_index: int

    is_published: bool
    published_at: Optional[datetime] = None

    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(extra="forbid")


class ModuleReorderRequest(BaseModel):
    module_ids: List[int] = Field(
        ...,
        min_length=1,
        description="Final ordered list of all module IDs in the course"
    )

    model_config = ConfigDict(extra="forbid")

class ModuleReorderResponse(BaseModel):
    course_id: int
    module_ids: List[int]

    model_config = ConfigDict(extra="forbid")


class ModuleListItem(BaseModel):
    id: int
    course_id: int
    title: str
    description: Optional[str] = None
    order_index: int

    is_published: bool
    published_at: Optional[datetime] = None

    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(extra="forbid")

class ModuleListResponse(BaseModel):
    course_id: int
    modules: List[ModuleListItem]

    model_config = ConfigDict(extra="forbid")