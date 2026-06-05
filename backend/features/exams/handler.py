from __future__ import annotations

import html
from typing import Any


def render_question_handler(*, question: dict, context: dict):
    # =========================
    # 1) Dispatch by question type
    # =========================
    question_type = str(question.get("type") or "").strip().lower()

    if question_type in ("multiple_choice", "multi_select"):
        if question_type == "multi_select" or _is_multi_answer_question(question):
            return render_multi_choice_question(
                question=question,
                context=context,
            )

        return render_single_choice_question(
            question=question,
            context=context,
        )

    if question_type == "true_false":
        return render_true_false_question(
            question=question,
            context=context,
        )

    if question_type == "short_answer":
        return render_short_answer_question(
            question=question,
            context=context,
        )

    if question_type == "essay":
        return render_essay_question(
            question=question,
            context=context,
        )

    return render_unknown_question(
        question=question,
        context=context,
    )


def render_single_choice_question(*, question: dict, context: dict):
    # =========================
    # 1) Render single-choice question
    # =========================
    return _render_choice_question(
        question=question,
        context=context,
    )


def render_multi_choice_question(*, question: dict, context: dict):
    # =========================
    # 1) Render multi-choice question
    # =========================
    return _render_choice_question(
        question=question,
        context=context,
    )


def render_true_false_question(*, question: dict, context: dict):
    # =========================
    # 1) Render true/false question
    # =========================
    question_header_html = _render_question_header(
        question=question,
        context=context,
        suffix_html="<span class='true-false-box'>( &nbsp;&nbsp;&nbsp; )</span>",
    )

    return f"""
    <div class="question-block">
        {question_header_html}
    </div>
    """


def render_short_answer_question(*, question: dict, context: dict):
    # =========================
    # 1) Render short-answer question
    # =========================
    return _render_written_question(
        question=question,
        context=context,
        line_count=3,
    )


def render_essay_question(*, question: dict, context: dict):
    # =========================
    # 1) Render essay question
    # =========================
    return _render_written_question(
        question=question,
        context=context,
        line_count=8,
    )


def render_unknown_question(*, question: dict, context: dict):
    # =========================
    # 1) Render unsupported question safely
    # =========================
    question_type = html.escape(str(question.get("type") or "unknown"))
    question_header_html = _render_question_header(
        question=question,
        context=context,
    )

    return f"""
    <div class="question-block">
        {question_header_html}
        <div class="option">Unsupported question type: {question_type}</div>
    </div>
    """


def _render_choice_question(*, question: dict, context: dict):
    # =========================
    # 1) Render question header
    # =========================
    question_header_html = _render_question_header(
        question=question,
        context=context,
    )

    # =========================
    # 2) Render options
    # =========================
    options_html = _render_options(
        options=question.get("options"),
    )

    return f"""
    <div class="question-block">
        {question_header_html}
        <div class="options-list">
            {options_html}
        </div>
    </div>
    """


def _render_written_question(*, question: dict, context: dict, line_count: int):
    # =========================
    # 1) Extract display settings
    # =========================
    display = context.get("display", {})
    include_answer_space = bool(display.get("include_answer_space"))

    # =========================
    # 2) Render question header
    # =========================
    question_header_html = _render_question_header(
        question=question,
        context=context,
    )

    # =========================
    # 3) Render answer lines
    # =========================
    answer_lines_html = ""
    if include_answer_space:
        answer_lines_html = _render_answer_lines(line_count=line_count)

    return f"""
    <div class="question-block">
        {question_header_html}
        {answer_lines_html}
    </div>
    """


def _render_question_header(*, question: dict, context: dict, suffix_html: str = ""):
    # =========================
    # 1) Extract display settings
    # =========================
    display = context.get("display", {})
    include_points = bool(display.get("include_points"))

    # =========================
    # 2) Render question header
    # =========================
    question_number = html.escape(str(question.get("question_number") or ""))
    question_text = html.escape(str(question.get("question_text") or ""))
    points_html = _render_points(question=question) if include_points else ""

    side_items = "".join(
        item for item in [suffix_html, points_html]
        if item
    )

    return f"""
    <div class="question-title">
        <span class="question-main">{question_number}) {question_text}</span>
        <span class="question-side">{side_items}</span>
    </div>
    """


def _render_options(*, options: Any):
    # =========================
    # 1) Validate options shape
    # =========================
    if not isinstance(options, list) or not options:
        return "<div class='option'>No options provided</div>"

    # =========================
    # 2) Render options
    # =========================
    rendered_options = []

    for index, option in enumerate(options):
        option_text = _extract_option_text(option=option)
        option_label = _render_option_label(index=index)

        rendered_options.append(
            f"""
            <div class="option">
                <span class="option-label">{option_label}.</span>
                <span class="option-text">{html.escape(option_text)}</span>
            </div>
            """
        )

    return "\n".join(rendered_options)


def _render_answer_lines(*, line_count: int):
    # =========================
    # 1) Render printed answer lines
    # =========================
    lines = "\n".join(
        "<div class='answer-line'></div>"
        for _ in range(line_count)
    )

    return f"""
    <div class="answer-lines">
        {lines}
    </div>
    """


def _render_option_label(*, index: int):
    # =========================
    # 1) Render option label
    # =========================
    if 0 <= index < 26:
        return chr(ord("A") + index)

    return str(index + 1)


def _extract_option_text(*, option: Any):
    # =========================
    # 1) Extract option text safely
    # =========================
    if isinstance(option, dict):
        return str(
            option.get("text")
            or option.get("label")
            or option.get("value")
            or ""
        )

    return str(option or "")


def _render_points(*, question: dict):
    # =========================
    # 1) Render question points
    # =========================
    points = question.get("points")

    if points is None:
        points = question.get("max_score")

    formatted_points = _format_points(points=points)
    label = "mark" if formatted_points == "1" else "marks"

    return f"<span class='points'>({formatted_points} {label})</span>"


def _format_points(*, points: Any):
    # =========================
    # 1) Format points for exam paper display
    # =========================
    if points is None:
        return "0"

    try:
        numeric_points = float(points)
    except (TypeError, ValueError):
        return html.escape(str(points))

    if numeric_points.is_integer():
        return str(int(numeric_points))

    return str(numeric_points)


def _is_multi_answer_question(question: dict):
    # =========================
    # 1) Detect multi-answer multiple choice
    # =========================
    expected_answer = question.get("expected_answer")

    if isinstance(expected_answer, list):
        return True

    if isinstance(expected_answer, dict):
        answers = (
            expected_answer.get("answers")
            or expected_answer.get("correct_answers")
            or expected_answer.get("correct_option_ids")
        )
        return isinstance(answers, list) and len(answers) > 1

    return False