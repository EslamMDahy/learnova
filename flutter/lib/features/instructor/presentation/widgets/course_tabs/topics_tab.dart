import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../data/courses_models.dart';
import '../../controllers/course_details_controller.dart';

class CourseTopicsTab extends ConsumerWidget {
  final MyCourseItem course;
  const CourseTopicsTab({super.key, required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courseDetailsControllerProvider(course.id));
    final modules = state.modules;

    if (state.modulesLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (modules.isEmpty) {
      return const _NoModulesState();
    }

    return const _BackendTopicsPendingState();
  }
}

class _NoModulesState extends StatelessWidget {
  const _NoModulesState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.topic_outlined,
                size: 30,
                color: Color(0xFF7C3AED),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Modules Yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textTitle,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create modules in the Materials tab first,\nthen manage their topics here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
}

class _BackendTopicsPendingState extends StatelessWidget {
  const _BackendTopicsPendingState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.construction_rounded,
                    size: 30,
                    color: Color(0xFF137FEC),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Topics management is temporarily hidden',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTitle,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'This tab was using local mock authoring paths. It is now disabled until the backend-driven topics workflow is wired end-to-end.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
}
