import 'material_vocabulary.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Materials — data models (mirrors backend schemas exactly)
// ─────────────────────────────────────────────────────────────────────────────

class MaterialItem {
  final int id;
  final int moduleId;
  final String? title;
  final String? description;
  final String type;   // 'video' | 'pdf' | 'document' | 'presentation' | 'link' | 'quiz'
  final String status; // 'draft_upload' | 'uploaded' | 'processing' | 'ready' | 'error'
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final int? pageCount;
  final int? durationSeconds;
  final DateTime uploadedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? downloadUrl;

  const MaterialItem({
    required this.id,
    required this.moduleId,
    this.title,
    this.description,
    required this.type,
    required this.status,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.pageCount,
    this.durationSeconds,
    required this.uploadedAt,
    required this.createdAt,
    required this.updatedAt,
    this.downloadUrl,
  });

  String get displayTitle =>
      (title ?? fileName ?? 'Untitled Material').trim().isEmpty
          ? 'Untitled Material'
          : (title ?? fileName)!.trim();

  MaterialKind get kind => parseMaterialKind(type);

  MaterialProcessingStatus get processingStatus =>
      parseMaterialProcessingStatus(status);

  bool get isReady => processingStatus == MaterialProcessingStatus.ready;
  bool get isProcessing => processingStatus == MaterialProcessingStatus.processing ||
      processingStatus == MaterialProcessingStatus.draftUpload;
  // 'uploaded' = file is on Supabase but not AI-processed yet — still previewable
  bool get isError => processingStatus == MaterialProcessingStatus.error;

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    DateTime dt(dynamic v) => DateTime.tryParse((v ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return MaterialItem(
      id: (json['id'] as num).toInt(),
      moduleId: (json['module_id'] as num).toInt(),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      type: parseMaterialKind((json['type'] ?? 'pdf').toString()).backendValue,
      status: parseMaterialProcessingStatus((json['status'] ?? 'ready').toString()).backendValue,
      fileName: json['file_name']?.toString(),
      fileSize: json['file_size'] == null
          ? null
          : (json['file_size'] as num).toInt(),
      mimeType: json['mime_type']?.toString(),
      pageCount: json['page_count'] == null
          ? null
          : (json['page_count'] as num).toInt(),
      durationSeconds: json['duration_seconds'] == null
          ? null
          : (json['duration_seconds'] as num).toInt(),
      uploadedAt: dt(json['uploaded_at']),
      createdAt: dt(json['created_at']),
      updatedAt: dt(json['updated_at']),
      downloadUrl: json['download_url']?.toString(),
    );
  }
}

class MaterialListResponse {
  final int courseId;
  final int moduleId;
  final List<MaterialItem> materials;

  const MaterialListResponse({
    required this.courseId,
    required this.moduleId,
    required this.materials,
  });

  factory MaterialListResponse.fromJson(Map<String, dynamic> json) {
    final raw = (json['materials'] as List?) ?? const [];
    return MaterialListResponse(
      courseId: (json['course_id'] as num).toInt(),
      moduleId: (json['module_id'] as num).toInt(),
      materials: raw
          .whereType<Map>()
          .map((e) => MaterialItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// Step 1: init upload — gets a presigned URL from backend
class MaterialInitUploadRequest {
  final String filename;
  final String contentType;
  final int fileSizeBytes;
  final String? title;
  final String? description;

  const MaterialInitUploadRequest({
    required this.filename,
    required this.contentType,
    required this.fileSizeBytes,
    this.title,
    this.description,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'filename': filename,
      'content_type': contentType,
      'file_size_bytes': fileSizeBytes,
    };
    if (title != null) m['title'] = title;
    if (description != null) m['description'] = description;
    return m;
  }
}

class MaterialInitUploadResponse {
  final int materialId;
  final int moduleId;
  final int courseId;
  final String uploadUrl;
  final String storageKey;
  final String bucket;
  final String contentType;
  final int maxBytes;
  final String status;

  const MaterialInitUploadResponse({
    required this.materialId,
    required this.moduleId,
    required this.courseId,
    required this.uploadUrl,
    required this.storageKey,
    required this.bucket,
    required this.contentType,
    required this.maxBytes,
    required this.status,
  });

  factory MaterialInitUploadResponse.fromJson(Map<String, dynamic> json) {
    return MaterialInitUploadResponse(
      materialId: (json['material_id'] as num).toInt(),
      moduleId: (json['module_id'] as num).toInt(),
      courseId: (json['course_id'] as num).toInt(),
      uploadUrl: (json['upload_url'] ?? '').toString(),
      storageKey: (json['storage_key'] ?? '').toString(),
      bucket: (json['bucket'] ?? '').toString(),
      contentType: (json['content_type'] ?? '').toString(),
      maxBytes: (json['max_bytes'] as num?)?.toInt() ?? 0,
      status: parseMaterialProcessingStatus((json['status'] ?? 'draft_upload').toString()).backendValue,
    );
  }
}

class MaterialConfirmUploadResponse {
  final int materialId;
  final int moduleId;
  final int courseId;
  final String status;
  final DateTime updatedAt;
  final String? downloadUrl;

  const MaterialConfirmUploadResponse({
    required this.materialId,
    required this.moduleId,
    required this.courseId,
    required this.status,
    required this.updatedAt,
    this.downloadUrl,
  });

  factory MaterialConfirmUploadResponse.fromJson(Map<String, dynamic> json) {
    return MaterialConfirmUploadResponse(
      materialId: (json['material_id'] as num).toInt(),
      moduleId: (json['module_id'] as num).toInt(),
      courseId: (json['course_id'] as num).toInt(),
      status: parseMaterialProcessingStatus((json['status'] ?? '').toString()).backendValue,
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      downloadUrl: json['download_url']?.toString(),
    );
  }
}

// ─── Reassign response ────────────────────────────────────────────────────────
// Backend: { id, module_id, storage_key }
class MaterialReassignResponse {
  final int id;
  final int moduleId;
  final String storageKey;

  const MaterialReassignResponse({
    required this.id,
    required this.moduleId,
    required this.storageKey,
  });

  factory MaterialReassignResponse.fromJson(Map<String, dynamic> json) {
    return MaterialReassignResponse(
      id: (json['id'] as num).toInt(),
      moduleId: (json['module_id'] as num).toInt(),
      storageKey: (json['storage_key'] ?? '').toString(),
    );
  }
}
