import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
class SelectedCourseCache {
  SelectedCourseCache._();

  static const _key = 'learnova_selected_course';
  static MyCourseItem? _memory;

  // ── write ────────────────────────────────────────────────────────────────

  /// Call this whenever the user taps a course to navigate to its details.
  /// Stores in memory AND sessionStorage so F5 doesn't break navigation.
  static void set(MyCourseItem course) {
    _memory = course;
    try {
      // toJson() strips nulls — we need ALL fields including id, created_by,
      // dates, etc. so we build a complete map here.
      final full = <String, dynamic>{
        'id':                   course.id,
        'title':                course.title,
        'course_code':          course.courseCode,
        'course_type':          course.courseType,
        'organization_id':      course.organizationId,
        'is_public':            course.isPublic,
        'visibility_level':     course.visibilityLevel,
        'status':               course.status,
        'cover_image_url':      course.coverImageUrl,
        'banner_image_url':     course.bannerImageUrl,
        'category':             course.category,
        'created_by':           course.createdBy,
        'created_at':           course.createdAt.toIso8601String(),
        'updated_at':           course.updatedAt.toIso8601String(),
        'enrollment_count':     course.enrollmentCount,
        'pending_invites':      course.pendingInvites,
      };
      html.window.sessionStorage[_key] = jsonEncode(full);
    } catch (_) {
      // Storage write failure is non-fatal — memory still works within the tab.
    }
  }

  // ── read ─────────────────────────────────────────────────────────────────

  /// Memory-first for performance, sessionStorage fallback for after F5.
  /// Returns null only when no course has ever been selected in this tab.
  static MyCourseItem? get value {
    // Hot-path: still alive in memory (normal navigation, no refresh).
    if (_memory != null) return _memory;

    // Cold-path: Dart app just restarted (F5). Try to restore from storage.
    try {
      final raw = html.window.sessionStorage[_key];
      if (raw != null && raw.isNotEmpty) {
        final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
        _memory = MyCourseItem.fromJson(json);
        return _memory;
      }
    } catch (_) {
      // Corrupted data — wipe it so we don't keep retrying.
      _clearStorage();
    }

    return null;
  }

  // ── clear ────────────────────────────────────────────────────────────────

  /// Call on logout so stale course data doesn't leak across sessions.
  static void clear() {
    _memory = null;
    _clearStorage();
  }

  static void _clearStorage() {
    try { html.window.sessionStorage.remove(_key); } catch (_) {}
  }
}
