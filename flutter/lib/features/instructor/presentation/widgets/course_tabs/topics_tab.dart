// ─────────────────────────────────────────────────────────────────────────────
//  Topics Tab — dedicated tab for viewing & managing all topics in a course
//  Shown per-module with AI/Manual badges and difficulty indicators.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../data/courses_models.dart';
import '../../../data/learning_outcomes_models.dart';
import '../../../data/mock_services.dart';
import '../../controllers/course_details_controller.dart';
import '../topic_management_panel.dart';

// ── Outcomes provider for this course ─────────────────────────────────────────
final _courseOutcomesProvider =
    StateProvider.family<List<LearningOutcome>, int>((ref, courseId) => []);

class CourseTopicsTab extends ConsumerStatefulWidget {
  final MyCourseItem course;
  const CourseTopicsTab({super.key, required this.course});

  @override
  ConsumerState<CourseTopicsTab> createState() => _CourseTopicsTabState();
}

class _CourseTopicsTabState extends ConsumerState<CourseTopicsTab> {
  int? _selectedModuleId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOutcomes());
  }

  Future<void> _loadOutcomes() async {
    final svc = ref.read(learningOutcomeMockServiceProvider);
    final outcomes = await svc.listOutcomes(widget.course.id);
    if (!mounted) return;
    ref
        .read(_courseOutcomesProvider(widget.course.id).notifier)
        .state = outcomes;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(courseDetailsControllerProvider(widget.course.id));
    final modules = state.modules;
    final outcomes = ref.watch(_courseOutcomesProvider(widget.course.id));

    if (state.modulesLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (modules.isEmpty) {
      return _NoModulesState();
    }

    // If none selected, select first
    final selectedId = _selectedModuleId ?? modules.first.id;
    final selectedModule =
        modules.firstWhere((m) => m.id == selectedId, orElse: () => modules.first);

    return Row(children: [
      // ── Left: Module list ─────────────────────────────────────────────────
      Container(
        width: 220,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: AppColors.border)),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [
              const Text('Modules',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,),),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.pageBg,
                    borderRadius: BorderRadius.circular(99),),
                child: Text('${modules.length}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,),),
              ),
            ],),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              itemCount: modules.length,
              itemBuilder: (_, i) {
                final m = modules[i];
                final isSelected = m.id == selectedId;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
                    borderRadius: BorderRadius.circular(8),
                    onTap: () =>
                        setState(() => _selectedModuleId = m.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 9,),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFEFF6FF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(
                                color: const Color(0xFFBFDBFE),)
                            : null,
                      ),
                      child: Row(children: [
                        Icon(
                          Icons.folder_rounded,
                          size: 15,
                          color: isSelected
                              ? const Color(0xFF137FEC)
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF137FEC)
                                  : AppColors.textTitle,
                            ),
                          ),
                        ),
                      ],),
                    ),
                  ),
                );
              },
            ),
          ),
        ],),
      ),

      // ── Right: Topic management panel ────────────────────────────────────
      Expanded(
        child: TopicManagementPanel(
          key: ValueKey(selectedModule.id),
          courseId: widget.course.id,
          moduleId: selectedModule.id,
          materialId: 0,
          moduleTitle: selectedModule.title,
          outcomes: outcomes,
        ),
      ),
    ],);
  }
}

class _NoModulesState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(16),),
          child: const Icon(Icons.topic_outlined,
              size: 30, color: Color(0xFF7C3AED),),
        ),
        const SizedBox(height: 16),
        const Text('No Modules Yet',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textTitle,),),
        const SizedBox(height: 8),
        const Text(
          'Create modules in the Materials tab first,\nthen manage their topics here.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13, color: AppColors.textMuted, height: 1.5,),
        ),
      ],
    ),
  );
}
