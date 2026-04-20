import '../../../core/log/app_logger.dart';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'courses_api.dart';
import 'courses_models.dart';
import 'modules_api.dart';

class CoursesRepository {
  final CoursesApi _api;
  final ModulesApi _modulesApi;

  CoursesRepository(this._api, this._modulesApi);

  Future<MyCoursesResponse> myCourses({
    CancelToken? cancelToken,
    bool enrichMissingModuleCounts = false,
  }) async {
    final response = await _api.myCourses(cancelToken: cancelToken);

    if (!enrichMissingModuleCounts) {
      return response;
    }

    final enrichedItems = await Future.wait(
      response.items.map((course) async {
        final existingModuleCount = course.moduleCount;
        if (existingModuleCount != null && existingModuleCount > 0) {
          return course;
        }

        try {
          final modulesResponse = await _modulesApi.listModules(
            courseId: course.id,
            cancelToken: cancelToken,
          );
          return course.copyWith(moduleCount: modulesResponse.modules.length);
        } catch (e, st) {
          AppLogger.log(
            'Failed to load modules count for course ${course.id}',
            level: LogLevel.warn,
            error: e,
            stackTrace: st,
          );
          return course.copyWith(moduleCount: existingModuleCount ?? 0);
        }
      }),
    );

    return MyCoursesResponse(items: enrichedItems, total: response.total);
  }

  /// Fetch a single course by its numeric id.
  ///
  /// Used by [selectedCourseByIdProvider] so the details page can reload
  /// itself after a browser refresh without depending on the in-memory cache.
  Future<MyCourseItem> getCourseById(
    int id, {
    CancelToken? cancelToken,
  }) =>
      _api.getCourseById(id, cancelToken: cancelToken);

  Future<CourseCreatedResponse> createCourse({
    required CourseCreateRequest payload,
    CancelToken? cancelToken,
  }) =>
      _api.createCourse(payload: payload, cancelToken: cancelToken);

  /// Upload invitations Excel/CSV file
  /// -> POST /courses/{id}/invitations/upload
  Future<Map<String, dynamic>> uploadInvitationsFile({
    required String courseId,
    required Uint8List bytes,
    required String filename,
    CancelToken? cancelToken,
  }) =>
      _api.uploadInvitationsFile(
        courseId: courseId,
        bytes: bytes,
        filename: filename,
        cancelToken: cancelToken,
      );

  /// Send invitations after upload
  /// -> POST /courses/{id}/invitations/send
  Future<Map<String, dynamic>> sendInvitations({
    required String courseId,
    bool includeExpired = true,
    bool force = false,
    CancelToken? cancelToken,
  }) =>
      _api.sendInvitations(
        courseId: courseId,
        includeExpired: includeExpired,
        force: force,
        cancelToken: cancelToken,
      );
}
