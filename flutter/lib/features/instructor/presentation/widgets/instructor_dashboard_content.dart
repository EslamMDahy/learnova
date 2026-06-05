import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../shared/widgets/design_tokens.dart';
import '../../data/courses_models.dart';
import '../../data/courses_providers.dart';
import '../controllers/selected_course_provider.dart';
import '../course_route_identity.dart';

final instructorDashboardSnapshotProvider =
    FutureProvider<InstructorDashboardSnapshot>((ref) async {
  final response = await ref.read(coursesRepositoryProvider).myCourses(
        enrichMissingModuleCounts: true,
      );
  return InstructorDashboardSnapshot.fromCourses(response.items);
});

class InstructorDashboardSnapshot {
  final List<CourseDashboardItem> courses;
  final List<DashboardActivity> activities;
  final int totalCourses;
  final int activeCourses;
  final int archivedCourses;
  final int totalStudents;
  final int pendingInvites;
  final int totalModules;
  final int publicCourses;
  final int privateCourses;
  final int readinessPercent;

  const InstructorDashboardSnapshot({
    required this.courses,
    required this.activities,
    required this.totalCourses,
    required this.activeCourses,
    required this.archivedCourses,
    required this.totalStudents,
    required this.pendingInvites,
    required this.totalModules,
    required this.publicCourses,
    required this.privateCourses,
    required this.readinessPercent,
  });

  factory InstructorDashboardSnapshot.empty() {
    return const InstructorDashboardSnapshot(
      courses: [],
      activities: [],
      totalCourses: 0,
      activeCourses: 0,
      archivedCourses: 0,
      totalStudents: 0,
      pendingInvites: 0,
      totalModules: 0,
      publicCourses: 0,
      privateCourses: 0,
      readinessPercent: 0,
    );
  }

  factory InstructorDashboardSnapshot.fromCourses(List<MyCourseItem> items) {
    final courseItems = items.map(CourseDashboardItem.new).toList()
      ..sort((a, b) => b.course.updatedAt.compareTo(a.course.updatedAt));

    final totalCourses = courseItems.length;
    final totalReadiness = courseItems.fold<int>(
      0,
      (sum, item) => sum + item.readinessPercent,
    );

    final activities = courseItems
        .where((item) => _isMeaningfulDate(item.course.updatedAt))
        .map(
          (item) => DashboardActivity(
            title: item.course.safeTitle,
            description: item.activityDescription,
            date: item.course.updatedAt,
            icon: item.activityIcon,
            course: item.course,
            route: Routes.courseDetails(item.slug),
          ),
        )
        .take(8)
        .toList();

    return InstructorDashboardSnapshot(
      courses: courseItems,
      activities: activities,
      totalCourses: totalCourses,
      activeCourses: courseItems.where((item) => item.isActive).length,
      archivedCourses: courseItems.where((item) => item.isArchived).length,
      totalStudents: courseItems.fold<int>(
        0,
        (sum, item) => sum + item.studentCount,
      ),
      pendingInvites: courseItems.fold<int>(
        0,
        (sum, item) => sum + item.pendingInvites,
      ),
      totalModules: courseItems.fold<int>(
        0,
        (sum, item) => sum + item.moduleCount,
      ),
      publicCourses: courseItems.where((item) => item.course.isPublic).length,
      privateCourses: courseItems.where((item) => item.course.isPrivate).length,
      readinessPercent:
          totalCourses == 0 ? 0 : (totalReadiness / totalCourses).round(),
    );
  }

  List<CourseDashboardItem> get recentCourses => courses.take(5).toList();

  double get setupRatio => readinessPercent / 100;

  double get inviteRatio {
    final denominator = math.max(1, totalStudents + pendingInvites);
    return pendingInvites / denominator;
  }
}

class CourseDashboardItem {
  final MyCourseItem course;

  const CourseDashboardItem(this.course);

  String get slug => buildCourseRouteSlug(course);

  int get moduleCount => course.moduleCount ?? 0;
  int get studentCount => course.enrollmentCount ?? 0;
  int get pendingInvites => course.pendingInvites ?? 0;

  bool get isActive {
    final status = course.status.toLowerCase().trim();
    return status == 'active' || status == 'published' || status == 'draft';
  }

  bool get isArchived => course.status.toLowerCase().trim() == 'archived';

  int get readinessPercent {
    var score = 0;
    if (course.safeTitle.trim().isNotEmpty) score += 25;
    if (moduleCount > 0) score += 25;
    if (studentCount > 0 || pendingInvites > 0) score += 25;
    if (course.status.toLowerCase().trim() == 'published' || course.isPublic) {
      score += 25;
    }
    return score.clamp(0, 100).toInt();
  }

  String get statusLabel {
    final raw = course.status.trim();
    if (raw.isEmpty) return 'Draft';
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }

  IconData get activityIcon {
    if (moduleCount > 0) return Icons.view_module_outlined;
    if (pendingInvites > 0) return Icons.mail_outline_rounded;
    return Icons.school_outlined;
  }

  String get activityDescription {
    if (moduleCount > 0) {
      return '$moduleCount module${moduleCount == 1 ? '' : 's'} in workspace';
    }
    if (pendingInvites > 0) {
      return '$pendingInvites pending invite${pendingInvites == 1 ? '' : 's'}';
    }
    return 'Course profile updated';
  }
}

class DashboardActivity {
  final String title;
  final String description;
  final DateTime date;
  final IconData icon;
  final MyCourseItem? course;
  final String? route;

  const DashboardActivity({
    required this.title,
    required this.description,
    required this.date,
    required this.icon,
    this.course,
    this.route,
  });
}

class InstructorDashboardContent extends ConsumerWidget {
  final String userName;

  const InstructorDashboardContent({
    super.key,
    this.userName = 'Instructor',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(instructorDashboardSnapshotProvider);

    return snapshot.when(
      loading: () => const _DashboardLoadingView(),
      error: (error, _) => _DashboardErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(instructorDashboardSnapshotProvider),
      ),
      data: (data) => _DashboardBody(
        userName: userName,
        snapshot: data,
        onRefresh: () async {
          ref.invalidate(instructorDashboardSnapshotProvider);
          await ref.read(instructorDashboardSnapshotProvider.future);
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final String userName;
  final InstructorDashboardSnapshot snapshot;
  final Future<void> Function() onRefresh;

  const _DashboardBody({
    required this.userName,
    required this.snapshot,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 920;
        final cardsPerRow = width < 680 ? 2 : 4;

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: width < 600 ? 16 : 32,
              vertical: 28,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DashboardHeader(
                      userName: userName,
                      onRefresh: onRefresh,
                    ),
                    const SizedBox(height: 24),
                    _MetricGrid(
                      columns: cardsPerRow,
                      cards: [
                        _MetricCard(
                          label: 'Courses',
                          value: snapshot.totalCourses.toString(),
                          helper: '${snapshot.activeCourses} active',
                          icon: Icons.school_outlined,
                        ),
                        _MetricCard(
                          label: 'Modules',
                          value: snapshot.totalModules.toString(),
                          helper: 'Across all courses',
                          icon: Icons.view_module_outlined,
                        ),
                        _MetricCard(
                          label: 'Students',
                          value: snapshot.totalStudents.toString(),
                          helper: '${snapshot.pendingInvites} pending invites',
                          icon: Icons.groups_outlined,
                        ),
                        _MetricCard(
                          label: 'Readiness',
                          value: '${snapshot.readinessPercent}%',
                          helper: 'Average setup',
                          icon: Icons.verified_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (snapshot.totalCourses == 0)
                      const _EmptyDashboardState()
                    else if (compact)
                      Column(
                        children: [
                          _RecentActivityPanel(snapshot: snapshot),
                          const SizedBox(height: 18),
                          _RightColumn(snapshot: snapshot),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: _RecentActivityPanel(snapshot: snapshot),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 4,
                            child: _RightColumn(snapshot: snapshot),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String userName;
  final Future<void> Function() onRefresh;

  const _DashboardHeader({
    required this.userName,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Home',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.hint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded,
                      size: 14, color: AppColors.hint,),
                  const SizedBox(width: 6),
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Welcome back, $userName',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.textTitle,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Fast live summary from your courses workspace.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          children: [
            _DateBadge(label: _todayLabel()),
            _RefreshButton(onRefresh: onRefresh),
          ],
        ),
      ],
    );
  }
}

class _DateBadge extends StatelessWidget {
  final String label;
  const _DateBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return _SoftContainer(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 14, color: AppColors.textMuted,),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textTitle,
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _RefreshButton({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => onRefresh(),
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: const Text('Refresh'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 13),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final int columns;
  final List<Widget> cards;

  const _MetricGrid({required this.columns, required this.cards});

  @override
  Widget build(BuildContext context) {
    const gap = 14.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map((card) => SizedBox(width: cardWidth, child: card))
              .toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String helper;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _SoftContainer(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 17, color: AppColors.primary),
              ),
              const Spacer(),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.textTitle,
              height: 1,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            helper,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textHint,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityPanel extends StatelessWidget {
  final InstructorDashboardSnapshot snapshot;

  const _RecentActivityPanel({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Recent Activity',
          trailing: TextButton(
            onPressed: () => context.go(Routes.instructorCourses),
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('View courses'),
          ),
        ),
        const SizedBox(height: 10),
        _SoftContainer(
          padding: EdgeInsets.zero,
          child: snapshot.activities.isEmpty
              ? const _NoActivityState()
              : Column(
                  children: List.generate(snapshot.activities.length, (index) {
                    final item = snapshot.activities[index];
                    return _ActivityTile(
                      activity: item,
                      isFirst: index == 0,
                      isLast: index == snapshot.activities.length - 1,
                    );
                  }),
                ),
        ),
        const SizedBox(height: 18),
        _CourseProgressPanel(snapshot: snapshot),
      ],
    );
  }
}

class _ActivityTile extends StatefulWidget {
  final DashboardActivity activity;
  final bool isFirst;
  final bool isLast;

  const _ActivityTile({
    required this.activity,
    required this.isFirst,
    required this.isLast,
  });

  @override
  State<_ActivityTile> createState() => _ActivityTileState();
}

class _ActivityTileState extends State<_ActivityTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final route = widget.activity.route;

    return MouseRegion(
      cursor: route == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: route == null
            ? null
            : () {
                final course = widget.activity.course;
                if (course != null) SelectedCourseCache.set(course);
                context.go(route);
              },
        child: Column(
          children: [
            if (!widget.isFirst)
              Divider(height: 1, thickness: 1, color: AppColors.divider),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              decoration: BoxDecoration(
                color: _hovered ? AppColors.surfaceBg : Colors.transparent,
                borderRadius: BorderRadius.vertical(
                  top: widget.isFirst ? const Radius.circular(14) : Radius.zero,
                  bottom: widget.isLast ? const Radius.circular(14) : Radius.zero,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(widget.activity.icon,
                        size: 16, color: AppColors.primary,),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.activity.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textTitle,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.activity.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _timeAgo(widget.activity.date),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseProgressPanel extends StatelessWidget {
  final InstructorDashboardSnapshot snapshot;

  const _CourseProgressPanel({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final courses = snapshot.recentCourses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Course Readiness'),
        const SizedBox(height: 10),
        _SoftContainer(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  _ReadinessRing(percent: snapshot.readinessPercent),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${snapshot.readinessPercent}% average setup complete',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textTitle,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Calculated from course status, modules, students, and visibility.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (courses.isNotEmpty) ...[
                const SizedBox(height: 18),
                Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 12),
                ...courses.map((course) => _CourseProgressRow(metric: course)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CourseProgressRow extends StatelessWidget {
  final CourseDashboardItem metric;

  const _CourseProgressRow({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          SelectedCourseCache.set(metric.course);
          context.go(Routes.courseDetails(metric.slug));
        },
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.course.safeTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textTitle,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${metric.moduleCount} modules · ${metric.studentCount} students · ${metric.statusLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 120,
              child: _LinearProgress(value: metric.readinessPercent / 100),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 38,
              child: Text(
                '${metric.readinessPercent}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textTitle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RightColumn extends StatelessWidget {
  final InstructorDashboardSnapshot snapshot;

  const _RightColumn({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorkspaceHealthPanel(snapshot: snapshot),
        const SizedBox(height: 18),
        _QuickActionsPanel(snapshot: snapshot),
      ],
    );
  }
}

class _WorkspaceHealthPanel extends StatelessWidget {
  final InstructorDashboardSnapshot snapshot;

  const _WorkspaceHealthPanel({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Workspace Health'),
        const SizedBox(height: 10),
        _SoftContainer(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HealthRow(
                label: 'Average setup',
                value: snapshot.setupRatio,
                detail: '${snapshot.activeCourses}/${snapshot.totalCourses} active courses',
              ),
              const SizedBox(height: 16),
              _HealthRow(
                label: 'Pending invitations',
                value: snapshot.inviteRatio,
                detail: '${snapshot.pendingInvites} invites waiting',
              ),
              const SizedBox(height: 16),
              _SmallStatsGrid(
                items: [
                  _SmallStat('Public', snapshot.publicCourses),
                  _SmallStat('Private', snapshot.privateCourses),
                  _SmallStat('Archived', snapshot.archivedCourses),
                  _SmallStat('Modules', snapshot.totalModules),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final double value;
  final String detail;

  const _HealthRow({
    required this.label,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).clamp(0, 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textTitle,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.textTitle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        _LinearProgress(value: value),
        const SizedBox(height: 5),
        Text(
          detail,
          style: TextStyle(
            fontSize: 11.5,
            color: AppColors.textHint,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _QuickActionsPanel extends StatelessWidget {
  final InstructorDashboardSnapshot snapshot;

  const _QuickActionsPanel({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final firstCourse = snapshot.courses.isEmpty ? null : snapshot.courses.first;

    final actions = <_QuickAction>[
      const _QuickAction(
        icon: Icons.add_circle_outline_rounded,
        label: 'Create or manage courses',
        sub: 'Open course workspace',
        route: Routes.instructorCourses,
      ),
      _QuickAction(
        icon: Icons.upload_file_outlined,
        label: 'Upload material',
        sub: firstCourse == null ? 'Create a course first' : 'Open Materials tab',
        route: firstCourse == null
            ? Routes.instructorCourses
            : Routes.courseMaterials(firstCourse.slug),
        course: firstCourse?.course,
      ),
      _QuickAction(
        icon: Icons.fact_check_outlined,
        label: 'Review question bank',
        sub: firstCourse == null ? 'Create a course first' : 'Open Question Bank',
        route: firstCourse == null
            ? Routes.instructorCourses
            : Routes.courseQuestionBank(firstCourse.slug),
        course: firstCourse?.course,
      ),
      const _QuickAction(
        icon: Icons.assignment_outlined,
        label: 'Build quizzes',
        sub: 'Open quizzes workspace',
        route: Routes.instructorQuizzes,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Quick Actions'),
        const SizedBox(height: 10),
        _SoftContainer(
          padding: EdgeInsets.zero,
          child: Column(
            children: List.generate(actions.length, (index) {
              return _ActionTile(
                action: actions[index],
                isFirst: index == 0,
                isLast: index == actions.length - 1,
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String sub;
  final String route;
  final MyCourseItem? course;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.sub,
    required this.route,
    this.course,
  });
}

class _ActionTile extends StatefulWidget {
  final _QuickAction action;
  final bool isFirst;
  final bool isLast;

  const _ActionTile({
    required this.action,
    required this.isFirst,
    required this.isLast,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final course = widget.action.course;
          if (course != null) SelectedCourseCache.set(course);
          context.go(widget.action.route);
        },
        child: Column(
          children: [
            if (!widget.isFirst)
              Divider(height: 1, thickness: 1, color: AppColors.divider),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: _hovered ? AppColors.surfaceBg : Colors.transparent,
                borderRadius: BorderRadius.vertical(
                  top: widget.isFirst ? const Radius.circular(14) : Radius.zero,
                  bottom: widget.isLast ? const Radius.circular(14) : Radius.zero,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      widget.action.icon,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.action.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textTitle,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.action.sub,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: _hovered ? AppColors.primary : AppColors.textHint,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallStatsGrid extends StatelessWidget {
  final List<_SmallStat> items;

  const _SmallStatsGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.value.toString(),
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textTitle,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SmallStat {
  final String label;
  final int value;

  const _SmallStat(this.label, this.value);
}

class _SoftContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SoftContainer({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowThin,
            blurRadius: AppThemeRuntime.isDark ? 0 : 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textTitle,
              letterSpacing: -0.1,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _LinearProgress extends StatelessWidget {
  final double value;

  const _LinearProgress({required this.value});

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          Container(height: 7, color: AppColors.headerBg),
          FractionallySizedBox(
            widthFactor: clamped,
            child: Container(
              height: 7,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessRing extends StatelessWidget {
  final int percent;

  const _ReadinessRing({required this.percent});

  @override
  Widget build(BuildContext context) {
    final value = (percent / 100).clamp(0.0, 1.0).toDouble();
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 7,
              backgroundColor: AppColors.headerBg,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          Text(
            '$percent%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textTitle,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoActivityState extends StatelessWidget {
  const _NoActivityState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.timeline_outlined, size: 34, color: AppColors.textHint),
          const SizedBox(height: 10),
          Text(
            'No recent activity yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textTitle,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your updated courses will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDashboardState extends StatelessWidget {
  const _EmptyDashboardState();

  @override
  Widget build(BuildContext context) {
    return _SoftContainer(
      padding: const EdgeInsets.all(28),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.school_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No courses yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create your first course to start tracking your teaching workspace.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () => context.go(Routes.instructorCourses),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create Course'),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoadingView extends StatelessWidget {
  const _DashboardLoadingView();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Skeleton(width: 260, height: 28),
              const SizedBox(height: 10),
              const _Skeleton(width: 360, height: 14),
              const SizedBox(height: 26),
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 14.0;
                  final width = (constraints.maxWidth - gap * 3) / 4;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: List.generate(
                      4,
                      (_) => _Skeleton(width: width, height: 132),
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _Skeleton(width: double.infinity, height: 330),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    flex: 4,
                    child: _Skeleton(width: double.infinity, height: 330),
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

class _DashboardErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DashboardErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _SoftContainer(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 42, color: AppColors.dangerText,),
              const SizedBox(height: 14),
              Text(
                'Dashboard could not load',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textTitle,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double width;
  final double height;

  const _Skeleton({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}

bool _isMeaningfulDate(DateTime value) => value.year >= 2020;

String _todayLabel() {
  final now = DateTime.now();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[now.month - 1]} ${now.day}, ${now.year}';
}

String _timeAgo(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}
