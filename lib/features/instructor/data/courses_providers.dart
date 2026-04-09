import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import 'courses_api.dart';
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
