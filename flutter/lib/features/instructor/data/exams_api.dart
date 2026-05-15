import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import 'exam_models.dart';

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

  Future<ExamAddQuestionsResponse> addQuestions({
    required int courseId,
    required int examId,
    required List<int> questionIds,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.examQuestions(courseId, examId),
      data: ExamAddQuestionsPayload(questionIds: questionIds).toJson(),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return ExamAddQuestionsResponse.fromJson(data);
    throw const FormatException('Invalid response from POST /courses/{id}/exams/{examId}/questions');
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
}
