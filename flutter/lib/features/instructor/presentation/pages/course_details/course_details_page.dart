import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/storage/key_value_store_factory.dart';
import '../../../../../core/network/error_mapper.dart';
import '../../../data/courses_models.dart';
import '../../../data/courses_providers.dart';
import '../../controllers/course_details_controller.dart';
import '../../widgets/course_tabs/overview_tab.dart';
import '../../widgets/course_tabs/materials_tab.dart';
import '../../widgets/course_tabs/outcomes_tab.dart';
import '../../widgets/course_outcomes_panel.dart';
import '../../widgets/course_tabs/question_bank_tab.dart';
import '../../widgets/course_tabs/students_tab.dart';

class CourseDetailsPage extends ConsumerStatefulWidget {
  final String courseSlug;

  /// Provide this when the course is already in memory (normal navigation).
  /// When null the page self-loads via [selectedCourseByIdProvider].
  final MyCourseItem? cachedCourse;

  /// Numeric course id used as the fallback key for the API fetch when
  /// [cachedCourse] is null (e.g. after a browser refresh).
  final int? cachedCourseId;

  const CourseDetailsPage({
    super.key,
    required this.courseSlug,
    this.cachedCourse,
    this.cachedCourseId,
  });

  @override
  ConsumerState<CourseDetailsPage> createState() => _CourseDetailsPageState();
}

class _CourseDetailsPageState extends ConsumerState<CourseDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final List<Widget>? _pages;
  late final _session = createSessionStore();
  int _currentIndex = 0;

  List<Widget> _buildPages(MyCourseItem course) => [
        CourseOverviewTab(
            key: const PageStorageKey('course-overview-tab'), course: course),
        CourseMaterialsTab(
            key: const PageStorageKey('course-materials-tab'), course: course),
        CourseOutcomesTab(
            key: const PageStorageKey('course-outcomes-tab'), course: course),
        CourseQuestionBankTab(
            key: const PageStorageKey('course-question-bank-tab'),
            course: course),
        CourseStudentsTab(
            key: const PageStorageKey('course-students-tab'), course: course),
      ];

  String get _tabKey =>
      'course:${widget.cachedCourse?.id ?? widget.cachedCourseId ?? widget.courseSlug}:active_tab';

  static const _tabs = [
    _TabDef(icon: Icons.dashboard_outlined, label: 'Overview'),
    _TabDef(icon: Icons.folder_open_outlined, label: 'Materials'),
    _TabDef(icon: Icons.flag_outlined, label: 'Outcomes'),
    _TabDef(icon: Icons.quiz_outlined, label: 'Question Bank'),
    _TabDef(icon: Icons.people_outline_rounded, label: 'Students'),
  ];

  @override
  void initState() {
    super.initState();
    final storedIndex = int.tryParse(_session.getString(_tabKey) ?? '');
    _currentIndex = storedIndex != null &&
            storedIndex >= 0 &&
            storedIndex < _tabs.length
        ? storedIndex
        : 0;
    _tabController = TabController(
        length: _tabs.length, vsync: this, initialIndex: _currentIndex);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentIndex = _tabController.index);
        _session.setString(_tabKey, _currentIndex.toString());
      }
    });

    if (widget.cachedCourse != null) {
      _loadCourseData(widget.cachedCourse!);
    }
  }

  void _loadCourseData(MyCourseItem course) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref
          .read(courseDetailsControllerProvider(course.id).notifier)
          .loadModulesAndAllMaterials();
      if (!mounted) return;
      await ensureCourseLearningOutcomesLoaded(ref, course.id);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        data: (course) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadCourseData(course);
          });
          return _buildContent(course);
        },
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
        decoration: const BoxDecoration(
          color: Colors.white,
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
    ]);
  }

  // ── Error shell ─────────────────────────────────────────────────────────────

  Widget _buildErrorShell(String message) {
    return Column(children: [
      Container(
        height: 52,
        decoration: const BoxDecoration(
          color: Colors.white,
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
                const Icon(Icons.error_outline,
                    color: AppColors.dangerText, size: 40),
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
    ]);
  }

  // ── Main content ────────────────────────────────────────────────────────────

  Widget _buildContent(MyCourseItem course) {
    final pages = _buildPages(course);
    return Column(children: [
      // ── Tab header — centered, does NOT stretch to full width ─────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Center(
          child: _PillTabBar(
            tabs: _tabs,
            currentIndex: _currentIndex,
            onTap: (i) {
              setState(() => _currentIndex = i);
              _session.setString(_tabKey, i.toString());
              _tabController.animateTo(i);
            },
          ),
        ),
      ),
      Expanded(
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
    ]);
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
    return IntrinsicWidth(
      child: Container(
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
              selected: i == currentIndex,
              onTap: () => onTap(i),
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Individual pill tab
// ─────────────────────────────────────────────────────────────────────────────
class _PillTab extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PillTab({
    required this.icon,
    required this.label,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: widget.selected
                ? Colors.white
                : _hovered
                    ? Colors.white.withOpacity(0.5)
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
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
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
