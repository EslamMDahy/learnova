import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import 'exam_models.dart';


class ExamPdfExport {
  final Uint8List bytes;
  final String filename;

  const ExamPdfExport({
    required this.bytes,
    required this.filename,
  });
}

class ExamsApi {
  final ApiClient _client;

  const ExamsApi(this._client);

  Future<ExamModel> createExam({
    required int courseId,
    required ExamCreatePayload payload,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.courseExams(courseId),
      data: payload.toJson(),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return ExamModel.fromJson(data);
    throw const FormatException('Invalid response from POST /courses/{id}/exams');
  }

  Future<ExamModel> updateExam({
    required int courseId,
    required int examId,
    required Map<String, dynamic> payload,
    CancelToken? cancelToken,
  }) async {
    final body = Map<String, dynamic>.from(payload)..removeWhere((_, value) => value == null);
    final res = await _client.patch<Map<String, dynamic>>(
      Endpoints.updateExam(courseId, examId),
      data: body,
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return ExamModel.fromJson(data);
    throw const FormatException('Invalid response from PATCH /courses/{id}/exams/{examId}');
  }

  Future<ExamSectionModel> createSection({
    required int courseId,
    required int examId,
    required ExamSectionCreatePayload payload,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.examSections(courseId, examId),
      data: payload.toJson(),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return ExamSectionModel.fromJson(data);
    throw const FormatException('Invalid response from POST /courses/{id}/exams/{examId}/sections');
  }

  Future<ExamSectionModel> updateSection({
    required int courseId,
    required int examId,
    required int sectionId,
    required Map<String, dynamic> payload,
    CancelToken? cancelToken,
  }) async {
    final body = Map<String, dynamic>.from(payload)..removeWhere((_, value) => value == null);
    final res = await _client.patch<Map<String, dynamic>>(
      Endpoints.examSection(courseId, examId, sectionId),
      data: body,
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return ExamSectionModel.fromJson(data);
    throw const FormatException('Invalid response from PATCH /courses/{id}/exams/{examId}/sections/{sectionId}');
  }

  Future<Map<String, dynamic>> reorderSectionsRaw({
    required int courseId,
    required int examId,
    required List<int> sectionIds,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.patch<Map<String, dynamic>>(
      Endpoints.reorderExamSections(courseId, examId),
      data: {'section_ids': sectionIds},
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Invalid response from PATCH /courses/{id}/exams/{examId}/sections/reorder');
  }

  Future<Map<String, dynamic>> deleteSectionRaw({
    required int courseId,
    required int examId,
    required int sectionId,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.delete<Map<String, dynamic>>(
      Endpoints.examSection(courseId, examId, sectionId),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Invalid response from DELETE /courses/{id}/exams/{examId}/sections/{sectionId}');
  }

  Future<ExamAddQuestionsResponse> addQuestions({
    required int courseId,
    required int examId,
    required int sectionId,
    required List<int> questionIds,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.examSectionQuestions(courseId, examId, sectionId),
      data: ExamAddQuestionsPayload(questionIds: questionIds).toJson(),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return ExamAddQuestionsResponse.fromJson(data);
    throw const FormatException('Invalid response from POST /courses/{id}/exams/{examId}/sections/{sectionId}/questions');
  }

  Future<Map<String, dynamic>> reorderQuestionsRaw({
    required int courseId,
    required int examId,
    required int sectionId,
    required List<int> examQuestionIds,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.patch<Map<String, dynamic>>(
      Endpoints.reorderExamQuestions(courseId, examId, sectionId),
      data: {'exam_question_ids': examQuestionIds},
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Invalid response from PATCH /courses/{id}/exams/{examId}/sections/{sectionId}/questions/reorder');
  }

  Future<ExamListResponse> listExams({
    required int courseId,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      Endpoints.courseExams(courseId),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return ExamListResponse.fromJson(data);
    throw const FormatException('Invalid response from GET /courses/{id}/exams');
  }

  Future<ExamDetailsModel> getExam({
    required int courseId,
    required int examId,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      Endpoints.exam(courseId, examId),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return ExamDetailsModel.fromJson(data);
    throw const FormatException('Invalid response from GET /courses/{id}/exams/{examId}');
  }

  Future<ExamPublishResponse> publishExam({
    required int courseId,
    required int examId,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.publishExam(courseId, examId),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return ExamPublishResponse.fromJson(data);
    throw const FormatException('Invalid response from POST /courses/{id}/exams/{examId}/publish');
  }


  Future<ExamPdfExport> exportExamPdf({
    required int courseId,
    required int examId,
    bool includeLearnovaLogo = true,
    bool includeCourseTitle = true,
    bool includeCourseCode = false,
    bool includeExamMetadata = true,
    bool includeInstructions = false,
    bool includeSectionDescriptions = true,
    bool includePoints = true,
    bool includeStudentInfoFields = true,
    bool includeAnswerSpace = true,
    bool? shuffleQuestions,
    bool? shuffleOptions,
    CancelToken? cancelToken,
  }) async {
    final queryParameters = <String, dynamic>{
      'include_learnova_logo': includeLearnovaLogo,
      'include_course_title': includeCourseTitle,
      'include_course_code': includeCourseCode,
      'include_exam_metadata': includeExamMetadata,
      'include_instructions': includeInstructions,
      'include_section_descriptions': includeSectionDescriptions,
      'include_points': includePoints,
      'include_student_info_fields': includeStudentInfoFields,
      'include_answer_space': includeAnswerSpace,
      if (shuffleQuestions != null) 'shuffle_questions': shuffleQuestions,
      if (shuffleOptions != null) 'shuffle_options': shuffleOptions,
    };

    final res = await _client.get<dynamic>(
      Endpoints.exportExamPdf(courseId, examId),
      queryParameters: queryParameters,
      options: Options(
        responseType: ResponseType.bytes,
        headers: const {
          'Accept': 'application/pdf',
        },
      ),
      cancelToken: cancelToken,
    );

    final data = res.data;
    final Uint8List bytes;
    if (data is Uint8List) {
      bytes = data;
    } else if (data is List<int>) {
      bytes = Uint8List.fromList(data);
    } else {
      throw const FormatException('Invalid response from GET /courses/{id}/exams/{examId}/export/pdf');
    }

    if (bytes.isEmpty) {
      throw const FormatException('Empty PDF returned from exam export endpoint');
    }

    return ExamPdfExport(
      bytes: bytes,
      filename: _filenameFromContentDisposition(
            res.headers.value('content-disposition'),
          ) ??
          'learnova-exam-$examId.pdf',
    );
  }

  Future<ExamRemoveQuestionResponse> removeQuestion({
    required int courseId,
    required int examId,
    required int sectionId,
    required int examQuestionId,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.delete<Map<String, dynamic>>(
      Endpoints.examSectionQuestion(courseId, examId, sectionId, examQuestionId),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return ExamRemoveQuestionResponse.fromJson(data);
    throw const FormatException('Invalid response from DELETE /courses/{id}/exams/{examId}/sections/{sectionId}/questions/{examQuestionId}');
  }

  Future<Map<String, dynamic>> listExamTemplatesRaw({
    required int courseId,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      Endpoints.examTemplates(courseId),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Invalid response from GET /courses/{id}/exams/templates');
  }

  Future<Map<String, dynamic>> getExamTemplateRaw({
    required int courseId,
    required int templateId,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      Endpoints.examTemplate(courseId, templateId),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Invalid response from GET /courses/{id}/exams/templates/{templateId}');
  }

  Future<Map<String, dynamic>> createExamTemplateRaw({
    required int courseId,
    required Map<String, dynamic> payload,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.examTemplates(courseId),
      data: payload,
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Invalid response from POST /courses/{id}/exams/templates');
  }

  Future<Map<String, dynamic>> updateExamTemplateRaw({
    required int courseId,
    required int templateId,
    required Map<String, dynamic> payload,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.patch<Map<String, dynamic>>(
      Endpoints.examTemplate(courseId, templateId),
      data: payload,
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Invalid response from PATCH /courses/{id}/exams/templates/{templateId}');
  }

  Future<Map<String, dynamic>> deleteExamTemplateRaw({
    required int courseId,
    required int templateId,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.delete<Map<String, dynamic>>(
      Endpoints.examTemplate(courseId, templateId),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Invalid response from DELETE /courses/{id}/exams/templates/{templateId}');
  }

  Future<Map<String, dynamic>> createExamTemplateSectionRaw({
    required int courseId,
    required int templateId,
    required Map<String, dynamic> payload,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.examTemplateSections(courseId, templateId),
      data: payload,
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Invalid response from POST /courses/{id}/exams/templates/{templateId}/sections');
  }

  Future<Map<String, dynamic>> updateExamTemplateSectionRaw({
    required int courseId,
    required int templateId,
    required int sectionId,
    required Map<String, dynamic> payload,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.patch<Map<String, dynamic>>(
      Endpoints.examTemplateSection(courseId, templateId, sectionId),
      data: payload,
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Invalid response from PATCH /courses/{id}/exams/templates/{templateId}/sections/{sectionId}');
  }

  Future<Map<String, dynamic>> deleteExamTemplateSectionRaw({
    required int courseId,
    required int templateId,
    required int sectionId,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.delete<Map<String, dynamic>>(
      Endpoints.examTemplateSection(courseId, templateId, sectionId),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Invalid response from DELETE /courses/{id}/exams/templates/{templateId}/sections/{sectionId}');
  }
}


String? _filenameFromContentDisposition(String? value) {
  if (value == null || value.trim().isEmpty) return null;

  final encoded = RegExp(r"filename\*=UTF-8''([^;]+)", caseSensitive: false)
      .firstMatch(value)
      ?.group(1);
  if (encoded != null && encoded.trim().isNotEmpty) {
    return Uri.decodeComponent(encoded.trim().replaceAll('"', ''));
  }

  final normal = RegExp(r'filename="?([^";]+)"?', caseSensitive: false)
      .firstMatch(value)
      ?.group(1);
  final cleaned = normal?.trim().replaceAll('"', '');
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}
