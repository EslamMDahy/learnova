from __future__ import annotations

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from typing import Optional

from app.db.session import get_db
from app.core.deps import get_current_user

from . import service
from .schemas import (ExamCreateRequest,
                      ExamUpdateRequest,
                      ExamResponse,
                      ExamSectionCreateRequest,
                      ExamSectionUpdateRequest,
                      ExamSectionResponse,
                      ExamSectionReorderRequest,
                      ExamSectionReorderResponse,
                      ExamSectionDeleteResponse,
                      ExamAddQuestionsRequest,
                      ExamAddQuestionsResponse,
                      ExamRemoveQuestionResponse,
                      ExamListResponse,
                      ExamDetailsResponse,
                      ExamPublishResponse,
                      ExamQuestionReorderRequest,
                      ExamQuestionReorderResponse,
                      ExamTemplateCreateRequest,
                      ExamTemplateUpdateRequest,
                      ExamTemplateListResponse,
                      ExamTemplateDetailsResponse,
                      ExamTemplateDeleteResponse,
                      ExamTemplateSectionCreateRequest,
                      ExamTemplateSectionUpdateRequest,
                      ExamTemplateSectionResponse,
                      ExamTemplateSectionDeleteResponse,
                      GenerateExamFromTemplateRequest,
                      GenerateExamFromTemplateResponse)


router = APIRouter(prefix="/courses/{course_id}/exams", tags=["Exams"],)


@router.post("", response_model=ExamResponse, status_code=status.HTTP_201_CREATED,)
def create_exam_endpoint(
    course_id: int,
    payload: ExamCreateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.create_exam(
        course_id=course_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.patch("/{exam_id}", response_model=ExamResponse,)
def update_exam_endpoint(
    course_id: int,
    exam_id: int,
    payload: ExamUpdateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.update_exam(
        course_id=course_id,
        exam_id=exam_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.post("/{exam_id}/sections", response_model=ExamSectionResponse, status_code=status.HTTP_201_CREATED,)
def add_section_to_exam_endpoint(
    course_id: int,
    exam_id: int,
    payload: ExamSectionCreateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.add_section_to_exam(
        course_id=course_id,
        exam_id=exam_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.patch("/{exam_id}/sections/reorder", response_model=ExamSectionReorderResponse,)
def reorder_exam_sections_endpoint(
    course_id: int,
    exam_id: int,
    payload: ExamSectionReorderRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.reorder_exam_sections(
        course_id=course_id,
        exam_id=exam_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.patch("/{exam_id}/sections/{section_id}", response_model=ExamSectionResponse,)
def update_exam_section_endpoint(
    course_id: int,
    exam_id: int,
    section_id: int,
    payload: ExamSectionUpdateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.update_exam_section(
        course_id=course_id,
        exam_id=exam_id,
        section_id=section_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.delete("/{exam_id}/sections/{section_id}", response_model=ExamSectionDeleteResponse,)
def delete_exam_section_endpoint(
    course_id: int,
    exam_id: int,
    section_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.delete_exam_section(
        course_id=course_id,
        exam_id=exam_id,
        section_id=section_id,
        db=db,
        current_user=current_user,)

@router.post("/{exam_id}/sections/{section_id}/questions",  response_model=ExamAddQuestionsResponse, status_code=status.HTTP_201_CREATED,)
def add_questions_to_exam_endpoint(
    course_id: int,
    exam_id: int,
    section_id: int,
    payload: ExamAddQuestionsRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.add_questions_to_exam_section(
        course_id=course_id,
        exam_id=exam_id,
        section_id=section_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.patch("/{exam_id}/sections/{section_id}/questions/reorder", response_model=ExamQuestionReorderResponse,)
def reorder_exam_questions_endpoint(
    course_id: int,
    exam_id: int,
    section_id: int,
    payload: ExamQuestionReorderRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.reorder_exam_questions(
        course_id=course_id,
        exam_id=exam_id,
        section_id=section_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.delete("/{exam_id}/sections/{section_id}/questions/{exam_question_id}", response_model=ExamRemoveQuestionResponse, status_code=status.HTTP_200_OK)
def remove_question_from_exam_endpoint(
    course_id: int,
    exam_id: int,
    section_id: int,
    exam_question_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.remove_question_from_exam(
        course_id=course_id,
        exam_id=exam_id,
        section_id=section_id,
        exam_question_id=exam_question_id,
        db=db,
        current_user=current_user,)

@router.post("/{exam_id}/publish", response_model=ExamPublishResponse,)
def publish_exam_endpoint(
    course_id: int,
    exam_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.publish_exam(
        course_id=course_id,
        exam_id=exam_id,
        db=db,
        current_user=current_user,)

@router.get("", response_model=ExamListResponse,)
def list_exams_endpoint(
    course_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.list_exams(
        course_id=course_id,
        db=db,
        current_user=current_user,)

@router.get("/templates", response_model=ExamTemplateListResponse,)
def list_exam_templates_endpoint(
    course_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.list_exam_templates(
        course_id=course_id,
        db=db,
        current_user=current_user,)

@router.get("/templates/{template_id}", response_model=ExamTemplateDetailsResponse,)
def get_exam_template_endpoint(
    course_id: int,
    template_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.get_exam_template(
        course_id=course_id,
        template_id=template_id,
        db=db,
        current_user=current_user,)

@router.post("/templates", response_model=ExamTemplateDetailsResponse, status_code=status.HTTP_201_CREATED,)
def create_exam_template_endpoint(
    course_id: int,
    payload: ExamTemplateCreateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.create_exam_template(
        course_id=course_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.patch("/templates/{template_id}", response_model=ExamTemplateDetailsResponse,)
def update_exam_template_endpoint(
    course_id: int,
    template_id: int,
    payload: ExamTemplateUpdateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.update_exam_template(
        course_id=course_id,
        template_id=template_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.delete("/templates/{template_id}", response_model=ExamTemplateDeleteResponse,)
def delete_exam_template_endpoint(
    course_id: int,
    template_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.delete_exam_template(
        course_id=course_id,
        template_id=template_id,
        db=db,
        current_user=current_user,)

@router.post("/templates/{template_id}/sections", response_model=ExamTemplateSectionResponse, status_code=status.HTTP_201_CREATED,)
def create_exam_template_section_endpoint(
    course_id: int,
    template_id: int,
    payload: ExamTemplateSectionCreateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.create_exam_template_section(
        course_id=course_id,
        template_id=template_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.patch("/templates/{template_id}/sections/{section_id}", response_model=ExamTemplateSectionResponse,)
def update_exam_template_section_endpoint(
    course_id: int,
    template_id: int,
    section_id: int,
    payload: ExamTemplateSectionUpdateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.update_exam_template_section(
        course_id=course_id,
        template_id=template_id,
        section_id=section_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.delete("/templates/{template_id}/sections/{section_id}", response_model=ExamTemplateSectionDeleteResponse,)
def delete_exam_template_section_endpoint(
    course_id: int,
    template_id: int,
    section_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.delete_exam_template_section(
        course_id=course_id,
        template_id=template_id,
        section_id=section_id,
        db=db,
        current_user=current_user,)

@router.post("/templates/{template_id}/generate-exam", response_model=GenerateExamFromTemplateResponse, status_code=status.HTTP_201_CREATED)
def generate_exam_from_template_endpoint(
    course_id: int,
    template_id: int,
    payload: GenerateExamFromTemplateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.generate_exam_from_template(
        course_id=course_id,
        template_id=template_id,
        payload=payload,
        db=db,
        current_user=current_user,)

@router.get("/{exam_id}", response_model=ExamDetailsResponse,)
def get_exam_endpoint(
    course_id: int,
    exam_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.get_exam(
        course_id=course_id,
        exam_id=exam_id,
        db=db,
        current_user=current_user,)

@router.get("/{exam_id}/export/pdf",)
def export_exam_pdf_endpoint(
    course_id: int,
    exam_id: int,
    include_learnova_logo: bool = True,
    include_course_title: bool = True,
    include_course_code: bool = False,
    include_exam_metadata: bool = True,
    include_instructions: bool = True,
    include_section_descriptions: bool = True,
    include_points: bool = True,
    include_student_info_fields: bool = True,
    include_answer_space: bool = True,
    shuffle_questions: Optional[bool] = None,
    shuffle_options: Optional[bool] = None,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),):
    return service.export_exam_pdf(
        course_id=course_id,
        exam_id=exam_id,
        include_learnova_logo=include_learnova_logo,
        include_course_title=include_course_title,
        include_course_code=include_course_code,
        include_exam_metadata=include_exam_metadata,
        include_instructions=include_instructions,
        include_section_descriptions=include_section_descriptions,
        include_points=include_points,
        include_student_info_fields=include_student_info_fields,
        include_answer_space=include_answer_space,
        shuffle_questions=shuffle_questions,
        shuffle_options=shuffle_options,
        db=db,
        current_user=current_user,)

