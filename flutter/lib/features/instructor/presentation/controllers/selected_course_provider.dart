import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/key_value_store_factory.dart';
import '../../data/courses_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  selectedCourseProvider — holds the last tapped course item.
// ─────────────────────────────────────────────────────────────────────────────

final selectedCourseProvider = StateProvider<MyCourseItem?>((ref) => null);

/// Static cache used by the router (non-Riverpod context).
///
/// BEFORE: pure in-memory only → lost on F5 refresh → redirect to courses list.
/// AFTER:  memory-first, sessionStorage fallback → survives browser refresh.
///         sessionStorage is tab-scoped, so it clears when the tab is closed —
///         which is exactly the right lifecycle for this data.
///
/// The router now reads [cachedCourseId] first; if available it passes the id
/// to [CourseDetailsPage] which loads via [selectedCourseByIdProvider].
/// This means a refresh no longer sends the user away — the page simply shows
/// a loading spinner while the API call completes.
class SelectedCourseCache {
  SelectedCourseCache._();

  static const _key = 'learnova_selected_course';
  static const _idKey = 'learnova_selected_course_id';
  static final _store = createSessionStore();
  static MyCourseItem? _memory;

  // ── write ────────────────────────────────────────────────────────────────

  /// Call this whenever the user taps a course to navigate to its details.
  /// Stores in memory AND sessionStorage so F5 doesn't break navigation.
  static void set(MyCourseItem course) {
    _memory = course;
    try {
      final full = <String, dynamic>{
        'id':               course.id,
        'title':            course.title,
        'course_code':      course.courseCode,
        'course_type':      course.courseType,
        'organization_id':  course.organizationId,
        'is_public':        course.isPublic,
        'visibility_level': course.visibilityLevel,
        'status':           course.status,
        'cover_image_url':  course.coverImageUrl,
        'banner_image_url': course.bannerImageUrl,
        'category':         course.category,
        'created_by':       course.createdBy,
        'created_at':       course.createdAt.toIso8601String(),
        'updated_at':       course.updatedAt.toIso8601String(),
        'enrollment_count': course.enrollmentCount,
        'pending_invites':  course.pendingInvites,
      };
      _store.setString(_key, jsonEncode(full));
      // Also persist the bare id so the router can trigger an API re-fetch
      // when the full JSON is unavailable or corrupted.
      _store.setString(_idKey, course.id.toString());
    } catch (_) {
      // Storage write failure is non-fatal — memory still works within the tab.
    }
  }

  // ── read ─────────────────────────────────────────────────────────────────

  /// Memory-first for performance, sessionStorage fallback for after F5.
  /// Returns null only when no course has ever been selected in this tab.
  static MyCourseItem? get value {
    if (_memory != null) return _memory;

    try {
      final raw = _store.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
        _memory = MyCourseItem.fromJson(json);
        return _memory;
      }
    } catch (_) {
      _clearStorage();
    }

    return null;
  }

  /// Returns only the persisted course id (faster than deserialising the full
  /// JSON). The router uses this as the fallback key when [value] is null.
  static int? get cachedCourseId {
    // Check memory first
    if (_memory != null) return _memory!.id;
    try {
      final raw = _store.getString(_idKey);
      if (raw != null && raw.isNotEmpty) return int.tryParse(raw);
    } catch (_) {}
    return null;
  }

  // ── clear ────────────────────────────────────────────────────────────────

  /// Call on logout so stale course data doesn't leak across sessions.
  static void clear() {
    _memory = null;
    _clearStorage();
  }

  static void _clearStorage() {
    try {
      _store.remove(_key);
      _store.remove(_idKey);
    } catch (_) {}
  }
}
