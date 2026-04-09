from __future__ import annotations

from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict


class MaterialInitUploadRequest(BaseModel):
    filename: str = Field(..., min_length=1, max_length=255, description="Original filename")
    content_type: str = Field(..., min_length=1, max_length=100, description="Must be application/pdf")
    file_size_bytes: int = Field(..., gt=0, le=50 * 1024 * 1024, description="Max 50MB")

    # Optional metadata (MVP-friendly)
    title: Optional[str] = Field(default=None, max_length=255)
    description: Optional[str] = Field(default=None)

    model_config = ConfigDict(extra="forbid")

class MaterialInitUploadResponse(BaseModel):
    material_id: int
    module_id: int
    course_id: int

    upload_url: str
    storage_key: str
    bucket: str

    content_type: str
    max_bytes: int
    expires_in_seconds: Optional[int] = None  # Supabase may not expose it cleanly

    status: str  # e.g., "draft_upload"
    created_at: Optional[datetime] = None

    model_config = ConfigDict(extra="forbid")



# class MaterialConfirmUploadRequest(BaseModel):
#     # decide publish here (your preference)
#     # publish_now: bool = Field(default=False)

#     model_config = ConfigDict(extra="forbid")

class MaterialConfirmUploadResponse(BaseModel):
    material_id: int
    module_id: int
    course_id: int

    status: str
    updated_at: datetime

    download_url: Optional[str] = None
    download_url_expires_in: Optional[int] = Field(default=None, description="Seconds")

    model_config = ConfigDict(extra="forbid")


class MaterialListItem(BaseModel):
    id: int
    module_id: int

    title: Optional[str] = None
    description: Optional[str] = None

    type: str  # material_type_enum as string
    status: str  # material_status_enum as string

    file_name: Optional[str] = None
    file_size: Optional[int] = None
    mime_type: Optional[str] = None

    page_count: Optional[int] = None
    duration_seconds: Optional[int] = None

    uploaded_at: datetime
    created_at: datetime
    updated_at: datetime

    # Signed URL for private bucket (optional)
    download_url: Optional[str] = Field(default=None, description="Signed download URL (private bucket)")

    model_config = ConfigDict(extra="forbid")

class MaterialListResponse(BaseModel):
    course_id: int
    module_id: int
    materials: List[MaterialListItem]

    model_config = ConfigDict(extra="forbid")


class MaterialDownloadUrlResponse(BaseModel):
    course_id: int
    module_id: int
    material_id: int

    download_url: str = Field(..., description="Signed download URL (private bucket)")
    expires_in_seconds: int = Field(..., gt=0, description="Signed URL validity period in seconds")

    model_config = ConfigDict(extra="forbid")


class MaterialReassignRequest(BaseModel):
    target_module_id: int = Field(
        ...,
        description="The target module ID to move the material into"
    )

    model_config = ConfigDict(extra="forbid")

class MaterialReassignResponse(BaseModel):
    id: int
    module_id: int
    storage_key: str

    model_config = ConfigDict(extra="forbid")