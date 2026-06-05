import 'package:flutter/material.dart';
import 'package:learnova/core/storage/user_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learnova/features/instructor/presentation/widgets/create_course_dialog.dart';
import 'package:learnova/features/instructor/presentation/widgets/invite_students_dialog.dart';
import 'package:learnova/features/instructor/data/mock_services.dart';
import 'package:learnova/features/instructor/data/authoring_mode.dart';
import 'package:learnova/features/instructor/presentation/widgets/instructor_course_widgets.dart';
import 'package:learnova/features/instructor/presentation/widgets/instructor_dashboard_content.dart';

import '../controllers/instructor_courses_controller.dart';

// ----------------------------------------------------------------
// SECTION: Dashboard Route Page
// ----------------------------------------------------------------
class InstructorDashboardRoutePage extends StatelessWidget {
  const InstructorDashboardRoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    final name = (UserStorage.userMap?['full_name'] ?? '').toString().trim();
    final displayName = name.isNotEmpty ? name : 'Professor';
    return InstructorDashboardContent(userName: displayName);
  }
}

// ----------------------------------------------------------------
// SECTION: Courses Route Page (Backend-ready)
// ----------------------------------------------------------------
class InstructorCourseRoutePage extends ConsumerStatefulWidget {
  const InstructorCourseRoutePage({super.key});

  @override
  ConsumerState<InstructorCourseRoutePage> createState() =>
      _InstructorCourseRoutePageState();
}

class _InstructorCourseRoutePageState extends ConsumerState<InstructorCourseRoutePage> {
  @override
  void initState() {
    super.initState();
    // Load my courses once when entering the page
    Future.microtask(() => ref
        .read(instructorCoursesControllerProvider.notifier)
        .load(force: true),);
  }

  Future<void> _openCreateCourse() async {
    final result = await showDialog<CreateCourseDialogResult>(
      context: context,
      builder: (_) => const CreateCourseDialog(),
    );

    if (result == null) return;

    // 1) Create course first (backend returns course with id)
    final created = await ref
        .read(instructorCoursesControllerProvider.notifier)
        .createCourse(result.request);

    final courseId = created.id;

    if (courseId <= 0) {
      await ref.read(instructorCoursesControllerProvider.notifier).load(force: true);
      return;
    }

    // 2) Seed locally-managed learning outcomes for the dedicated Outcomes tab.
    if (result.learningOutcomes.isNotEmpty &&
        ref.read(enableLocalAuthoringFallbackProvider)) {
      await ref
          .read(learningOutcomeMockServiceProvider)
          .seedOutcomes(courseId, result.learningOutcomes);
    }

    // 3) If course is PRIVATE (needs invites), open upload dialog with courseId
    if (result.needsInvites) {
      await showDialog<bool>(
        context: context,
        builder: (_) => InviteStudentsDialog(courseId: courseId),
      );
    }

    // 4) Refresh courses list after creation (and possible invites)
    await ref.read(instructorCoursesControllerProvider.notifier).load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(instructorCoursesControllerProvider);

    final controller = ref.read(instructorCoursesControllerProvider.notifier);

    return InstructorCourseContent(
      loading: state.loading,
      errorText: state.error,
      courses: state.items,
      onRefresh: () => controller.load(force: true),
      onCreateNewCourse: _openCreateCourse,
    );
  }
}
