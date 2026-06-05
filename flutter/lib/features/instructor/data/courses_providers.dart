import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import 'courses_api.dart';
import 'courses_models.dart';
import 'courses_repository.dart';
import 'modules_materials_providers.dart';

final coursesApiProvider = Provider<CoursesApi>((ref) {
  return CoursesApi(ref.read(apiClientProvider));
});

final coursesRepositoryProvider = Provider<CoursesRepository>((ref) {
  return CoursesRepository(
    ref.read(coursesApiProvider),
    ref.read(modulesApiProvider),
  );
});

/// Fetches a single [MyCourseItem] by its numeric id.
///
/// This is the "cold start" provider used by [CourseDetailsPage] when the
/// in-memory [SelectedCourseCache] is empty (e.g. after a browser refresh).
/// Using a [FutureProvider.family] means:
///   • The URL (course id) is the source of truth — not in-memory state.
///   • Riverpod caches the result; subsequent watches are instant.
///   • The page gets a proper loading/error/data lifecycle for free.
final selectedCourseByIdProvider =
    FutureProvider.family<MyCourseItem, int>((ref, id) async {
  final response = await ref.read(coursesRepositoryProvider).myCourses(
        
      );

  for (final course in response.items) {
    if (course.id == id) return course;
  }

  throw StateError('Course not found in your courses. Reopen it from Courses.');
});
