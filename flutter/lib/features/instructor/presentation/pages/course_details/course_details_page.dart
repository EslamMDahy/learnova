import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/network/error_mapper.dart';
import '../../../../../core/routing/routes.dart';
import '../../../data/courses_models.dart';
import '../../../data/courses_providers.dart';
import '../../controllers/course_details_controller.dart';
import '../../widgets/course_tabs/overview_tab.dart';
import '../../widgets/course_tabs/materials_tab.dart';
import '../../widgets/course_tabs/outcomes_tab.dart';
import '../../widgets/course_tabs/question_bank_tab.dart';
import '../../widgets/course_tabs/exam_templates_tab.dart';
import '../../widgets/course_tabs/students_tab.dart';
import '../../controllers/selected_course_provider.dart';
import '../../course_route_identity.dart';

enum CourseDetailsTab { overview, materials, outcomes, questionBank, templates, students }

class CourseDetailsPage extends ConsumerStatefulWidget {
  final String courseSlug;

  /// Provide this when the course is already in memory (normal navigation).
  /// When null the page self-loads via [selectedCourseByIdProvider].
  final MyCourseItem? cachedCourse;

  /// Numeric course id used as the fallback key for the API fetch when
  /// [cachedCourse] is null (e.g. after a browser refresh).
  final int? cachedCourseId;

  /// Route-backed active tab. Each tab has its own URL and lazy load boundary.
  final CourseDetailsTab initialTab;

  const CourseDetailsPage({
    super.key,
    required this.courseSlug,
    this.cachedCourse,
    this.cachedCourseId,
    this.initialTab = CourseDetailsTab.overview,
  });

  @override
  ConsumerState<CourseDetailsPage> createState() => _CourseDetailsPageState();
}

class _CourseDetailsPageState extends ConsumerState<CourseDetailsPage> {
  int _currentIndex = 0;
  int? _activeCourseId;
  final Set<int> _visitedTabIndexes = <int>{};
  final Set<String> _loadedTabKeys = <String>{};

  void _syncVisitedTabs(MyCourseItem? course) {
    final int? courseId = course?.id ?? widget.cachedCourseId;
    if (_activeCourseId != courseId) {
      _activeCourseId = courseId;
      _visitedTabIndexes
        ..clear()
        ..add(widget.initialTab.index);
      return;
    }
    _visitedTabIndexes.add(widget.initialTab.index);
  }

  Widget _buildPageForTab(MyCourseItem course, CourseDetailsTab tab) {
    switch (tab) {
      case CourseDetailsTab.overview:
        return CourseOverviewTab(
          key: PageStorageKey('course-${course.id}-overview-tab'),
          course: course,
        );
      case CourseDetailsTab.materials:
        return CourseMaterialsTab(
          key: PageStorageKey('course-${course.id}-materials-tab'),
          course: course,
        );
      case CourseDetailsTab.outcomes:
        return CourseOutcomesTab(
          key: PageStorageKey('course-${course.id}-outcomes-tab'),
          course: course,
        );
      case CourseDetailsTab.questionBank:
        return CourseQuestionBankTab(
          key: PageStorageKey('course-${course.id}-question-bank-tab'),
          course: course,
        );
      case CourseDetailsTab.templates:
        return CourseExamTemplatesTab(
          key: PageStorageKey('course-${course.id}-exam-templates-tab'),
          course: course,
        );
      case CourseDetailsTab.students:
        return CourseStudentsTab(
          key: PageStorageKey('course-${course.id}-students-tab'),
          course: course,
        );
    }
  }

  List<Widget> _buildVisitedTabPages(MyCourseItem course) {
    return CourseDetailsTab.values.map((CourseDetailsTab tab) {
      if (!_visitedTabIndexes.contains(tab.index)) {
        return const SizedBox.shrink();
      }
      return _buildPageForTab(course, tab);
    }).toList();
  }

  static const _privateTabs = [
    _TabDef(icon: Icons.dashboard_outlined, label: 'Overview'),
    _TabDef(icon: Icons.folder_open_outlined, label: 'Materials'),
    _TabDef(icon: Icons.flag_outlined, label: 'Outcomes'),
    _TabDef(icon: Icons.quiz_outlined, label: 'Question Bank'),
    _TabDef(icon: Icons.description_outlined, label: 'Templates'),
    _TabDef(icon: Icons.people_outline_rounded, label: 'Students'),
  ];

  static const _publicTabs = [
    _TabDef(icon: Icons.dashboard_outlined, label: 'Overview'),
    _TabDef(icon: Icons.folder_open_outlined, label: 'Materials'),
    _TabDef(icon: Icons.flag_outlined, label: 'Outcomes'),
    _TabDef(icon: Icons.quiz_outlined, label: 'Question Bank'),
    _TabDef(icon: Icons.description_outlined, label: 'Templates'),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab.index;
    _syncVisitedTabs(widget.cachedCourse);
    final course = widget.cachedCourse;
    if (course != null) _loadActiveTabData(course);
  }

  @override
  void didUpdateWidget(covariant CourseDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _currentIndex = widget.initialTab.index;
    }
    if (oldWidget.cachedCourseId != widget.cachedCourseId ||
        oldWidget.cachedCourse?.id != widget.cachedCourse?.id) {
      _activeCourseId = null;
      _loadedTabKeys.clear();
    }
    _syncVisitedTabs(widget.cachedCourse);

    final course = widget.cachedCourse;
    if (course != null &&
        (oldWidget.initialTab != widget.initialTab ||
            oldWidget.cachedCourse?.id != course.id)) {
      _loadActiveTabData(course);
    }
  }

  void _loadActiveTabData(MyCourseItem course) {
    final tab = widget.initialTab;
    final key = '${course.id}:${tab.name}';
    if (!_loadedTabKeys.add(key)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final notifier = ref.read(courseDetailsControllerProvider(course.id).notifier);

      switch (tab) {
        case CourseDetailsTab.overview:
          // Overview only needs the course structure. Do not preload materials,
          // topics, questions, outcomes, or invitations from here.
          await notifier.loadModules();
          break;
        case CourseDetailsTab.materials:
          // Materials tab starts with modules; each module/material branch loads
          // its own materials/topics only when opened by the user.
          await notifier.loadModules();
          break;
        case CourseDetailsTab.outcomes:
        case CourseDetailsTab.questionBank:
        case CourseDetailsTab.templates:
        case CourseDetailsTab.students:
          // These tabs own their loading in their own widgets.
          break;
      }
    });
  }

  String _routeForTab(MyCourseItem course, int index) {
    final slug = buildCourseRouteSlug(course);
    final tab = CourseDetailsTab.values[index];
    switch (tab) {
      case CourseDetailsTab.overview:
        return Routes.courseDetails(slug);
      case CourseDetailsTab.materials:
        return Routes.courseMaterials(slug);
      case CourseDetailsTab.outcomes:
        return Routes.courseOutcomes(slug);
      case CourseDetailsTab.questionBank:
        return Routes.courseQuestionBank(slug);
      case CourseDetailsTab.templates:
        return Routes.courseTemplates(slug);
      case CourseDetailsTab.students:
        return Routes.courseStudents(slug);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cachedCourse != null) {
      return _buildContent(widget.cachedCourse!);
    }

    if (widget.cachedCourseId != null) {
      final asyncCourse =
          ref.watch(selectedCourseByIdProvider(widget.cachedCourseId!));
      return asyncCourse.when(
        loading: () => _buildLoadingShell(),
        error: (e, _) => _buildErrorShell(mapApiFailure(e).message),
        data: (course) => _buildContent(course),
      );
    }

    return _buildErrorShell(
      'Course could not be loaded. Please go back and reopen it.',
    );
  }

  // ── Loading shell ───────────────────────────────────────────────────────────

  Widget _buildLoadingShell() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: const Center(
          child: SizedBox(
            height: 36,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
      const Expanded(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
    ],);
  }

  // ── Error shell ─────────────────────────────────────────────────────────────

  Widget _buildErrorShell(String message) {
    return Column(children: [
      Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
      ),
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    color: AppColors.dangerText, size: 40,),
                const SizedBox(height: 12),
                Text(
                  'Could not load course',
                  style: AppTextStyles.sectionTitle,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: AppTextStyles.muted,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ],);
  }

  // ── Main content ────────────────────────────────────────────────────────────

  Widget _buildContent(MyCourseItem course) {
    _syncVisitedTabs(course);
    _loadActiveTabData(course);
    final visibleTabs = course.isPrivate ? _privateTabs : _publicTabs;
    return Column(children: [
      // ── Tab header — centered, does NOT stretch to full width ─────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: _PillTabBar(
            tabs: visibleTabs,
            currentIndex: _currentIndex,
            onTap: (i) {
              if (i == _currentIndex) return;
              SelectedCourseCache.set(course);
              context.go(_routeForTab(course, i));
            },
          ),
        ),
      ),
      Expanded(
        child: IndexedStack(
          index: _currentIndex,
          children: _buildVisitedTabPages(course),
        ),
      ),
    ],);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pill tab bar — wraps its content, centered in the header
// ─────────────────────────────────────────────────────────────────────────────
class _PillTabBar extends StatelessWidget {
  final List<_TabDef> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _PillTabBar({
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final ultraCompact = constraints.maxWidth < 440;
        final bar = Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.pageBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(tabs.length, (i) {
              return _PillTab(
                icon: tabs[i].icon,
                label: tabs[i].label,
                compact: compact,
                showLabel: !ultraCompact || i == currentIndex,
                selected: i == currentIndex,
                onTap: () => onTap(i),
              );
            }),
          ),
        );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Align(
              child: bar,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Individual pill tab
// ─────────────────────────────────────────────────────────────────────────────
class _PillTab extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool compact;
  final bool showLabel;
  final bool selected;
  final VoidCallback onTap;

  const _PillTab({
    required this.icon,
    required this.label,
    this.compact = false,
    this.showLabel = true,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_PillTab> createState() => _PillTabState();
}

class _PillTabState extends State<_PillTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 10 : 14, vertical: widget.compact ? 7 : 7),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.cardBg
                : _hovered
                    ? AppColors.cardBg.withOpacity(0.62)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.selected
                    ? AppColors.primary
                    : AppColors.textMuted,
              ),
              if (widget.showLabel) ...[
                SizedBox(width: widget.compact ? 5 : 6),
                Text(
                  widget.compact && widget.label == 'Question Bank'
                      ? 'Questions'
                      : widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: widget.compact ? 12 : 13,
                    fontFamily: 'Inter',
                    fontWeight: widget.selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: widget.selected
                        ? AppColors.textTitle
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────
class _TabDef {
  final IconData icon;
  final String label;
  const _TabDef({required this.icon, required this.label});
}
