import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:learnova/core/routing/routes.dart';
import 'package:learnova/core/ui/toast.dart';
import '../../data/courses_models.dart';
import '../../data/course_vocabulary.dart';
import 'package:learnova/shared/widgets/app_ui_components.dart';
import 'invite_students_dialog.dart';
import '../controllers/selected_course_provider.dart';
import '../course_route_identity.dart';

typedef CourseUpdateAction = Future<MyCourseItem> Function(
  MyCourseItem course,
  CourseUpdateRequest payload,
);
typedef CourseArchiveAction = Future<MyCourseItem> Function(MyCourseItem course);
typedef CourseDeleteAction = Future<void> Function(MyCourseItem course);

class InstructorCourseContent extends StatefulWidget {
  final VoidCallback? onCreateNewCourse;
  final VoidCallback? onRefresh;
  final bool loading;
  final String? errorText;
  final List<MyCourseItem> courses;
  final CourseUpdateAction? onUpdateCourse;
  final CourseArchiveAction? onArchiveCourse;
  final CourseDeleteAction? onDeleteCourse;

  const InstructorCourseContent({
    super.key,
    this.onCreateNewCourse,
    this.onRefresh,
    this.loading = false,
    this.errorText,
    this.courses = const [],
    this.onUpdateCourse,
    this.onArchiveCourse,
    this.onDeleteCourse,
  });

  @override
  State<InstructorCourseContent> createState() =>
      _InstructorCourseContentState();
}
class _InstructorCourseContentState extends State<InstructorCourseContent> {
  final _search = TextEditingController();
  Timer? _searchDebounce;

  String _searchText = '';

  String selectedSemester = 'All Semesters';
  String selectedStatus = 'All Statuses';
  String selectedType = 'All Types';

  // ---- Caches (performance)
  List<MyCourseItem> _cachedFiltered = [];
  String _cacheKey = '';

  int _totalCoursesCached = 0;
  int _activeStudentsTotalCached = 0;
  int _pendingInvitesTotalCached = 0;

  @override
  void initState() {
    super.initState();
    _recomputeTotals();
  }

  @override
  void didUpdateWidget(covariant InstructorCourseContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the list changed (e.g. fetched from API), recompute totals and clear the cache key
    if (!identical(oldWidget.courses, widget.courses) ||
        oldWidget.courses.length != widget.courses.length) {
      _recomputeTotals();
      _cacheKey = '';
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _recomputeTotals() {
    _totalCoursesCached = widget.courses.length;

    _activeStudentsTotalCached =
        widget.courses.fold<int>(0, (sum, c) => sum + (c.enrollmentCount ?? 0));

    _pendingInvitesTotalCached =
        widget.courses.fold<int>(0, (sum, c) => sum + (c.pendingInvites ?? 0));
  }

  void _recomputeFiltered() {
    final key =
        '${_searchText.trim().toLowerCase()}|$selectedSemester|$selectedStatus|$selectedType|${widget.courses.length}';
    if (key == _cacheKey) return;
    _cacheKey = key;

    final q = _searchText.trim().toLowerCase();

    bool statusOk(MyCourseItem c) {
      if (selectedStatus == 'All Statuses') return true;
      return c.status.trim().toLowerCase() == selectedStatus.toLowerCase();
    }

    bool semesterOk(MyCourseItem c) {
      if (selectedSemester == 'All Semesters') return true;
      
      return true; 
    }

    bool typeOk(MyCourseItem c) {
      if (selectedType == 'All Types') return true;
      return c.courseType.trim().toLowerCase() == selectedType.toLowerCase();
    }

    bool searchOk(MyCourseItem c) {
      if (q.isEmpty) return true;

      final title = c.title.toLowerCase();
      final code = c.safeCourseCode
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '-')
          .replaceAll(RegExp(r'[^a-z0-9\-]'), '');

      return title.contains(q) || code.contains(q);
    }

    _cachedFiltered = widget.courses.where((c) {
      return statusOk(c) && semesterOk(c) && typeOk(c) && searchOk(c);
    }).toList(growable: false);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() {
        _searchText = value;
        _cacheKey = ''; // ensure filter recomputation on next render
      });
    });
  }

  void _clearAll() {
    _search.clear();
    setState(() {
      _searchText = '';
      selectedSemester = 'All Semesters';
      selectedStatus = 'All Statuses';
      selectedType = 'All Types';
      _cacheKey = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    _recomputeFiltered();
    final courses = _cachedFiltered;

    final hasActiveFilters = (_searchText.trim().isNotEmpty) ||
        selectedSemester != 'All Semesters' ||
        selectedStatus != 'All Statuses' ||
        selectedType != 'All Types';

    return Container(
      color: _CourseTokens.pageBg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenW = constraints.maxWidth;

          int columns = 4;
          if (screenW < 1200) columns = 3;
          if (screenW < 900) columns = 2;
          if (screenW < 600) columns = 1;

          final maxContentWidth = _clamp(screenW - 220, 1180, 1560);

          final horizontalPadding = screenW >= 1600
              ? 24.0
              : screenW >= 1400
                  ? 32.0
                  : screenW >= 1100
                      ? 48.0
                      : 20.0;

          final topPadding = screenW < 900 ? 18.0 : 26.0;
          final isNarrow = constraints.maxWidth < 1100;

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 28),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    topPadding,
                    horizontalPadding,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      const _Breadcrumb(),
                      const SizedBox(height: 14),
                      _HeaderRow(
                        onCreateNewCourse: widget.onCreateNewCourse,
                        onRefresh: widget.onRefresh,
                      ),
                      const SizedBox(height: 18),
                      _StatsRow(
                        totalCourses: _totalCoursesCached,
                        activeStudents: _activeStudentsTotalCached,
                        pendingInvites: _pendingInvitesTotalCached,
                      ),
                      const SizedBox(height: 16),
                      _CoursesFiltersBar(
                        controller: _search,
                        isNarrow: isNarrow,
                        selectedSemester: selectedSemester,
                        selectedStatus: selectedStatus,
                        selectedType: selectedType,
                        onSearchChanged: _onSearchChanged,
                        onSemesterChanged: (v) =>
                            setState(() => selectedSemester = v),
                        onStatusChanged: (v) =>
                            setState(() => selectedStatus = v),
                        onTypeChanged: (v) => setState(() => selectedType = v),
                        onMoreFilters: () {},
                        onRefresh: widget.onRefresh ?? () {},
                      ),
                      const SizedBox(height: 12),
                      _ActiveFiltersChips(
                        searchText: _searchText,
                        selectedSemester: selectedSemester,
                        selectedStatus: selectedStatus,
                        selectedType: selectedType,
                        onClearAll: _clearAll,
                        onClearSearch: () {
                          _search.clear();
                          setState(() {
                            _searchText = '';
                            _cacheKey = '';
                          });
                        },
                        onClearSemester: () => setState(() {
                          selectedSemester = 'All Semesters';
                          _cacheKey = '';
                        }),
                        onClearStatus: () => setState(() {
                          selectedStatus = 'All Statuses';
                          _cacheKey = '';
                        }),
                        onClearType: () => setState(() {
                          selectedType = 'All Types';
                          _cacheKey = '';
                        }),
                      ),
                      if ((widget.errorText ?? '').trim().isNotEmpty) ...[
                        _InlineErrorBanner(
                          message: widget.errorText!.trim(),
                          onRetry: widget.onRefresh,
                        ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 18),
                      _CoursesGrid(
                        columns: columns,
                        courses: courses,
                        loading: widget.loading,
                        hasAnyCourses: widget.courses.isNotEmpty,
                        hasActiveFilters: hasActiveFilters,
                        onClearFilters: _clearAll,
                        onCreateFirstCourse: widget.onCreateNewCourse,
                        onUpdateCourse: widget.onUpdateCourse,
                        onArchiveCourse: widget.onArchiveCourse,
                        onDeleteCourse: widget.onDeleteCourse,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
// ==================== Filters Bar ====================

class _CoursesFiltersBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isNarrow;

  final String selectedSemester;
  final String selectedStatus;
  final String selectedType;

  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSemesterChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onTypeChanged;

  final VoidCallback onMoreFilters;
  final VoidCallback onRefresh;

  const _CoursesFiltersBar({
    required this.controller,
    required this.isNarrow,
    required this.selectedSemester,
    required this.selectedStatus,
    required this.selectedType,
    required this.onSearchChanged,
    required this.onSemesterChanged,
    required this.onStatusChanged,
    required this.onTypeChanged,
    required this.onMoreFilters,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final search = FigmaUmSearch40(
      controller: controller,
      onChanged:  onSearchChanged,
    );

    final semesterDrop = FigmaUmDropdown40(
      width: isNarrow ? 170 : 158,
      value: selectedSemester,
      items: [
        'All Semesters',
        'Fall 2023',
        'Spring 2024',
        'Fall 2024',
        'Spring 2025',
      ],
      onChanged: onSemesterChanged,
    );

    final statusDrop = FigmaUmDropdown40(
      width: isNarrow ? 158 : 146,
      value: selectedStatus,
      items: ['All Statuses', 'active', 'draft', 'archived'],
      onChanged: onStatusChanged,
    );

    final typeDrop = FigmaUmDropdown40(
      width: isNarrow ? 140 : 128,
      value: selectedType,
      items: ['All Types', 'lecture', 'seminar', 'lab'],
      onChanged: onTypeChanged,
    );

    return Container(
      height: isNarrow ? null : 56,
      padding: EdgeInsets.symmetric(
          horizontal: 16, vertical: isNarrow ? 12 : 0,),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppColors.borderGray),
        boxShadow: [
          const BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),),
        ],
      ),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                search,
                const SizedBox(height: 12),
                Row(children: [
                  semesterDrop,
                  const SizedBox(width: 10),
                  statusDrop,
                  const SizedBox(width: 10),
                  typeDrop,
                ],),
              ],
            )
          : Row(children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              semesterDrop,
              const SizedBox(width: 10),
              statusDrop,
              const SizedBox(width: 10),
              typeDrop,
            ],),
    );
  }
}

// ==================== Active Filter Chips ====================

class _ActiveFiltersChips extends StatelessWidget {
  final String searchText;
  final String selectedSemester;
  final String selectedStatus;
  final String selectedType;

  final VoidCallback onClearAll;
  final VoidCallback onClearSearch;
  final VoidCallback onClearSemester;
  final VoidCallback onClearStatus;
  final VoidCallback onClearType;

  const _ActiveFiltersChips({
    required this.searchText,
    required this.selectedSemester,
    required this.selectedStatus,
    required this.selectedType,
    required this.onClearAll,
    required this.onClearSearch,
    required this.onClearSemester,
    required this.onClearStatus,
    required this.onClearType,
  });

  bool get _hasAny =>
      (searchText.trim().isNotEmpty) ||
      selectedSemester != 'All Semesters' ||
      selectedStatus   != 'All Statuses'  ||
      selectedType     != 'All Types';

  @override
  Widget build(BuildContext context) {
    if (!_hasAny) return const SizedBox.shrink();

    Widget chip(String label, VoidCallback onDeleted) {
      return InputChip(
        label: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 12,),),
        onDeleted:       onDeleted,
        deleteIcon:      const Icon(Icons.close_rounded, size: 16),
        backgroundColor: AppColors.headerBg,
        side:  BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing:            10,
        runSpacing:         10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (searchText.trim().isNotEmpty)
            chip('Search: "${searchText.trim()}"', onClearSearch),
          if (selectedSemester != 'All Semesters')
            chip('Semester: $selectedSemester', onClearSemester),
          if (selectedStatus != 'All Statuses')
            chip('Status: $selectedStatus', onClearStatus),
          if (selectedType != 'All Types')
            chip('Type: $selectedType', onClearType),
          TextButton.icon(
            onPressed: onClearAll,
            icon:  const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Clear all',
                style: TextStyle(fontWeight: FontWeight.w900),),
            style: TextButton.styleFrom(
                foregroundColor: _CourseTokens.blue,),
          ),
        ],
      ),
    );
  }
}

// ==================== Helpers ====================

double _clamp(double v, double min, double max) {
  if (v < min) return min;
  if (v > max) return max;
  return v;
}

// ==================== Design Tokens ====================

class _CourseTokens {
  static Color get pageBg => AppColors.pageBg;
  static Color get cardBg => AppColors.cardBg;
  static Color get border => AppColors.borderGray;
  static Color get divider => AppColors.headerBg;

  static Color get textPrimary => AppColors.textTitle;
  static Color get textMuted => AppColors.textMuted;
  static Color get textHint => AppColors.textHint;

  static Color get blue => AppColors.primary;

  static const radiusCard       = 12.0;
  static const statCardHeight   = 88.0;
  static const courseCardHeight = 322.0;
  static const heroHeight       = 128.0;

  static const hoverShadow = [
    BoxShadow(
        color: Color(0x14000000), blurRadius: 26, offset: Offset(0, 14),),
  ];
}

// ==================== Breadcrumb ====================

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.home_rounded, size: 14, color: _CourseTokens.textHint),
        const SizedBox(width: 8),
        Text('Home',
            style: TextStyle(
                color:      _CourseTokens.textHint,
                fontSize:   12,
                fontWeight: FontWeight.w600,),),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right_rounded,
            size: 16, color: Color(0xFFCBD5E1),),
        const SizedBox(width: 8),
        Text('Courses Management',
            style: TextStyle(
                color:      _CourseTokens.textHint,
                fontSize:   12,
                fontWeight: FontWeight.w600,),),
      ],
    );
  }
}

// ==================== Header Row ====================

class _HeaderRow extends StatelessWidget {
  final VoidCallback? onCreateNewCourse;
  final VoidCallback? onRefresh;

  const _HeaderRow({this.onCreateNewCourse, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 820;

      final left = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Courses',
              style: TextStyle(
                  fontSize:   30,
                  fontWeight: FontWeight.w900,
                  color:      _CourseTokens.textPrimary,
                  height:     1.05,),),
          const SizedBox(height: 6),
          Text(
              'Manage your curriculum, AI assessments, and student cohorts.',
              style: TextStyle(
                  color:      _CourseTokens.textMuted,
                  fontSize:   13.2,
                  fontWeight: FontWeight.w600,),),
        ],
      );

      final btn = _PrimaryButton(onPressed: onCreateNewCourse);

      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            left,
            const SizedBox(height: 14),
            Align(alignment: Alignment.centerLeft, child: btn),
          ],
        );
      }

      return Row(children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        btn,
      ],);
    },);
  }
}

class _PrimaryButton extends StatefulWidget {
  final VoidCallback? onPressed;
  const _PrimaryButton({required this.onPressed});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit:  (_) => setState(() => hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: hover ? _CourseTokens.hoverShadow : [],
        ),
        child: ElevatedButton.icon(
          onPressed: widget.onPressed,
          icon:  const Icon(Icons.add, size: 18, color: Colors.white),
          label: const Text('Create New Course',
              style: TextStyle(
                  height: 1.0,
                  leadingDistribution: TextLeadingDistribution.even,
                  fontSize:   12.6,
                  fontWeight: FontWeight.w800,
                  color:      Colors.white,),),
          style: ElevatedButton.styleFrom(
            alignment: Alignment.center,
            backgroundColor: _CourseTokens.blue,
            elevation:   0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12,),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),),
          ),
        ),
      ),
    );
  }
}

// ==================== Stats Row ====================

class _StatsRow extends StatelessWidget {
  final int totalCourses;
  final int activeStudents;
  final int pendingInvites;

  const _StatsRow({
    required this.totalCourses,
    required this.activeStudents,
    required this.pendingInvites,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wrap = c.maxWidth < 900;

      final cards = [
        _MiniStatCard(
          title:     'TOTAL COURSES',
          value:     totalCourses.toString(),
          icon:      Icons.folder_outlined,
          iconBg:    const Color(0xFFEAF2FF),
          iconColor: AppColors.primary,
        ),
        _MiniStatCard(
          title:     'ACTIVE STUDENTS',
          value:     activeStudents.toString(),
          icon:      Icons.people_outline_rounded,
          iconBg:    const Color(0xFFE9FBF1),
          iconColor: AppColors.successText,
        ),
        _MiniStatCard(
          title:     'PENDING INVITES',
          value:     pendingInvites.toString(),
          icon:      Icons.mail_outline_rounded,
          iconBg:    const Color(0xFFFFF4DB),
          iconColor: const Color(0xFFF59E0B),
        ),
      ];

      if (!wrap) {
        return Row(children: [
          Expanded(
              child: SizedBox(
                  height: _CourseTokens.statCardHeight,
                  child: cards[0],),),
          const SizedBox(width: 16),
          Expanded(
              child: SizedBox(
                  height: _CourseTokens.statCardHeight,
                  child: cards[1],),),
          const SizedBox(width: 16),
          Expanded(
              child: SizedBox(
                  height: _CourseTokens.statCardHeight,
                  child: cards[2],),),
        ],);
      }

      return Wrap(
        spacing:    16,
        runSpacing: 16,
        children: cards
            .map((w) => SizedBox(
                width:  (c.maxWidth - 16) / 2,
                height: _CourseTokens.statCardHeight,
                child:  w,),)
            .toList(),
      );
    },);
  }
}

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color:         _CourseTokens.textHint,
                      fontSize:      10.4,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: 0.35,),),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      color:      _CourseTokens.textPrimary,
                      fontSize:   24,
                      fontWeight: FontWeight.w900,
                      height:     1.0,),),
            ],
          ),
        ),
        Container(
          width:  34,
          height: 34,
          decoration: BoxDecoration(
            color:        iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ],),
    );
  }
}


// ==================== Courses Grid ====================

class _CoursesGrid extends StatelessWidget {
  final int columns;
  final List<MyCourseItem> courses;
  final bool loading;
  final bool hasAnyCourses;
  final bool hasActiveFilters;
  final VoidCallback? onClearFilters;
  final VoidCallback? onCreateFirstCourse;
  final CourseUpdateAction? onUpdateCourse;
  final CourseArchiveAction? onArchiveCourse;
  final CourseDeleteAction? onDeleteCourse;

  const _CoursesGrid({
    required this.columns,
    required this.courses,
    required this.loading,
    required this.hasAnyCourses,
    required this.hasActiveFilters,
    this.onClearFilters,
    this.onCreateFirstCourse,
    this.onUpdateCourse,
    this.onArchiveCourse,
    this.onDeleteCourse,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && courses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child:   _CoursesGridSkeleton(),
      );
    }

    if (courses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child:   hasAnyCourses && hasActiveFilters
            ? _NoResultsState(onClear: onClearFilters)
            : _CoursesEmptyState(onCreate: onCreateFirstCourse),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      const gap         = 16.0;
      final totalWidth  = constraints.maxWidth;
      final columnWidth = (totalWidth - (columns - 1) * gap) / columns;

      return Wrap(
        spacing:    gap,
        runSpacing: gap,
        children: courses.map((course) {
          return SizedBox(
            width: columnWidth,
            child: _ApiCourseCard(
              course: course,
              onUpdateCourse: onUpdateCourse,
              onArchiveCourse: onArchiveCourse,
              onDeleteCourse: onDeleteCourse,
            ),
          );
        }).toList(),
      );
    },);
  }
}

class _CoursesGridSkeleton extends StatelessWidget {
  const _CoursesGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      int columns = 4;
      if (w < 1200) columns = 3;
      if (w < 900)  columns = 2;
      if (w < 600)  columns = 1;

      const gap   = 16.0;
      final cardW = (w - (columns - 1) * gap) / columns;

      return Wrap(
        spacing:    gap,
        runSpacing: gap,
        children: List.generate(8, (_) {
          return SizedBox(
            width:  cardW,
            height: _CourseTokens.courseCardHeight,
            child:  const _SkeletonCard(),
          );
        }),
      );
    },);
  }
}

class _NoResultsState extends StatelessWidget {
  final VoidCallback? onClear;
  const _NoResultsState({this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding:     const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: AppColors.border),
          boxShadow: [
            const BoxShadow(
                color:      Color(0x0D000000),
                blurRadius: 2,
                offset:     Offset(0, 1),),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.search_off_rounded,
              size: 34, color: AppColors.primary,),
          const SizedBox(height: 10),
          Text('No results match your filters',
              style: TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.w900,
                  color:      AppColors.textTitle,),
              textAlign: TextAlign.center,),
          const SizedBox(height: 8),
          Text(
              'Try clearing filters or searching with a different keyword.',
              style:     TextStyle(color: AppColors.textMuted),
              textAlign: TextAlign.center,),
          const SizedBox(height: 14),
          if (onClear != null)
            ElevatedButton.icon(
              onPressed: onClear,
              icon:  const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: const Text('Clear filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),),
              ),
            ),
        ],),
      ),
    );
  }
}

class _CoursesEmptyState extends StatelessWidget {
  final VoidCallback? onCreate;
  const _CoursesEmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(14),
            border:       Border.all(color: _CourseTokens.border),
            boxShadow: [
              const BoxShadow(
                  color:      Color(0x0D000000),
                  blurRadius: 2,
                  offset:     Offset(0, 1),),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width:  54,
              height: 54,
              decoration: BoxDecoration(
                color:        const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.folder_open_rounded,
                  color: _CourseTokens.blue, size: 28,),
            ),
            const SizedBox(height: 12),
            Text('No courses yet',
                style: TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.w900,
                    color:      _CourseTokens.textPrimary,),),
            const SizedBox(height: 6),
            Text(
                'Create your first course to start uploading materials, generating AI quizzes, and inviting students.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize:   12.8,
                    fontWeight: FontWeight.w600,
                    color:      _CourseTokens.textMuted,
                    height:     1.35,),),
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: onCreate,
                icon:  const Icon(Icons.add_rounded,
                    size: 18, color: Colors.white,),
                label: const Text('Create course',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color:      Colors.white,),),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _CourseTokens.blue,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),),
                ),
              ),
            ),
          ],),
        ),
      ),
    );
  }
}

// ==================== Skeleton Card ====================

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync:    this,
        duration: const Duration(milliseconds: 1100),)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final color = Color.lerp(
            AppColors.borderGray,
            AppColors.headerBg,
            _c.value,)!;

        return Container(
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(_CourseTokens.radiusCard),
            border:       Border.all(color: _CourseTokens.border),
          ),
          child: Column(children: [
            Container(
              height: _CourseTokens.heroHeight,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(_CourseTokens.radiusCard),),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 18,
                        width:  double.infinity,
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),),),
                    const SizedBox(height: 10),
                    Container(
                        height: 14,
                        width:  160,
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),),),
                    const SizedBox(height: 18),
                    Row(children: [
                      Container(
                          height: 12,
                          width:  90,
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),),),
                      const SizedBox(width: 12),
                      Container(
                          height: 12,
                          width:  90,
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),),),
                    ],),
                    const Spacer(),
                    Container(height: 1, color: _CourseTokens.divider),
                    const SizedBox(height: 12),
                    Container(
                        height: 12,
                        width:  140,
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),),),
                  ],
                ),
              ),
            ),
          ],),
        );
      },
    );
  }
}

// ==================== API Course Card ====================

class _ApiCourseCard extends StatefulWidget {
  final MyCourseItem course;
  final CourseUpdateAction? onUpdateCourse;
  final CourseArchiveAction? onArchiveCourse;
  final CourseDeleteAction? onDeleteCourse;

  const _ApiCourseCard({
    required this.course,
    this.onUpdateCourse,
    this.onArchiveCourse,
    this.onDeleteCourse,
  });

  @override
  State<_ApiCourseCard> createState() => _ApiCourseCardState();
}

class _ApiCourseCardState extends State<_ApiCourseCard> {
  bool hover = false;
  final GlobalKey _moreKey = GlobalKey();

  String _title(MyCourseItem c) =>
      c.title.trim().isEmpty ? 'Untitled course' : c.title.trim();

  String _code(MyCourseItem c) {
    final code = c.safeCourseCode.trim();
    return code.isNotEmpty ? code : 'COURSE-${c.id}';
  }

  _CourseStatus _status(MyCourseItem c) {
    switch (c.lifecycleStatus) {
      case CourseLifecycleStatus.draft:
        return _CourseStatus.draft;
      case CourseLifecycleStatus.archived:
        return _CourseStatus.archived;
      case CourseLifecycleStatus.published:
      case CourseLifecycleStatus.active:
        return _CourseStatus.active;
    }
  }

  String _meta(MyCourseItem c) {
    final parts = <String>[];
    if ((c.category ?? '').trim().isNotEmpty) {
      parts.add(c.category!.trim());
    }
    if (c.visibilityLevel.trim().isNotEmpty) {
      parts.add(c.visibility.label);
    }
    return parts.join(' • ');
  }

  int _students(MyCourseItem c) => c.enrollmentCount ?? 0;
  int _modules(MyCourseItem c)  => 0;

  Future<void> _showCourseMenuFromKey(
    BuildContext context,
    MyCourseItem c,
    GlobalKey anchorKey,
  ) async {
    final slug = buildCourseRouteSlug(c);

    final selected = await showFigmaUmMenu<String>(
      context: context,
      anchorKey: anchorKey,
      minWidth: 210,
      entries: const [
        FigmaUmMenuEntry.item(
          value: 'materials',
          label: 'View materials',
          icon: Icons.folder_open_rounded,
        ),
        FigmaUmMenuEntry.item(
          value: 'invite',
          label: 'Invite students',
          icon: Icons.person_add_alt_1_rounded,
        ),
        FigmaUmMenuEntry.item(
          value: 'edit',
          label: 'Edit course info',
          icon: Icons.edit_rounded,
        ),
        FigmaUmMenuEntry.item(
          value: 'archive',
          label: 'Archive course',
          icon: Icons.archive_rounded,
        ),
        FigmaUmMenuEntry.divider(),
        FigmaUmMenuEntry.item(
          value: 'delete',
          label: 'Delete course',
          icon: Icons.delete_outline_rounded,
        ),
      ],
    );

    if (!mounted || selected == null) return;

    switch (selected) {
      case 'materials':
        SelectedCourseCache.set(c);
        context.go(Routes.courseMaterials(slug));
        return;
      case 'invite':
        if (c.isPublic) {
          AppToast.warning(
            context,
            title: 'Invitations unavailable',
            message: 'This course is open for enrollment, so it does not use private invitations.',
          );
          return;
        }
        await showDialog<bool>(
          context: context,
          builder: (_) => InviteStudentsDialog(courseId: c.id),
        );
        return;
      case 'edit':
        await _editCourse(c);
        return;
      case 'archive':
        await _archiveCourse(c);
        return;
      case 'delete':
        await _deleteCourse(c);
        return;
    }
  }

  Future<void> _editCourse(MyCourseItem course) async {
    final action = widget.onUpdateCourse;
    if (action == null) {
      AppToast.warning(
        context,
        title: 'Unavailable',
        message: 'The current backend exposes create, list, materials, and invitations only. Course update is not available.',
      );
      return;
    }

    final payload = await showDialog<CourseUpdateRequest>(
      context: context,
      builder: (_) => _EditCourseDialog(course: course),
    );

    if (!mounted || payload == null || payload.isEmpty) return;

    try {
      final updated = await action(course, payload);
      SelectedCourseCache.set(updated);
      if (!mounted) return;
      AppToast.success(
        context,
        title: 'Course updated',
        message: 'The course information was saved.',
      );
    } catch (_) {
      if (!mounted) return;
      AppToast.error(
        context,
        title: 'Update failed',
        message: 'The course could not be updated.',
      );
    }
  }

  Future<void> _archiveCourse(MyCourseItem course) async {
    final action = widget.onArchiveCourse;
    if (action == null) {
      AppToast.warning(
        context,
        title: 'Unavailable',
        message: 'The current backend does not expose a course archive/update endpoint.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _CourseActionConfirmDialog(
        icon: Icons.archive_rounded,
        title: 'Archive course?',
        message:
            '“${course.safeTitle}” will be moved to archived courses. You can keep its existing content, but it will no longer appear as an active course.',
        confirmLabel: 'Archive course',
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      final updated = await action(course);
      SelectedCourseCache.set(updated);
      if (!mounted) return;
      AppToast.success(
        context,
        title: 'Course archived',
        message: 'The course was archived successfully.',
      );
    } catch (_) {
      if (!mounted) return;
      AppToast.error(
        context,
        title: 'Archive failed',
        message: 'The course could not be archived.',
      );
    }
  }

  Future<void> _deleteCourse(MyCourseItem course) async {
    final action = widget.onDeleteCourse;
    if (action == null) {
      AppToast.warning(
        context,
        title: 'Unavailable',
        message: 'The current backend does not expose a course delete endpoint.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _CourseActionConfirmDialog(
        icon: Icons.delete_outline_rounded,
        title: 'Delete course?',
        message:
            'This will permanently delete “${course.safeTitle}” and remove it from My Courses. This action cannot be undone.',
        confirmLabel: 'Delete course',
        destructive: true,
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      await action(course);
      if (!mounted) return;
      AppToast.success(
        context,
        title: 'Course deleted',
        message: 'The course was deleted successfully.',
      );
    } catch (_) {
      if (!mounted) return;
      AppToast.error(
        context,
        title: 'Delete failed',
        message: 'The course could not be deleted.',
      );
    }
  }

  @override
    Widget build(BuildContext context) {
    // HTML-matched card layout (hero gradient + code badge + status pill + stats + footer)
    final lifecycleStatus = widget.course.lifecycleStatus;
    final isActive = lifecycleStatus == CourseLifecycleStatus.active ||
        lifecycleStatus == CourseLifecycleStatus.published;
    final isDraft = lifecycleStatus == CourseLifecycleStatus.draft;
    final isArchived = lifecycleStatus == CourseLifecycleStatus.archived;
    final statusLabel = lifecycleStatus.label;
    final statusBg = isActive
        ? const Color(0xE616A34A)
        : (isDraft
            ? const Color(0xE5F59E0B)
            : const Color(0xBF64748B));
    final heroGradient = isDraft
        ? LinearGradient(colors: [AppColors.textTitle, const Color(0xFF1E293B)])
        : (isArchived
            ? LinearGradient(colors: [AppColors.textHint, AppColors.textGray500])
            : const LinearGradient(colors: [Color(0xFF134E4A), Color(0xFF0891B2)]));
    final enrollCount = widget.course.enrollmentCount ?? 0;
    final modulesCount = widget.course.moduleCount ?? 0;
    final code = (widget.course.courseCode?.isNotEmpty ?? false) ? widget.course.courseCode! : '—';
    final metaLeft = widget.course.category ?? 'General';
    final metaRight = widget.course.accessType.label;
    final meta = '$metaLeft • $metaRight';
  
  return MouseRegion(
    onEnter: (_) => setState(() => hover = true),
    onExit: (_) => setState(() => hover = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      transform: hover ? (Matrix4.identity()..translate(0.0, -1.0)) : Matrix4.identity(),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hover ? AppColors.badgeBlueBorder : AppColors.border,
          width: hover ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (hover)
            const BoxShadow(color: Color(0x14137FEC), blurRadius: 28, offset: Offset(0, 10))
          else
            const BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final slug = buildCourseRouteSlug(widget.course);
          SelectedCourseCache.set(widget.course);
          context.go(Routes.courseDetails(slug)); // ✅ navigate to course details
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero
              SizedBox(
                height: 140,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(gradient: heroGradient),
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0x80000000), Color(0x00000000)],
                            stops: [0.0, 0.6],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xE6FFFFFF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          code,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDraft ? Icons.edit_rounded : (isArchived ? Icons.inventory_2_outlined : Icons.check_rounded),
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.course.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: AppColors.textTitle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _CourseStat(icon: Icons.groups_rounded, label: '$enrollCount Students'),
                        const SizedBox(width: 14),
                        _CourseStat(icon: Icons.grid_view_rounded, label: '$modulesCount Modules'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(height: 1, color: AppColors.divider),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Avatar stack (mocked, but matches HTML look)
                        const _AvatarStack(),
                        const Spacer(),
                        Row(
                          children: [
                            _IconBtnSm(icon: Icons.schedule_rounded, onTap: () {}),
                            const SizedBox(width: 4),
                            _IconBtnSm(
                              key: _moreKey,
                              icon: Icons.more_horiz_rounded,
                              onTap: () => _showCourseMenuFromKey(context, widget.course, _moreKey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

}


class _EditCourseDialog extends StatefulWidget {
  final MyCourseItem course;

  const _EditCourseDialog({required this.course});

  @override
  State<_EditCourseDialog> createState() => _EditCourseDialogState();
}

class _EditCourseDialogState extends State<_EditCourseDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _categoryCtrl;

  late String _visibility;
  late String _status;
  bool _approvalRequired = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.course.safeTitle);
    _codeCtrl = TextEditingController(text: widget.course.courseCode ?? '');
    _categoryCtrl = TextEditingController(text: widget.course.category ?? '');
    _visibility = widget.course.visibility.backendValue;
    _status = widget.course.lifecycleStatus == CourseLifecycleStatus.active
        ? CourseLifecycleStatus.published.backendValue
        : widget.course.lifecycleStatus.backendValue;
    _approvalRequired = widget.course.isPrivate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _codeCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  bool get _isPublic => _visibility == CourseVisibility.public.backendValue;

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      AppToast.error(
        context,
        title: 'Validation error',
        message: 'Course title is required.',
      );
      return;
    }

    Navigator.of(context).pop(
      CourseUpdateRequest(
        title: title,
        courseCode: _codeCtrl.text.trim(),
        category: _categoryCtrl.text.trim(),
        isPublic: _isPublic,
        visibilityLevel: _visibility,
        requiresEnrollmentApproval: _approvalRequired,
        status: _status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 32,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 16, 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.edit_rounded,
                          color: AppColors.primary, size: 20,),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit course info',
                            style: TextStyle(
                              color: AppColors.textTitle,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Update the course name, code, visibility, and status.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.divider),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _EditCourseLabel('Course title'),
                      const SizedBox(height: 6),
                      _EditCourseTextField(
                        controller: _titleCtrl,
                        hint: 'Course title',
                        icon: Icons.school_outlined,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _EditCourseLabel('Course code'),
                                const SizedBox(height: 6),
                                _EditCourseTextField(
                                  controller: _codeCtrl,
                                  hint: 'Optional code',
                                  icon: Icons.tag_rounded,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _EditCourseLabel('Category'),
                                const SizedBox(height: 6),
                                _EditCourseTextField(
                                  controller: _categoryCtrl,
                                  hint: 'General',
                                  icon: Icons.category_outlined,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _EditCourseDropdown(
                              label: 'Visibility',
                              value: _visibility,
                              items: const [
                                'private',
                                'public',
                                'unlisted',
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _visibility = value;
                                  _approvalRequired = value != 'public';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _EditCourseDropdown(
                              label: 'Status',
                              value: _status,
                              items: const [
                                'draft',
                                'published',
                                'archived',
                              ],
                              onChanged: (value) =>
                                  setState(() => _status = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10,),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Require enrollment approval',
                                    style: TextStyle(
                                      color: AppColors.textTitle,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Useful for private or controlled courses.',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _approvalRequired,
                              onChanged: (value) => setState(
                                  () => _approvalRequired = value,),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Save changes'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditCourseLabel extends StatelessWidget {
  final String text;

  const _EditCourseLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.textTitle,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _EditCourseTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;

  const _EditCourseTextField({
    required this.controller,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppColors.muted),
        filled: true,
        fillColor: AppColors.surfaceBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      ),
    );
  }
}

class _EditCourseDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _EditCourseDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EditCourseLabel(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: AppColors.cardBg,
          iconEnabledColor: AppColors.muted,
          style: TextStyle(
            color: AppColors.textTitle,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item[0].toUpperCase() + item.substring(1)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ],
    );
  }
}

class _CourseActionConfirmDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  const _CourseActionConfirmDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? AppColors.dangerText : AppColors.primary;
    final accentBg = destructive ? AppColors.dangerBg : AppColors.primarySoft;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 32,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accentBg,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: accent, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: AppColors.textTitle,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                message,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: destructive
                        ? FilledButton.styleFrom(backgroundColor: accent)
                        : null,
                    child: Text(confirmLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CourseStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      width: 56,
      child: Stack(
        children: [
          _AvatarDot(left: 0,  bg: AppColors.border),
          _AvatarDot(left: 16, bg: AppColors.badgeBlueBg),
          const _AvatarDot(left: 32, bg: Color(0xFFE9FBF1)),
        ],
      ),
    );
  }
}

class _AvatarDot extends StatelessWidget {
  final double left;
  final Color bg;

  const _AvatarDot({required this.left, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(Icons.person, size: 14, color: AppColors.textMuted),
      ),
    );
  }
}

class _IconBtnSm extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _IconBtnSm({super.key, required this.icon, this.onTap});

  @override
  State<_IconBtnSm> createState() => _IconBtnSmState();
}

class _IconBtnSmState extends State<_IconBtnSm> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: hover ? AppColors.headerBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(widget.icon, size: 18, color: AppColors.muted),
        ),
      ),
    );
  }
}


// ==================== API Hero ====================

class _ApiHero extends StatelessWidget {
  final _CourseStatus status;
  final String code;
  final String imageUrl;

  const _ApiHero({
    required this.status,
    required this.code,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final statusLabel = status == _CourseStatus.active
        ? 'Active'
        : status == _CourseStatus.draft
            ? 'Draft'
            : 'Archived';

    final statusColor = status == _CourseStatus.active
        ? AppColors.successText
        : status == _CourseStatus.draft
            ? const Color(0xFFF59E0B)
            : AppColors.textMuted;

    return Stack(
      children: [
      if (imageUrl.isNotEmpty)
        Image.network(imageUrl,
            fit:             BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder:    (_, __, ___) =>
                Container(color: const Color(0xFFEFF2F6)),)
      else
        Container(color: const Color(0xFFEFF2F6)),

      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin:  Alignment.bottomCenter,
              end:    Alignment.topCenter,
              colors: [Color(0x99000000), Color(0x00000000)],
            ),
          ),
        ),
      ),

      // Code chip
      Positioned(
        right: 11.25, top: 7,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4.5,),
              color: Colors.white.withValues(alpha: 0.90),
              child: Text(code,
                  style: TextStyle(
                      fontFamily:  'Inter',
                      fontWeight:  FontWeight.w700,
                      fontSize:    12,
                      height:      1.33,
                      color:       _CourseTokens.textPrimary,),),
            ),
          ),
        ),
      

      // Status pill
      Positioned(
        left: 12, bottom: 12,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9999),
          child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4,),
              color: statusColor.withValues(alpha: 0.90),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  status == _CourseStatus.active
                      ? Icons.check_circle_rounded
                      : status == _CourseStatus.draft
                          ? Icons.edit_rounded
                          : Icons.archive_rounded,
                  size:  14,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(statusLabel,
                    style: const TextStyle(
                        fontFamily:  'Inter',
                        fontWeight:  FontWeight.w700,
                        fontSize:    12,
                        height:      1.33,
                        color:       Colors.white,),),
              ],),
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== API Body ====================

class _ApiBody extends StatelessWidget {
  final String title;
  final String meta;
  final int students;
  final int modules;
  final DateTime updatedAt;
  final VoidCallback onWorkTap;
  final VoidCallback onMoreTap;
  final GlobalKey moreKey;
  final bool showPeople;
  final String memberCountText;

  const _ApiBody({
    required this.title,
    required this.meta,
    required this.students,
    required this.modules,
    required this.updatedAt,
    required this.onWorkTap,
    required this.onMoreTap,
    required this.moreKey,
    required this.showPeople,
    required this.memberCountText,
  });

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              maxLines:  2,
              overflow:  TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily:  'Inter',
                  fontWeight:  FontWeight.w700,
                  fontSize:    18,
                  height:      1.2,
                  color:       _CourseTokens.textPrimary,),),
          const SizedBox(height: 4),
          Text(meta.isEmpty ? '—' : meta,
              maxLines:  1,
              overflow:  TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily:  'Inter',
                  fontWeight:  FontWeight.w400,
                  fontSize:    14,
                  color:       _CourseTokens.textMuted,),),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.people_outline,
                size: 18, color: _CourseTokens.textMuted,),
            const SizedBox(width: 6),
            Text('$students Students',
                style: TextStyle(
                    fontFamily:  'Inter',
                    fontWeight:  FontWeight.w400,
                    fontSize:    14,
                    color:       _CourseTokens.textMuted,),),
            const SizedBox(width: 14),
            Icon(Icons.menu_book_outlined,
                size: 18, color: _CourseTokens.textMuted,),
            const SizedBox(width: 6),
            Text('$modules Modules',
                style: TextStyle(
                    fontFamily:  'Inter',
                    fontWeight:  FontWeight.w400,
                    fontSize:    14,
                    color:       _CourseTokens.textMuted,),),
          ],),
          const Spacer(),
          Divider(
              height: 1, thickness: 1, color: _CourseTokens.divider,),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: Row(children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: showPeople
                      ? _PeopleFooter(memberCountText: memberCountText)
                      : _NoteFooter(
                          text: 'Updated ${_fmtDate(updatedAt)}',),
                ),
              ),
              _IconActionButton(
                  icon: Icons.work_outline_rounded, onTap: onWorkTap,),
              const SizedBox(width: 6),
              _IconActionButton(
                  key:  moreKey,
                  icon: Icons.more_vert_rounded,
                  onTap: onMoreTap,),
            ],),
          ),
        ],
      ),
    );
  }
}

// ==================== Footer Widgets ====================

class _PeopleFooter extends StatelessWidget {
  final String memberCountText;
  const _PeopleFooter({required this.memberCountText});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const _AvatarStackSmall(),
      if (memberCountText.trim().isNotEmpty) ...[
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 6,),
          decoration: BoxDecoration(
            color:        AppColors.headerBg,
            borderRadius: BorderRadius.circular(999),
            border:       Border.all(color: _CourseTokens.border),
          ),
          child: Text(memberCountText,
              style: TextStyle(
                  fontFamily:  'Inter',
                  fontWeight:  FontWeight.w600,
                  fontSize:    12,
                  color:       _CourseTokens.textMuted,),),
        ),
      ],
    ],);
  }
}

class _NoteFooter extends StatelessWidget {
  final String text;
  const _NoteFooter({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        maxLines:  1,
        overflow:  TextOverflow.ellipsis,
        style: TextStyle(
            fontFamily:  'Inter',
            fontWeight:  FontWeight.w500,
            fontSize:    12,
            color:       _CourseTokens.textMuted,),);
  }
}

class _AvatarStackSmall extends StatelessWidget {
  const _AvatarStackSmall();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28, width: 52,
      child: Stack(children: [
        _a(0,  AppColors.border),
        _a(16, AppColors.badgeBlueBg),
      ],),
    );
  }

  Widget _a(double left, Color bg) {
    return Positioned(
      left: left,
      child: Container(
        width:  28, height: 28,
        decoration: BoxDecoration(
          shape:  BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          color:  bg,
        ),
        child: Icon(Icons.person,
            size: 14, color: AppColors.textMuted,),
      ),
    );
  }
}

// ==================== Icon Action Button ====================

class _IconActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onTapDown;

  const _IconActionButton({
    super.key,
    required this.icon,
    this.onTap,
    this.onTapDown,
  });

  @override
  State<_IconActionButton> createState() => _IconActionButtonState();
}

class _IconActionButtonState extends State<_IconActionButton> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit:  (_) => setState(() => hover = false),
      child: InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
        onTap: widget.onTap,
        onTapDown: widget.onTapDown == null
            ? null
            : (d) => widget.onTapDown!(d.globalPosition),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width:  34, height: 34,
          decoration: BoxDecoration(
            color: hover
                ? AppColors.headerBg
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(widget.icon,
              size: 18, color: _CourseTokens.textMuted,),
        ),
      ),
    );
  }
}

// ==================== Card Shell ====================

class _CardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _CardShell({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color:        _CourseTokens.cardBg,
        borderRadius: BorderRadius.circular(_CourseTokens.radiusCard),
        border:       Border.all(color: _CourseTokens.border),
      ),
      child: child,
    );
  }
}

// ==================== Inline Error Banner ====================

class _InlineErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _InlineErrorBanner({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_rounded, color: Color(0xFFB45309)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  color:      Color(0xFF92400E),
                  fontWeight: FontWeight.w700,),
              maxLines:  2,
              overflow:  TextOverflow.ellipsis,),
        ),
        const SizedBox(width: 10),
        if (onRetry != null)
          TextButton.icon(
            onPressed: onRetry,
            icon:  const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF92400E),),
          ),
      ],),
    );
  }
}

// ==================== Menu Item Row ====================

class _MenuItemRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MenuItemRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: const Color(0xFF334155)),
      const SizedBox(width: 10),
      Text(text,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize:   13.5,
              color:      AppColors.textTitle,),),
    ],);
  }
}

// ==================== Legacy model classes (kept for compilation) ====================

enum _CourseStatus { active, draft, archived }

class _CourseModel {
  final String code;
  final _CourseStatus status;
  final String title;
  final String meta;
  final int students;
  final int modules;
  final String memberCountText;
  final String? note;
  final String coverUrl;

  const _CourseModel({
    required this.code,
    required this.status,
    required this.title,
    required this.meta,
    required this.students,
    required this.modules,
    required this.coverUrl,
    this.memberCountText = '',
    this.note,
  });
}
