from __future__ import annotations

import html
import random
from typing import Any

from weasyprint import HTML

from app.core.config import settings
from .handler import render_question_handler


def build_exam_export_context(*, exam_row: dict, course_row: dict, section_rows: list[dict], question_rows: list[dict],
                              include_learnova_logo: bool, include_course_title: bool, include_course_code: bool, include_exam_metadata: bool,
                              include_instructions: bool, include_section_descriptions: bool, include_points: bool, include_student_info_fields: bool,
                              include_answer_space: bool, effective_shuffle_questions: bool, effective_shuffle_options: bool,) -> dict:
    # =========================
    # 1) Prepare sections
    # =========================
    sections = []
    section_map = {}

    for section in section_rows:
        section_id = int(section["section_id"])

        section_data = {
            "id": section_id,
            "title": section.get("title"),
            "description": section.get("description"),
            "question_type": section.get("question_type"),
            "question_type_label": _format_question_type_label(
                question_type=section.get("question_type"),
            ),
            "order_index": section.get("order_index"),
            "total_questions": 0,
            "total_score": 0,
            "questions": [],
        }

        sections.append(section_data)
        section_map[section_id] = section_data

    # =========================
    # 2) Attach questions to sections
    # =========================
    for row in question_rows:
        question = dict(row)
        section_id = question.get("section_id")

        if section_id is None:
            continue

        section = section_map.get(int(section_id))
        if not section:
            continue

        section["questions"].append(question)

    # =========================
    # 3) Normalize questions inside each section
    # =========================
    flat_questions = []

    for section in sections:
        questions = list(section["questions"])

        if effective_shuffle_questions:
            random.shuffle(questions)

        normalized_questions = []

        for index, question in enumerate(questions, start=1):
            options = question.get("options")

            if effective_shuffle_options and isinstance(options, list):
                options = list(options)
                random.shuffle(options)

            normalized_question = {
                **question,
                "question_number": index,
                "options": options,
            }

            normalized_questions.append(normalized_question)
            flat_questions.append(normalized_question)

        section["questions"] = normalized_questions
        section["total_questions"] = len(normalized_questions)
        section["total_score"] = sum(
            float(question.get("points") or question.get("max_score") or 0)
            for question in normalized_questions
        )

    # =========================
    # 4) Build export context
    # =========================
    return {
        "exam": {
            "id": exam_row.get("id"),
            "title": exam_row.get("title"),
            "description": exam_row.get("description"),
            "instructions": exam_row.get("instructions"),
            "exam_type": exam_row.get("exam_type"),
            "duration_minutes": exam_row.get("duration_minutes"),
            "total_questions": len(flat_questions),
            "total_score": exam_row.get("total_score"),
        },
        "course": {
            "title": course_row.get("title"),
            "course_code": course_row.get("course_code"),
        },
        "display": {
            "include_learnova_logo": include_learnova_logo,
            "include_course_title": include_course_title,
            "include_course_code": include_course_code,
            "include_exam_metadata": include_exam_metadata,
            "include_instructions": include_instructions,
            "include_section_descriptions": include_section_descriptions,
            "include_points": include_points,
            "include_student_info_fields": include_student_info_fields,
            "include_answer_space": include_answer_space,
            "shuffle_questions": effective_shuffle_questions,
            "shuffle_options": effective_shuffle_options,
        },
        "sections": sections,
        "questions": flat_questions,
    }



def render_exam_pdf_html(context: dict):
    # =========================
    # 1) Extract context
    # =========================
    exam = context["exam"]
    course = context.get("course") or {}
    display = context["display"]
    sections = context.get("sections") or []
    questions = context.get("questions") or []

    title = html.escape(str(exam.get("title") or "Exam"))
    exam_type = html.escape(str(exam.get("exam_type") or "exam"))

    course_title = html.escape(str(course.get("title") or ""))
    course_code = html.escape(str(course.get("course_code") or ""))

    duration_minutes = exam.get("duration_minutes")
    time_allowed = (
        f"{html.escape(str(duration_minutes))} minutes"
        if duration_minutes
        else "Not limited"
    )

    total_questions = html.escape(str(exam.get("total_questions") or 0))
    total_marks = html.escape(str(exam.get("total_score") or 0))

    # =========================
    # 2) Render header parts
    # =========================
    logo_html = ""
    if display.get("include_learnova_logo"):
        logo_html = f"""
        <div class="brand-logo">
            <img src="{html.escape(str(settings.email_logo_url or ''))}" alt="Learnova">
        </div>
        """

    course_title_html = ""
    if display.get("include_course_title") and course_title:
        course_title_html = f"""
        <div class="info-line">
            <span class="label">Course:</span>
            <span>{course_title}</span>
        </div>
        """

    course_code_html = ""
    if display.get("include_course_code") and course_code:
        course_code_html = f"""
        <div class="info-line">
            <span class="label">Course Code:</span>
            <span>{course_code}</span>
        </div>
        """

    metadata_html = ""
    if display.get("include_exam_metadata"):
        metadata_html = f"""
        <div class="stats-column">
            <div class="info-line">
                <span class="label">Time Allowed:</span>
                <span>{time_allowed}</span>
            </div>
            <div class="info-line">
                <span class="label">No. of Questions:</span>
                <span>{total_questions}</span>
            </div>
            <div class="info-line">
                <span class="label">Total Marks:</span>
                <span>{total_marks}</span>
            </div>
        </div>
        """

    student_info_html = ""
    if display.get("include_student_info_fields"):
        student_info_html = """
        <div class="student-fields">
            <div class="student-line">
                <span class="label">Student Name:</span>
                <span class="blank-line"></span>
            </div>
            <div class="student-line">
                <span class="label">Student ID:</span>
                <span class="blank-line"></span>
            </div>
            <div class="student-line">
                <span class="label">Date:</span>
                <span class="blank-line"></span>
            </div>
        </div>
        """

    instructions_html = ""
    if display.get("include_instructions") and exam.get("instructions"):
        instructions_html = f"""
        <section class="instructions">
            <div class="section-title">Instructions</div>
            <div class="instructions-text">{html.escape(str(exam.get("instructions") or ""))}</div>
        </section>
        <div class="thin-separator"></div>
        """

    # =========================
    # 3) Render questions / sections
    # =========================
    questions_html = ""

    if sections:
        rendered_sections = []

        question_type_labels = {
            "multiple_choice": "Multiple Choice",
            "multi_select": "Multiple Select",
            "true_false": "True / False",
            "short_answer": "Short Answer",
            "essay": "Essay",
        }

        for section in sections:
            section_title = html.escape(str(section.get("title") or "Question"))
            raw_question_type = str(section.get("question_type") or "").strip().lower()
            question_type_label = html.escape(
                str(
                    section.get("question_type_label")
                    or question_type_labels.get(
                        raw_question_type,
                        raw_question_type.replace("_", " ").title() or "Questions",
                    )
                )
            )

            section_score = section.get("total_score")

            if section_score is None:
                formatted_section_score = "0"
            else:
                try:
                    numeric_section_score = float(section_score)
                    if numeric_section_score.is_integer():
                        formatted_section_score = str(int(numeric_section_score))
                    else:
                        formatted_section_score = str(numeric_section_score)
                except (TypeError, ValueError):
                    formatted_section_score = html.escape(str(section_score))

            section_score_label = (
                "mark"
                if formatted_section_score == "1"
                else "marks"
            )

            section_description_html = ""
            if display.get("include_section_descriptions") and section.get("description"):
                section_description_text = html.escape(str(section.get("description") or ""))
                section_description_html = f'<div class="exam-section-description">{section_description_text}</div>'

            section_questions = section.get("questions") or []

            section_questions_html = "\n".join(
                f"""
                <section class="question-wrapper">
                    {render_question_handler(question=question, context=context)}
                </section>
                """
                for question in section_questions
            )

            rendered_sections.append(
                f"""
                <section class="exam-section">
                    <div class="exam-section-title-row">
                        <span class="exam-section-main">
                            {section_title}: {question_type_label}
                        </span>
                        <span class="exam-section-score">
                            ({formatted_section_score} {section_score_label})
                        </span>
                    </div>

                    {section_description_html}

                    <div class="exam-section-questions">
                        {section_questions_html}
                    </div>
                </section>
                """
            )

        questions_html = "\n".join(rendered_sections)

    else:
        questions_html = "\n".join(
            f"""
            <section class="question-wrapper">
                {render_question_handler(question=question, context=context)}
            </section>
            """
            for question in questions
        )

    # =========================
    # 4) Return full HTML document
    # =========================
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <style>
            @page {{
                size: A4;
                margin: 18mm 14mm 16mm 14mm;

                @bottom-left {{
                    content: "Powered by Learnova";
                    font-family: Arial, sans-serif;
                    font-size: 11px;
                    color: #111111;
                    border-top: 2px solid #111111;
                    padding-top: 5px;
                    width: 100%;
                }}

                @bottom-right {{
                    content: "Page " counter(page) " of " counter(pages);
                    font-family: Arial, sans-serif;
                    font-size: 11px;
                    color: #111111;
                    border-top: 2px solid #111111;
                    padding-top: 5px;
                    width: 35mm;
                    text-align: right;
                    white-space: nowrap;
                }}
            }}

            * {{
                box-sizing: border-box;
            }}

            body {{
                font-family: Arial, sans-serif;
                color: #111111;
                font-size: 11px;
                line-height: 1.35;
                margin: 0;
                padding: 0;
            }}

            .exam-header {{
                width: 100%;
                display: table;
                table-layout: fixed;
                margin-bottom: 8px;
            }}

            .header-cell {{
                display: table-cell;
                vertical-align: top;
                padding-right: 6px;
            }}

            .logo-cell {{
                width: 10%;
            }}

            .course-column {{
                width: 36%;
                padding-left: 0;
            }}

            .stats-cell {{
                width: 27%;
            }}

            .stats-column {{
                width: 100%;
            }}

            .student-column {{
                width: 27%;
                padding-right: 0;
            }}

            .student-fields {{
                width: 100%;
            }}

            .brand-logo img {{
                width: 62px;
                height: 62px;
                object-fit: contain;
                display: block;
            }}

            .info-line {{
                margin-bottom: 3px;
                white-space: normal;
                overflow-wrap: break-word;
                word-break: normal;
            }}

            .label {{
                font-weight: bold;
            }}

            .exam-title {{
                margin-top: 5px;
                font-weight: bold;
                font-size: 12px;
                line-height: 1.25;
                white-space: normal;
                overflow-wrap: break-word;
            }}

            .student-line {{
                display: table;
                width: 100%;
                margin-bottom: 5px;
            }}

            .student-line .label {{
                display: table-cell;
                width: 78px;
                white-space: nowrap;
            }}

            .blank-line {{
                display: table-cell;
                border-bottom: 1px solid #111111;
                height: 12px;
            }}

            .thick-separator {{
                border-top: 2px solid #111111;
                margin: 8px 0 8px;
            }}

            .thin-separator {{
                border-top: 1px solid #777777;
                margin: 8px 0 10px;
            }}

            .instructions {{
                margin: 0 0 8px;
            }}

            .section-title {{
                font-weight: bold;
                margin-bottom: 3px;
            }}

            .instructions-text {{
                white-space: pre-line;
                font-size: 11px;
            }}

            .questions-area {{
                margin-top: 0;
            }}

            .exam-section {{
                margin-top: 12px;
            }}

            .exam-section:first-child {{
                margin-top: 0;
            }}

            .exam-section + .exam-section {{
                margin-top: 16px;
            }}

            .exam-section-title-row {{
                display: table;
                width: 100%;
                font-weight: bold;
                font-size: 13px;
                padding-bottom: 0px;
                margin-bottom: 0px;
            }}

            .exam-section-main {{
                display: table-cell;
                vertical-align: top;
                padding-right: 10px;
            }}

            .exam-section-score {{
                display: table-cell;
                vertical-align: top;
                width: 75px;
                text-align: right;
                white-space: nowrap;
            }}

            .exam-section-description {{
                font-size: 11px;
                font-style: italic;
                margin: 0 0 6px;
                white-space: pre-line;
            }}

            .exam-section-questions {{
                margin-left: 4mm;
                padding-left: 1mm;
            }}

            .question-wrapper {{
                padding: 6px 0 7px;
                border-bottom: 1px solid #777777;
                page-break-inside: avoid;
                break-inside: avoid;
            }}

            .exam-section-questions .question-wrapper:first-child {{
                padding-top: 4px;
            }}

            .question-block {{
                margin-bottom: 0;
                page-break-inside: avoid;
                break-inside: avoid;
            }}

            .question-title {{
                display: table;
                width: 100%;
                font-weight: bold;
                margin-bottom: 7px;
            }}

            .question-main {{
                display: table-cell;
                vertical-align: top;
                padding-right: 10px;
            }}

            .question-side {{
                display: table-cell;
                vertical-align: top;
                width: 78px;
                text-align: right;
                white-space: nowrap;
            }}

            .points {{
                font-weight: bold;
            }}

            .true-false-box {{
                display: inline-block;
                margin-right: 8px;
                font-weight: normal;
            }}

            .options-list {{
                margin-top: 3px;
            }}

            .option {{
                display: table;
                width: 100%;
                margin: 3px 0;
            }}

            .option-label {{
                display: table-cell;
                width: 20px;
                font-weight: bold;
            }}

            .option-text {{
                display: table-cell;
            }}

            .answer-lines {{
                margin-top: 8px;
            }}

            .answer-line {{
                height: 16px;
                border-bottom: 1px dotted #555555;
            }}
        </style>
    </head>
    <body>
        <header class="exam-header">
            <div class="header-cell logo-cell">
                {logo_html}
            </div>

            <div class="header-cell course-column">
                {course_title_html}
                {course_code_html}
                <div class="info-line">
                    <span class="label">Exam Type:</span>
                    <span>{exam_type}</span>
                </div>
                <div class="exam-title">{title}</div>
            </div>

            <div class="header-cell stats-cell">
                {metadata_html}
            </div>

            <div class="header-cell student-column">
                {student_info_html}
            </div>
        </header>

        <div class="thick-separator"></div>

        {instructions_html}

        <main class="questions-area">
            {questions_html}
        </main>
    </body>
    </html>
    """


def convert_html_to_pdf(html_content: str):
    # =========================
    # 1) Convert HTML to PDF bytes
    # =========================
    return HTML(string=html_content).write_pdf()


def _format_question_type_label(*, question_type):
    # =========================
    # 1) Format section question type for exam paper display
    # =========================
    normalized_type = str(question_type or "").strip().lower()

    labels = {
        "multiple_choice": "Multiple Choice",
        "multi_select": "Multiple Select",
        "true_false": "True / False",
        "short_answer": "Short Answer",
        "essay": "Essay",
    }

    return labels.get(normalized_type, normalized_type.replace("_", " ").title())