import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import 'topics_models.dart';

class TopicsApi {
  final ApiClient _client;
  TopicsApi(this._client);

  // ─── LIST ─────────────────────────────────────────────────────────────────
  /// GET /courses/{c}/modules/{m}/materials/{mat}/topics
  Future<TopicListResponse> listTopics({
    required int courseId,
    required int moduleId,
    required int materialId,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      Endpoints.materialTopics(courseId, moduleId, materialId),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return TopicListResponse.fromJson(data);
    throw const FormatException('Invalid response from GET topics');
  }

  // ─── CREATE ───────────────────────────────────────────────────────────────
  /// POST /courses/{c}/modules/{m}/materials/{mat}/topics
  Future<TopicItem> createTopic({
    required int courseId,
    required int moduleId,
    required int materialId,
    required TopicCreateRequest payload,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.materialTopics(courseId, moduleId, materialId),
      data: payload.toJson(),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return TopicItem.fromJson(data);
    throw const FormatException('Invalid response from POST topic');
  }

  // ─── UPDATE ───────────────────────────────────────────────────────────────
  /// PATCH /courses/{c}/modules/{m}/materials/{mat}/topics/{t}/update
  Future<TopicItem> updateTopic({
    required int courseId,
    required int moduleId,
    required int materialId,
    required int topicId,
    required TopicUpdateRequest payload,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.patch<Map<String, dynamic>>(
      Endpoints.updateTopic(courseId, moduleId, materialId, topicId),
      data: payload.toJson(),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return TopicItem.fromJson(data);
    throw const FormatException('Invalid response from PATCH topic');
  }

  // ─── DELETE ───────────────────────────────────────────────────────────────
  /// DELETE /courses/{c}/modules/{m}/materials/{mat}/topics/{t}/delete
  Future<void> deleteTopic({
    required int courseId,
    required int moduleId,
    required int materialId,
    required int topicId,
    CancelToken? cancelToken,
  }) async {
    await _client.delete<void>(
      Endpoints.deleteTopic(courseId, moduleId, materialId, topicId),
      cancelToken: cancelToken,
    );
  }

  // ─── GET SINGLE ──────────────────────────────────────────────────────────────
  /// GET /courses/{c}/modules/{m}/materials/{mat}/topics/{t}
  /// Returns the topic with its linked learning outcomes.
  Future<TopicGetResponse> getTopic({
    required int courseId,
    required int moduleId,
    required int materialId,
    required int topicId,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      Endpoints.getTopic(courseId, moduleId, materialId, topicId),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return TopicGetResponse.fromJson(data);
    throw const FormatException('Invalid response from GET topics/{id}');
  }

  // ─── REORDER ──────────────────────────────────────────────────────────────
  /// PATCH /courses/{c}/modules/{m}/materials/{mat}/topics/reorder
  Future<TopicReorderResponse> reorderTopics({
    required int courseId,
    required int moduleId,
    required int materialId,
    required List<int> topicIds,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.patch<Map<String, dynamic>>(
      Endpoints.reorderTopics(courseId, moduleId, materialId),
      data: {'topic_ids': topicIds},
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return TopicReorderResponse.fromJson(data);
    throw const FormatException('Invalid response from PATCH topics/reorder');
  }
}
