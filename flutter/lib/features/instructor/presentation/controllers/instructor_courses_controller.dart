import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_error_bus.dart';
import '../../../../core/network/error_mapper.dart';

import '../../data/courses_models.dart';
import '../../data/courses_providers.dart';
import 'instructor_courses_state.dart';

final instructorCoursesControllerProvider =
    StateNotifierProvider.autoDispose<InstructorCoursesController, InstructorCoursesState>(
  (ref) => InstructorCoursesController(ref),
);

class InstructorCoursesController extends StateNotifier<InstructorCoursesState> {
  InstructorCoursesController(this._ref) : super(const InstructorCoursesState());

  final Ref _ref;
  CancelToken? _cancel;

  Future<void> load({bool force = false}) async {
    
    if (state.loading && !force) return;

    _cancel?.cancel();
    _cancel = CancelToken();

    state = state.copyWith(loading: true);

    try {
      final res = await _ref.read(coursesRepositoryProvider).myCourses(
        cancelToken: _cancel,
        enrichMissingModuleCounts: true,
      );
      state = state.copyWith(loading: false, items: res.items);
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(_ref, failure);

      state = state.copyWith(
        loading: false,
        error: failure.message,
      );
    }
  }


  /// Course update/archive/delete are intentionally not implemented here because
  /// the uploaded FastAPI backend exposes create/list/invite endpoints only.
  /// Leaving guessed mutation calls here causes real 404 errors in the UI.

  /// Creates a course and returns the typed backend response.
  ///
  /// NOTE: We do NOT call load() here automatically because the UI flow
  /// might need the created courseId first (e.g., to upload invitations),
  /// then refresh after finishing that flow.
  Future<CourseCreatedResponse> createCourse(CourseCreateRequest payload) async {
    _cancel?.cancel();
    _cancel = CancelToken();

    state = state.copyWith(loading: true);

    try {
      final created = await _ref
          .read(coursesRepositoryProvider)
          .createCourse(payload: payload, cancelToken: _cancel);

      // stop loading here; the caller will decide when to refresh
      state = state.copyWith(loading: false);
      return created;
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(_ref, failure);

      state = state.copyWith(
        loading: false,
        error: failure.message,
      );
      rethrow;
    }
  }

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }
}
