import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/log/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import 'courses_models.dart';

class CoursesApi {
  final ApiClient _client;
  CoursesApi(this._client);

  /// GET /courses/my
  Future<MyCoursesResponse> myCourses({CancelToken? cancelToken}) async {
    final res = await _client.get<Map<String, dynamic>>(
      Endpoints.myCourses,
      cancelToken: cancelToken,
    );

    final data = res.data;
    if (data is Map<String, dynamic>) {
      AppLogger.log('GET ${Endpoints.myCourses} -> $data', level: LogLevel.debug);
      return MyCoursesResponse.fromJson(data);
    }
    throw const FormatException('Invalid response from /courses/my');
  }

  /// GET /courses/{id}
  ///
  /// Used to reload a single course after a browser refresh, so the
  /// details page is never dependent on the in-memory cache.
  Future<MyCourseItem> getCourseById(
    int id, {
    CancelToken? cancelToken,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/courses/$id',
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      AppLogger.log('GET /courses/$id -> $data', level: LogLevel.debug);
      return MyCourseItem.fromJson(data);
    }
    throw FormatException('Invalid response from GET /courses/$id');
  }

  /// POST /courses
  ///
  /// NOTE: kept as Map to avoid breaking existing code.
  Future<Map<String, dynamic>> createCourse({
    required CourseCreateRequest payload,
    CancelToken? cancelToken,
  }) async {
    final title = payload.title.trim();
    if (title.isEmpty) {
      throw ArgumentError('Course title is required.');
    }

    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.createCourse,
      data: payload.toJson(),
      cancelToken: cancelToken,
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Invalid response from POST /courses');
  }

  /// POST /courses/{courseId}/invitations/upload
  ///
  /// Backend expects multipart file upload.
  Future<Map<String, dynamic>> uploadInvitationsFile({
    required String courseId,
    required Uint8List bytes,
    required String filename,
    CancelToken? cancelToken,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError('File bytes are empty.');
    }

    final form = FormData.fromMap({
      // IMPORTANT: backend expects field name "file"
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename.isNotEmpty ? filename : 'invitations.xlsx',
      ),
    });

    final res = await _client.post<Map<String, dynamic>>(
      '/courses/$courseId/invitations/upload',
      data: form,
      options: Options(
        // Dio will set the correct boundary automatically
        contentType: 'multipart/form-data',
      ),
      cancelToken: cancelToken,
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Invalid response from POST /courses/{id}/invitations/upload');
  }

  /// POST /courses/{courseId}/invitations/send
  Future<Map<String, dynamic>> sendInvitations({
    required String courseId,
    bool includeExpired = true,
    bool force = false,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/courses/$courseId/invitations/send',
      data: {
        'include_expired': includeExpired,
        'force': force,
      },
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Invalid response from POST /courses/{id}/invitations/send');
  }

  /// POST /courses/invitations/accept
  /// Student uses this to accept an invitation by token (from email link).
  Future<Map<String, dynamic>> acceptInvitation({
    required String token,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.acceptCourseInvitation,
      data: {'token': token},
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Invalid response from POST /courses/invitations/accept');
  }
}
