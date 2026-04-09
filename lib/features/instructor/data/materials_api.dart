import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import 'materials_models.dart';

class MaterialsApi {
  final ApiClient _client;
  MaterialsApi(this._client);

  Future<MaterialListResponse> listMaterials({
    required int courseId,
    required int moduleId,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      Endpoints.moduleMaterials(courseId, moduleId),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return MaterialListResponse.fromJson(data);
    throw const FormatException('Invalid response from GET materials');
  }

  Future<MaterialInitUploadResponse> initUpload({
    required int courseId,
    required int moduleId,
    required MaterialInitUploadRequest payload,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.initMaterialUpload(courseId, moduleId),
      data: payload.toJson(),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return MaterialInitUploadResponse.fromJson(data);
    throw const FormatException('Invalid response from POST init-upload');
  }

  /// Upload file bytes directly to the presigned URL (Supabase/S3).
  /// This call bypasses our API client (no auth header needed).
  Future<void> uploadToPresignedUrl({
    required String uploadUrl,
    required Uint8List bytes,
    required String contentType,
    void Function(int sentBytes, int totalBytes)? onSendProgress,
  }) async {
    final dio = Dio();
    await dio.put(
      uploadUrl,
      data: bytes,
      onSendProgress: onSendProgress,
      options: Options(
        headers: {
          'Content-Type': contentType,
          'Content-Length': bytes.length,
        },
      ),
    );
  }

  Future<MaterialConfirmUploadResponse> confirmUpload({
    required int materialId,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.confirmMaterialUpload(materialId),
      data: {},
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return MaterialConfirmUploadResponse.fromJson(data);
    throw const FormatException('Invalid response from POST confirm-upload');
  }

  /// Fetches a fresh signed download URL for the given material.
  Future<String?> getDownloadUrl({
    required int courseId,
    required int moduleId,
    required int materialId,
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await _client.get<Map<String, dynamic>>(
        Endpoints.materialDownloadUrl(courseId, moduleId, materialId),
        cancelToken: cancelToken,
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        return data['download_url']?.toString() ??
               data['url']?.toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─── DELETE ───────────────────────────────────────────────────────────────
  /// DELETE /courses/{c}/modules/{m}/materials/{mat}
  Future<void> deleteMaterial({
    required int courseId,
    required int moduleId,
    required int materialId,
    CancelToken? cancelToken,
  }) async {
    await _client.delete<void>(
      Endpoints.deleteMaterial(courseId, moduleId, materialId),
      cancelToken: cancelToken,
    );
  }

  // ─── REASSIGN ─────────────────────────────────────────────────────────────
  /// PATCH /courses/{c}/modules/{m}/materials/{mat}/reassign
  /// Moves a material to a different module within the same course.
  Future<MaterialReassignResponse> reassignMaterial({
    required int courseId,
    required int moduleId,
    required int materialId,
    required int targetModuleId,
    CancelToken? cancelToken,
  }) async {
    final res = await _client.patch<Map<String, dynamic>>(
      Endpoints.reassignMaterial(courseId, moduleId, materialId),
      data: {'target_module_id': targetModuleId},
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return MaterialReassignResponse.fromJson(data);
    }
    throw const FormatException('Invalid response from PATCH material/reassign');
  }
}
