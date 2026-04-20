import '../data/courses_models.dart';

String buildCourseRouteSlug(MyCourseItem course) {
  final base = (course.safeCourseCode.trim().isNotEmpty
          ? course.safeCourseCode
          : course.safeTitle)
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^a-z0-9\-]'), '')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  final prefix = base.isEmpty ? 'course' : base;
  return '$prefix-${course.id}';
}

int? parseCourseIdFromSlug(String slug) {
  final trimmed = slug.trim().toLowerCase();
  if (trimmed.isEmpty) return null;
  final direct = int.tryParse(trimmed);
  if (direct != null) return direct;

  final match = RegExp(r'(?:^|\-)(\d+)$').firstMatch(trimmed);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

bool slugMatchesCourse(String slug, MyCourseItem course) {
  final parsedId = parseCourseIdFromSlug(slug);
  if (parsedId != null) return parsedId == course.id;
  return buildCourseRouteSlug(course) == slug.trim().toLowerCase();
}
