import 'course_vocabulary.dart';

enum CourseType { individual, organization }

enum CourseVisibilityLevel { private, public, unlisted }

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') return true;
  if (normalized == 'false' || normalized == '0') return false;
  return fallback;
}

int? _countFromDynamicCollection(dynamic value) {
  if (value is List) return value.length;
  if (value is Map<String, dynamic>) {
    final items = value['items'];
    if (items is List) return items.length;
    final modules = value['modules'];
    if (modules is List) return modules.length;
    final students = value['students'];
    if (students is List) return students.length;
    final enrollments = value['enrollments'];
    if (enrollments is List) return enrollments.length;
    return _asInt(value['count']) ?? _asInt(value['total']);
  }
  return null;
}

class MyCourseItem {
  final int id;
  final String title;
  final String? courseCode;
  final String courseType;
  final int? organizationId;
  final bool isPublic;
  final String visibilityLevel;
  final String status;

  final String? coverImageUrl;
  final String? bannerImageUrl;
  final String? category;

  final int createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  final int? enrollmentCount;
  final int? pendingInvites;
  final int? moduleCount;

  const MyCourseItem({
    required this.id,
    required this.title,
    required this.courseCode,
    required this.courseType,
    required this.organizationId,
    required this.isPublic,
    required this.visibilityLevel,
    required this.status,
    required this.coverImageUrl,
    required this.bannerImageUrl,
    required this.category,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.enrollmentCount,
    required this.pendingInvites,
    this.moduleCount,
  });

  /// Helpers (UI-friendly)
  String get safeTitle => title.trim().isEmpty ? 'Untitled course' : title.trim();

  String get safeCourseCode {
    final v = (courseCode ?? '').trim();
    return v.isEmpty ? 'CS-$id' : v;
  }

  CourseAccessType get accessType => parseCourseAccessType(courseType);

  CourseVisibility get visibility => parseCourseVisibility(visibilityLevel);

  CourseLifecycleStatus get lifecycleStatus => parseCourseLifecycleStatus(status);

  bool get isPrivate => visibility == CourseVisibility.private;

  MyCourseItem copyWith({
    int? id,
    String? title,
    String? courseCode,
    String? courseType,
    int? organizationId,
    bool? isPublic,
    String? visibilityLevel,
    String? status,
    String? coverImageUrl,
    String? bannerImageUrl,
    String? category,
    int? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? enrollmentCount,
    int? pendingInvites,
    int? moduleCount,
  }) {
    return MyCourseItem(
      id: id ?? this.id,
      title: title ?? this.title,
      courseCode: courseCode ?? this.courseCode,
      courseType: courseType ?? this.courseType,
      organizationId: organizationId ?? this.organizationId,
      isPublic: isPublic ?? this.isPublic,
      visibilityLevel: visibilityLevel ?? this.visibilityLevel,
      status: status ?? this.status,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      category: category ?? this.category,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      enrollmentCount: enrollmentCount ?? this.enrollmentCount,
      pendingInvites: pendingInvites ?? this.pendingInvites,
      moduleCount: moduleCount ?? this.moduleCount,
    );
  }

  factory MyCourseItem.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => (v ?? '').toString().trim();

    final enrollmentCount =
        _asInt(json['enrollment_count']) ??
        _asInt(json['student_count']) ??
        _asInt(json['students_count']) ??
        _asInt(json['active_students']) ??
        _countFromDynamicCollection(json['students']) ??
        _countFromDynamicCollection(json['enrollments']);

    final moduleCount =
        _asInt(json['module_count']) ??
        _asInt(json['modules_count']) ??
        _countFromDynamicCollection(json['modules']);

    return MyCourseItem(
      id: _asInt(json['id']) ?? 0,
      title: s(json['title']),
      courseCode: s(json['course_code']).isEmpty ? null : s(json['course_code']),
      courseType: parseCourseAccessType(s(json['course_type'])).backendValue,
      organizationId: _asInt(json['organization_id']),
      isPublic: _asBool(
        json['is_open_for_enrollment'] ?? json['is_public'],
      ),
      visibilityLevel: parseCourseVisibility(s(json['visibility_level'])).backendValue,
      status: parseCourseLifecycleStatus(s(json['status'])).backendValue,
      coverImageUrl: json['cover_image_url']?.toString(),
      bannerImageUrl: json['banner_image_url']?.toString(),
      category: json['category']?.toString(),
      createdBy: _asInt(json['created_by']) ?? 0,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      enrollmentCount: enrollmentCount,
      pendingInvites: _asInt(json['pending_invites']),
      moduleCount: moduleCount,
    );
  }
}

class MyCoursesResponse {
  final List<MyCourseItem> items;
  final int total;

  const MyCoursesResponse({required this.items, required this.total});

  factory MyCoursesResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map>()
        .map((e) => MyCourseItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return MyCoursesResponse(
      items: items,
      total: (json['total'] as num?)?.toInt() ?? items.length,
    );
  }
}


class CourseCreatedResponse {
  final int id;
  final String title;
  final String? courseCode;

  const CourseCreatedResponse({
    required this.id,
    required this.title,
    required this.courseCode,
  });

  factory CourseCreatedResponse.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => (v ?? '').toString().trim();

    return CourseCreatedResponse(
      id: _asInt(json['id']) ?? 0,
      title: s(json['title']),
      courseCode: s(json['course_code']).isEmpty ? null : s(json['course_code']),
    );
  }
}

class CourseCreateRequest {
  final String courseType; // "individual" | "organization"
  final int? organizationId;

  final String title;
  final String? description;
  final String? coverImageUrl;
  final String? bannerImageUrl;

  final bool isPublic;
  final String visibilityLevel; // "private" | "public" | "unlisted"
  final bool requiresEnrollmentApproval;

  final List<String>? learningOutcomes;
  final List<String>? tags;
  final String? category;

  
  final String? status; // "draft" | "published" | "archived"

  // UI-only fields (NOT sent to backend because backend schema forbids extra fields)
  final String? courseCode;
  final String? academicTerm;
  final String? localStatus;

  const CourseCreateRequest({
    required this.courseType,
    required this.organizationId,
    required this.title,
    required this.description,
    required this.coverImageUrl,
    required this.bannerImageUrl,
    required this.isPublic,
    required this.visibilityLevel,
    required this.requiresEnrollmentApproval,
    required this.learningOutcomes,
    required this.tags,
    required this.category,

    
    this.status,

    this.courseCode,
    this.academicTerm,
    this.localStatus,
  });

  Map<String, dynamic> toJson() {
    // IMPORTANT: backend uses extra="forbid" — only send fields the schema accepts.
    // Excluded: learning_outcomes (commented out in backend), cover_image_url,
    //           banner_image_url, academicTerm, localStatus (UI-only).
    final map = <String, dynamic>{
      'course_type': parseCourseAccessType(courseType).backendValue,
      'title': title,
      'is_open_for_enrollment': isPublic,
      'visibility_level': parseCourseVisibility(visibilityLevel).backendValue,
      'requires_enrollment_approval': requiresEnrollmentApproval,
    };

    // Optional backend fields — only include when non-null/non-empty
    if (organizationId != null) map['organization_id'] = organizationId;
    if (courseCode != null && courseCode!.trim().isNotEmpty) {
      map['course_code'] = courseCode!.trim();
    }
    if (description != null && description!.trim().isNotEmpty) {
      map['description'] = description!.trim();
    }
    if (tags != null && tags!.isNotEmpty) map['tags'] = tags;
    if (category != null && category!.trim().isNotEmpty) map['category'] = category;
    if (status != null) map['status'] = parseCourseLifecycleStatus(status).backendValue;

    return map;
  }
}
