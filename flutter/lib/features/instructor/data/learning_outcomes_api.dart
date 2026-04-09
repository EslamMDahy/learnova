import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import 'learning_outcomes_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  LearningOutcomesApi
//
//  Wires all 5 LO endpoints:
//    GET    /courses/{course_id}/learning-outcomes              → list
//    POST   /courses/{course_id}/learning-outcomes              → create
//    GET    /courses/{course_id}/learning-outcomes/{id}         → get single
//    PATCH  /courses/{course_id}/learning-outcomes/{id}/update  → update
//    DELETE /courses/{course_id}/learning-outcomes/{id}/delete  → delete
// ─────────────────────────────────────────────────────────────────────────────

class LearningOutcomesApi {
  final ApiClient _client;
  LearningOutcomesApi(this._client);

  // ─── LIST ─────────────────────────────────────────────────────────────────
  Future<LearningOutcomeListResponse> listOutcomes({
    required int courseId,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      Endpoints.learningOutcomes(courseId),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return LearningOutcomeListResponse.fromJson(data);
    }
    throw const FormatException('Invalid response from GET learning-outcomes');
  }

  // ─── CREATE ───────────────────────────────────────────────────────────────
  Future<LearningOutcome> createOutcome({
    required int courseId,
    required LearningOutcome outcome,
    List<int>? topicIds,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.learningOutcomes(courseId),
      data: outcome.toCreateJson(topicIds: topicIds),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return LearningOutcome.fromJson(data);
    throw const FormatException('Invalid response from POST learning-outcomes');
  }

  // ─── GET SINGLE ───────────────────────────────────────────────────────────
  Future<LearningOutcome> getOutcome({
    required int courseId,
    required int outcomeId,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      Endpoints.getLearningOutcome(courseId, outcomeId),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return LearningOutcome.fromJson(data);
    throw const FormatException('Invalid response from GET learning-outcome/{id}');
  }

  // ─── UPDATE ───────────────────────────────────────────────────────────────
  Future<LearningOutcome> updateOutcome({
    required int courseId,
    required int outcomeId,
    required LearningOutcome outcome,
    List<int>? topicIds,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.patch<Map<String, dynamic>>(
      Endpoints.updateLearningOutcome(courseId, outcomeId),
      data: outcome.toUpdateJson(topicIds: topicIds),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return LearningOutcome.fromJson(data);
    throw const FormatException('Invalid response from PATCH learning-outcome/{id}/update');
  }

  // ─── DELETE ───────────────────────────────────────────────────────────────
  Future<void> deleteOutcome({
    required int courseId,
    required int outcomeId,
    CancelToken? cancelToken,
  }) async {
    await _client.delete<void>(
      Endpoints.deleteLearningOutcome(courseId, outcomeId),
      cancelToken: cancelToken,
    );
  }
}
