import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import 'modules_models.dart';

class ModulesApi {
  final ApiClient _client;
  ModulesApi(this._client);

  // ─── LIST ─────────────────────────────────────────────────────────────────
  Future<ModuleListResponse> listModules({
    required int courseId,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      Endpoints.courseModules(courseId),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return ModuleListResponse.fromJson(data);
    throw const FormatException('Invalid response from GET modules');
  }

  // ─── CREATE ───────────────────────────────────────────────────────────────
  Future<ModuleItem> createModule({
    required int courseId,
    required ModuleCreateRequest payload,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.createModule(courseId),
      data: payload.toJson(),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return ModuleItem.fromJson(data);
    throw const FormatException('Invalid response from POST module');
  }

  // ─── UPDATE ───────────────────────────────────────────────────────────────
  /// PATCH /courses/{c}/modules/{m}/update
  Future<ModuleItem> updateModule({
    required int courseId,
    required int moduleId,
    required ModuleUpdateRequest payload,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.patch<Map<String, dynamic>>(
      Endpoints.updateModule(courseId, moduleId),
      data: payload.toJson(),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return ModuleItem.fromJson(data);
    throw const FormatException('Invalid response from PATCH module');
  }

  // ─── DELETE ───────────────────────────────────────────────────────────────
  /// DELETE /courses/{c}/modules/{m}/delete
  Future<void> deleteModule({
    required int courseId,
    required int moduleId,
    CancelToken? cancelToken,
  }) async {
    await _client.delete<void>(
      Endpoints.deleteModule(courseId, moduleId),
      cancelToken: cancelToken,
    );
  }

  // ─── COPY ─────────────────────────────────────────────────────────────────
  /// POST /courses/{targetCourseId}/modules/{moduleId}/copy
  ///
  /// Backend contract note:
  /// - the route is mounted under the TARGET course
  /// - [moduleId] is the source module id
  /// - the backend infers the source course from that module id
  ///
  /// The request body is still sent for forward compatibility, but the current
  /// backend persists the copy based on the target course in the URL path.
  Future<ModuleItem> copyModule({
    required int sourceCourseId,
    required int moduleId,
    required int targetCourseId,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.copyModule(targetCourseId, moduleId),
      data: {'target_course_id': targetCourseId},
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return ModuleItem.fromJson(data);
    throw const FormatException('Invalid response from POST module/copy');
  }

  // ─── REORDER ──────────────────────────────────────────────────────────────
  /// PATCH /courses/{c}/modules/reorder
  Future<ModuleReorderResponse> reorderModules({
    required int courseId,
    required List<int> moduleIds,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.patch<Map<String, dynamic>>(
      Endpoints.reorderModules(courseId),
      data: {'module_ids': moduleIds},
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return ModuleReorderResponse.fromJson(data);
    throw const FormatException('Invalid response from PATCH modules/reorder');
  }
}
