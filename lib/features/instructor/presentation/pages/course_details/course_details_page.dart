import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/storage/key_value_store_factory.dart';
import '../../../data/courses_models.dart';
import '../../controllers/course_details_controller.dart';
import '../../widgets/course_tabs/overview_tab.dart';
import '../../widgets/course_tabs/materials_tab.dart';

import '../../widgets/course_tabs/outcomes_tab.dart';
import '../../widgets/course_outcomes_panel.dart';
import '../../widgets/course_tabs/question_bank_tab.dart';
import '../../widgets/course_tabs/students_tab.dart';

class CourseDetailsPage extends ConsumerStatefulWidget {
  final String courseSlug;
  final MyCourseItem course;

  const CourseDetailsPage({
    super.key,
    required this.courseSlug,
    required this.course,
  });

  @override
  ConsumerState<CourseDetailsPage> createState() => _CourseDetailsPageState();
}

class _CourseDetailsPageState extends ConsumerState<CourseDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final List<Widget> _pages;
  late final _session = createSessionStore();
  int _currentIndex = 0;

  String get _tabKey => 'course:${widget.course.id}:active_tab';

  static const _tabs = [
    _TabDef(icon: Icons.dashboard_outlined,     label: 'Overview'),
    _TabDef(icon: Icons.folder_open_outlined,   label: 'Materials'),
    _TabDef(icon: Icons.flag_outlined,          label: 'Outcomes'),
    _TabDef(icon: Icons.quiz_outlined,          label: 'Question Bank'),
    _TabDef(icon: Icons.people_outline_rounded, label: 'Students'),
  ];

  @override
  void initState() {
    super.initState();
    final storedIndex = int.tryParse(_session.getString(_tabKey) ?? '');
    _currentIndex = storedIndex != null && storedIndex >= 0 && storedIndex < _tabs.length ? storedIndex : 0;
    _tabController = TabController(length: _tabs.length, vsync: this, initialIndex: _currentIndex);
    _pages = [
      CourseOverviewTab(key: const PageStorageKey('course-overview-tab'), course: widget.course),
      CourseMaterialsTab(key: const PageStorageKey('course-materials-tab'), course: widget.course),
      CourseOutcomesTab(key: const PageStorageKey('course-outcomes-tab'), course: widget.course),
      CourseQuestionBankTab(key: const PageStorageKey('course-question-bank-tab'), course: widget.course),
      CourseStudentsTab(key: const PageStorageKey('course-students-tab'), course: widget.course),
    ];
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentIndex = _tabController.index);
        _session.setString(_tabKey, _currentIndex.toString());
      }
    });
    // Load modules immediately after the first frame so the provider
    // is available. Using addPostFrameCallback avoids calling read()
    // before the widget tree is fully mounted while still being
    // synchronous enough that the Overview stats appear on first paint.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await ref
          .read(courseDetailsControllerProvider(widget.course.id).notifier)
          .loadModulesAndAllMaterials();

      if (!mounted) return;
      await ensureCourseLearningOutcomesLoaded(ref, widget.course.id);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
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
          children: _pages,
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pill tab bar — flush to the left edge
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
    return Align(
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
      onExit:  (_) => setState(() => _hovered = false),
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
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
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
                child: Text(widget.label),
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
