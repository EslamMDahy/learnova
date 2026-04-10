import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../data/courses_models.dart';
import '../../controllers/course_details_controller.dart';
import '../course_outcomes_panel.dart';
import '../generate_questions_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Shared helpers — single source of truth, no more scattered top-level fns
// ─────────────────────────────────────────────────────────────────────────────
abstract final class _H {
  // Status
  static String statusLabel(String v) {
    switch (v.trim().toLowerCase()) {
      case 'published':
      case 'active':
        return 'Active';
      case 'draft':
        return 'Draft';
      case 'archived':
        return 'Archived';
      default:
        return titleCase(v.trim().isEmpty ? 'Unknown' : v.trim());
    }
  }

  static Color statusAccent(String v) {
    switch (v.trim().toLowerCase()) {
      case 'published':
      case 'active':
        return const Color(0xFF16A34A);
      case 'draft':
        return const Color(0xFFD97706);
      case 'archived':
        return const Color(0xFF64748B);
      default:
        return AppColors.primary;
    }
  }

  static Color statusSoft(String v) {
    switch (v.trim().toLowerCase()) {
      case 'published':
      case 'active':
        return const Color(0xFFDCFCE7);
      case 'draft':
        return const Color(0xFFFEF3C7);
      case 'archived':
        return const Color(0xFFE2E8F0);
      default:
        return const Color(0xFFEFF6FF);
    }
  }

  // Date
  static String formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  static String relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays <= 0) return 'today';
    if (diff.inDays == 1) return '1 day ago';
    if (diff.inDays < 30) return '${diff.inDays} days ago';
    final months = (diff.inDays / 30).floor();
    if (months <= 1) return '1 month ago';
    if (months < 12) return '$months months ago';
    final years = (months / 12).floor();
    return years <= 1 ? '1 year ago' : '$years years ago';
  }

  // Text
  static String titleCase(String v) {
    final s = v.trim();
    if (s.isEmpty) return v;
    return s[0].toUpperCase() + s.substring(1);
  }

  // Shared decoration reused by multiple cards
  static BoxDecoration cardDecoration({
    Color color = Colors.white,
    double radius = 16,
  }) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x09000000), blurRadius: 12, offset: Offset(0, 3),),
        ],
      );

  static BoxDecoration surfaceDecoration({double radius = 14}) =>
      BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CourseOverviewTab
// ─────────────────────────────────────────────────────────────────────────────
class CourseOverviewTab extends ConsumerWidget {
  final MyCourseItem course;
  const CourseOverviewTab({super.key, required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courseDetailsControllerProvider(course.id));
    final moduleCount = state.modules.length;
    final materialCount =
        state.materials.values.fold<int>(0, (s, l) => s + l.length);
    final questionCount = state.questions.length;
    final studentCount = course.enrollmentCount ?? 0;
    final publishedModules =
        state.modules.where((m) => m.isPublished).length;
    final draftModules =
        (moduleCount - publishedModules).clamp(0, moduleCount);
    final avgMaterialsPerModule =
        moduleCount == 0 ? 0.0 : materialCount / moduleCount;
    final hasContent =
        moduleCount > 0 || materialCount > 0 || questionCount > 0;

    // Setup progress (4 milestones)
    int completedSteps = 0;
    if (moduleCount > 0) completedSteps++;
    if (materialCount > 0) completedSteps++;
    if (questionCount > 0) completedSteps++;
    if (studentCount > 0) completedSteps++;
    final setupProgress = completedSteps / 4.0;

    final setupLabel = setupProgress >= 1
        ? 'Course ready to teach'
        : setupProgress >= 0.5
            ? 'Good progress'
            : 'Needs setup';

    return Container(
      color: AppColors.pageBg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1180;
          final isMedium = constraints.maxWidth >= 860;
          final hPad = isWide ? 24.0 : 16.0;

          return SingleChildScrollView(
            padding:
                EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero ──────────────────────────────────────────────────
                _OverviewHero(
                  course: course,
                  moduleCount: moduleCount,
                  materialCount: materialCount,
                  questionCount: questionCount,
                  studentCount: studentCount,
                  setupProgress: setupProgress,
                  setupLabel: setupLabel,
                ),
                const SizedBox(height: 12),

                // ── Smart next-action banner ──────────────────────────────
                _NextActionBanner(
                  moduleCount: moduleCount,
                  materialCount: materialCount,
                  questionCount: questionCount,
                  studentCount: studentCount,
                  draftModules: draftModules,
                  courseId: course.id,
                ),
                const SizedBox(height: 12),

                // ── Stat cards ────────────────────────────────────────────
                _ResponsiveStatsGrid(
                  isWide: isWide,
                  isMedium: isMedium,
                  children: [
                    _InsightStatCard(
                      title: 'Modules',
                      value: '$moduleCount',
                      subtitle: state.modulesLoading
                          ? 'Loading course structure...'
                          : publishedModules == 0 && moduleCount > 0
                              ? '$draftModules draft module${draftModules == 1 ? '' : 's'}'
                              : '$publishedModules published module${publishedModules == 1 ? '' : 's'}',
                      icon: Icons.view_module_rounded,
                      accent: AppColors.primary,
                      softColor: const Color(0xFFEFF6FF),
                      loading: state.modulesLoading,
                    ),
                    _InsightStatCard(
                      title: 'Materials',
                      value: '$materialCount',
                      subtitle: moduleCount == 0
                          ? 'Add modules first'
                          : '${avgMaterialsPerModule.toStringAsFixed(avgMaterialsPerModule == avgMaterialsPerModule.roundToDouble() ? 0 : 1)} avg per module',
                      icon: Icons.folder_rounded,
                      accent: const Color(0xFF7C3AED),
                      softColor: const Color(0xFFF3E8FF),
                    ),
                    _InsightStatCard(
                      title: 'Students',
                      value: '$studentCount',
                      subtitle: studentCount == 0
                          ? 'No learners enrolled yet'
                          : studentCount == 1
                              ? '1 learner enrolled'
                              : '$studentCount learners enrolled',
                      icon: Icons.people_alt_rounded,
                      accent: const Color(0xFF16A34A),
                      softColor: const Color(0xFFDCFCE7),
                    ),
                    _InsightStatCard(
                      title: 'Course status',
                      value: _H.statusLabel(course.status),
                      subtitle:
                          '${(setupProgress * 100).round()}% setup complete',
                      icon: Icons.verified_rounded,
                      accent: _H.statusAccent(course.status),
                      softColor: _H.statusSoft(course.status),
                      compactText: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Sections (wide / narrow) ──────────────────────────────
                if (isWide)
                  _WideLayout(
                    course: course,
                    moduleCount: moduleCount,
                    materialCount: materialCount,
                    questionCount: questionCount,
                    studentCount: studentCount,
                    publishedModules: publishedModules,
                    draftModules: draftModules,
                    setupProgress: setupProgress,
                    hasContent: hasContent,
                    modulesLoading: state.modulesLoading,
                    modules: state.modules,
                    materials: state.materials,
                  )
                else
                  _NarrowLayout(
                    course: course,
                    moduleCount: moduleCount,
                    materialCount: materialCount,
                    questionCount: questionCount,
                    studentCount: studentCount,
                    publishedModules: publishedModules,
                    draftModules: draftModules,
                    setupProgress: setupProgress,
                    hasContent: hasContent,
                    modulesLoading: state.modulesLoading,
                    modules: state.modules,
                    materials: state.materials,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Smart next-action banner
// ─────────────────────────────────────────────────────────────────────────────
class _NextActionBanner extends ConsumerWidget {
  final int moduleCount;
  final int materialCount;
  final int questionCount;
  final int studentCount;
  final int draftModules;
  final int courseId;

  const _NextActionBanner({
    required this.moduleCount,
    required this.materialCount,
    required this.questionCount,
    required this.studentCount,
    required this.draftModules,
    required this.courseId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (
      IconData icon,
      Color accent,
      Color soft,
      String title,
      String body,
      String? cta,
      VoidCallback? onCta,
    ) = _resolve(context, ref);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.45,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          if (cta != null && onCta != null) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onCta,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    cta,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  (
    IconData,
    Color,
    Color,
    String,
    String,
    String?,
    VoidCallback?,
  ) _resolve(BuildContext context, WidgetRef ref) {
    // Priority 1: no modules at all
    if (moduleCount == 0) {
      return (
        Icons.add_box_outlined,
        AppColors.primary,
        const Color(0xFFEFF6FF),
        'Start by creating your first module',
        'A module is the building block of your course. Add at least one to unlock materials, questions, and learner delivery.',
        'Create Module',
        () {},
      );
    }

    // Priority 2: modules exist but no materials
    if (materialCount == 0) {
      return (
        Icons.upload_file_outlined,
        const Color(0xFF7C3AED),
        const Color(0xFFF5F3FF),
        'Upload your first learning material',
        'You have $moduleCount module${moduleCount == 1 ? '' : 's'} ready. Add PDFs, slides, or documents to give your course substance.',
        'Upload',
        () {},
      );
    }

    // Priority 3: materials exist but no questions
    if (questionCount == 0) {
      return (
        Icons.auto_awesome_rounded,
        const Color(0xFF7C3AED),
        const Color(0xFFF5F3FF),
        'Your content is ready — build the question bank',
        'You have $materialCount material${materialCount == 1 ? '' : 's'} uploaded. Generate or create questions to activate assessments.',
        'Generate',
        () => showDialog(
          context: context,
          builder: (_) => GenerateQuestionsDialog(courseId: courseId),
        ),
      );
    }

    // Priority 4: draft modules lingering
    if (draftModules > 0) {
      return (
        Icons.edit_note_rounded,
        const Color(0xFFD97706),
        const Color(0xFFFFFBEB),
        '$draftModules module${draftModules == 1 ? '' : 's'} still in draft',
        'Review and publish your draft modules so enrolled students can access the full curriculum.',
        null,
        null,
      );
    }

    // Priority 5: no students yet
    if (studentCount == 0) {
      return (
        Icons.person_add_outlined,
        const Color(0xFF0EA5E9),
        const Color(0xFFEFF9FF),
        'Your course is ready — invite students',
        'Modules, materials, and questions are in place. Start enrolling learners to put the course to work.',
        'Invite',
        () {},
      );
    }

    // All good
    return (
      Icons.verified_rounded,
      const Color(0xFF16A34A),
      const Color(0xFFF0FDF4),
      'Course is live and running',
      '$studentCount student${studentCount == 1 ? '' : 's'} enrolled · $questionCount question${questionCount == 1 ? '' : 's'} in bank · All modules published.',
      null,
      null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Wide / narrow layout extracted to avoid duplicate inline trees
// ─────────────────────────────────────────────────────────────────────────────
class _WideLayout extends StatelessWidget {
  final MyCourseItem course;
  final int moduleCount, materialCount, questionCount, studentCount;
  final int publishedModules, draftModules;
  final double setupProgress;
  final bool hasContent, modulesLoading;
  final List<dynamic> modules;
  final Map<int, List<dynamic>> materials;

  const _WideLayout({
    required this.course,
    required this.moduleCount,
    required this.materialCount,
    required this.questionCount,
    required this.studentCount,
    required this.publishedModules,
    required this.draftModules,
    required this.setupProgress,
    required this.hasContent,
    required this.modulesLoading,
    required this.modules,
    required this.materials,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 7,
          child: Column(
            children: [
              _SectionCard(
                title: 'Setup progress',
                subtitle:
                    'Track what is ready and what still needs attention before the course is fully prepared.',
                icon: Icons.track_changes_rounded,
                iconColor: AppColors.primary,
                child: _SetupProgressSection(
                  moduleCount: moduleCount,
                  materialCount: materialCount,
                  questionCount: questionCount,
                  studentCount: studentCount,
                  setupProgress: setupProgress,
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Recent insights',
                subtitle:
                    'A quick operational snapshot of this course based on the content already created.',
                icon: Icons.insights_rounded,
                iconColor: const Color(0xFF7C3AED),
                child: _RecentInsightsSection(
                  course: course,
                  moduleCount: moduleCount,
                  materialCount: materialCount,
                  questionCount: questionCount,
                  studentCount: studentCount,
                  publishedModules: publishedModules,
                  draftModules: draftModules,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _SectionCard(
                title: 'Course structure',
                subtitle:
                    'Browse the modules currently shaping this course.',
                icon: Icons.account_tree_rounded,
                iconColor: const Color(0xFF0EA5E9),
                trailing: modulesLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                child: _CourseStructureSection(
                  modulesLoading: modulesLoading,
                  modules: modules,
                  materials: materials,
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Quick actions',
                subtitle:
                    'Jump into the most common instructor workflows without leaving the overview.',
                icon: Icons.bolt_rounded,
                iconColor: const Color(0xFFD97706),
                child: _QuickActions(
                  courseId: course.id,
                  hasContent: hasContent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  final MyCourseItem course;
  final int moduleCount, materialCount, questionCount, studentCount;
  final int publishedModules, draftModules;
  final double setupProgress;
  final bool hasContent, modulesLoading;
  final List<dynamic> modules;
  final Map<int, List<dynamic>> materials;

  const _NarrowLayout({
    required this.course,
    required this.moduleCount,
    required this.materialCount,
    required this.questionCount,
    required this.studentCount,
    required this.publishedModules,
    required this.draftModules,
    required this.setupProgress,
    required this.hasContent,
    required this.modulesLoading,
    required this.modules,
    required this.materials,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionCard(
          title: 'Setup progress',
          subtitle:
              'Track what is ready and what still needs attention before the course is fully prepared.',
          icon: Icons.track_changes_rounded,
          iconColor: AppColors.primary,
          child: _SetupProgressSection(
            moduleCount: moduleCount,
            materialCount: materialCount,
            questionCount: questionCount,
            studentCount: studentCount,
            setupProgress: setupProgress,
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Quick actions',
          subtitle:
              'Jump into the most common instructor workflows without leaving the overview.',
          icon: Icons.bolt_rounded,
          iconColor: const Color(0xFFD97706),
          child: _QuickActions(
            courseId: course.id,
            hasContent: hasContent,
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Course structure',
          subtitle: 'Browse the modules currently shaping this course.',
          icon: Icons.account_tree_rounded,
          iconColor: const Color(0xFF0EA5E9),
          trailing: modulesLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          child: _CourseStructureSection(
            modulesLoading: modulesLoading,
            modules: modules,
            materials: materials,
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Recent insights',
          subtitle:
              'A quick operational snapshot of this course based on the content already created.',
          icon: Icons.insights_rounded,
          iconColor: const Color(0xFF7C3AED),
          child: _RecentInsightsSection(
            course: course,
            moduleCount: moduleCount,
            materialCount: materialCount,
            questionCount: questionCount,
            studentCount: studentCount,
            publishedModules: publishedModules,
            draftModules: draftModules,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Hero
// ─────────────────────────────────────────────────────────────────────────────
class _OverviewHero extends StatelessWidget {
  final MyCourseItem course;
  final int moduleCount;
  final int materialCount;
  final int questionCount;
  final int studentCount;
  final double setupProgress;
  final String setupLabel;

  const _OverviewHero({
    required this.course,
    required this.moduleCount,
    required this.materialCount,
    required this.questionCount,
    required this.studentCount,
    required this.setupProgress,
    required this.setupLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF145CCB), Color(0xFF137FEC), Color(0xFF4CB5FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.22),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final stats = [
            _HeroStat(label: 'Modules', value: '$moduleCount'),
            _HeroStat(label: 'Materials', value: '$materialCount'),
            _HeroStat(label: 'Students', value: '$studentCount'),
            _HeroStat(label: 'Questions', value: '$questionCount'),
          ];

          final leftCol = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroBadge(
                      _H.statusLabel(course.status),
                      _H.statusSoft(course.status),
                      _H.statusAccent(course.status),
                    ),
                    _HeroBadge(course.safeCourseCode,
                        Colors.white.withOpacity(0.18), Colors.white,),
                    _HeroBadge(_H.titleCase(course.courseType),
                        Colors.white.withOpacity(0.18), Colors.white,),
                    _HeroBadge(
                        course.isPrivate ? 'Private' : 'Public',
                        Colors.white.withOpacity(0.18),
                        Colors.white,),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  course.safeTitle,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _buildSummary(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.86),
                    height: 1.55,
                  ),
                ),
                if ((course.category ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Category: ${course.category!.trim()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.72),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          );

          final progressPanel = SizedBox(
            width: compact ? double.infinity : 320,
            child: _HeroProgressPanel(
              setupProgress: setupProgress,
              setupLabel: setupLabel,
              createdAt: course.createdAt,
              updatedAt: course.updatedAt,
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leftCol,
                        const SizedBox(height: 18),
                        progressPanel,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leftCol,
                        const SizedBox(width: 20),
                        progressPanel,
                      ],
                    ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: stats,
              ),
            ],
          );
        },
      ),
    );
  }

  String _buildSummary() {
    final pieces = <String>[];
    pieces.add(moduleCount > 0
        ? '$moduleCount module${moduleCount == 1 ? '' : 's'}'
        : 'no modules yet',);
    if (materialCount > 0) {
      pieces.add('$materialCount material${materialCount == 1 ? '' : 's'}');
    }
    if (studentCount > 0) {
      pieces.add('$studentCount student${studentCount == 1 ? '' : 's'}');
    }
    if (questionCount > 0) {
      pieces.add(
          '$questionCount question${questionCount == 1 ? '' : 's'} in the current bank',);
    }
    return 'This ${_H.titleCase(course.courseType)} course currently has ${pieces.join(', ')}. '
        'Use the overview to monitor structure, readiness, and the next best instructor actions.';
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
                fontSize: 11.5,
                color: Colors.white.withOpacity(0.72),
                fontWeight: FontWeight.w600,),
          ),
        ],
      ),
    );
  }
}

class _HeroProgressPanel extends StatelessWidget {
  final double setupProgress;
  final String setupLabel;
  final DateTime createdAt;
  final DateTime updatedAt;

  const _HeroProgressPanel({
    required this.setupProgress,
    required this.setupLabel,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timeline_rounded,
                    color: Colors.white, size: 18,),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Course readiness',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,),
                    ),
                    Text(
                      setupLabel,
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withOpacity(0.74),),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(setupProgress * 100).round()}%',
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'completed',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.76),
                      fontWeight: FontWeight.w600,),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: setupProgress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.16),
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetaChip(
                  icon: Icons.calendar_today_rounded,
                  label: 'Created',
                  value: _H.formatDate(createdAt),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetaChip(
                  icon: Icons.update_rounded,
                  label: 'Updated',
                  value: _H.formatDate(updatedAt),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetaChip(
      {required this.icon, required this.label, required this.value,});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white.withOpacity(0.88)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.white.withOpacity(0.68),
                      fontWeight: FontWeight.w600,),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Stat cards grid
// ─────────────────────────────────────────────────────────────────────────────
class _ResponsiveStatsGrid extends StatelessWidget {
  final bool isWide;
  final bool isMedium;
  final List<Widget> children;

  const _ResponsiveStatsGrid({
    required this.isWide,
    required this.isMedium,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            Expanded(child: children[i]),
            if (i != children.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    }
    if (isMedium) {
      return Column(
        children: [
          Row(children: [
            Expanded(child: children[0]),
            const SizedBox(width: 12),
            Expanded(child: children[1]),
          ],),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: children[2]),
            const SizedBox(width: 12),
            Expanded(child: children[3]),
          ],),
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _InsightStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color softColor;
  final bool loading;
  final bool compactText;

  const _InsightStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.softColor,
    this.loading = false,
    this.compactText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _H.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: softColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 16),
          loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: compactText ? 21 : 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTitle,
                    height: 1,
                  ),
                ),
          const SizedBox(height: 6),
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTitle,),),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  height: 1.45,),),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section card
// ─────────────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _H.cardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textTitle,),),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                              height: 1.4,),),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Setup progress section
// ─────────────────────────────────────────────────────────────────────────────
class _SetupProgressSection extends StatelessWidget {
  final int moduleCount;
  final int materialCount;
  final int questionCount;
  final int studentCount;
  final double setupProgress;

  const _SetupProgressSection({
    required this.moduleCount,
    required this.materialCount,
    required this.questionCount,
    required this.studentCount,
    required this.setupProgress,
  });

  @override
  Widget build(BuildContext context) {
    final steps = [
      _SetupStep(
        title: 'Create modules',
        description: 'Organize the course into clear learning units.',
        done: moduleCount > 0,
        icon: Icons.view_module_rounded,
        hint: moduleCount > 0 ? '$moduleCount created' : 'Still missing',
      ),
      _SetupStep(
        title: 'Add materials',
        description: 'Upload PDFs, slides, docs, or lecture assets.',
        done: materialCount > 0,
        icon: Icons.folder_rounded,
        hint: materialCount > 0 ? '$materialCount uploaded' : 'Still missing',
      ),
      _SetupStep(
        title: 'Build question bank',
        description: 'Create or generate questions linked to topics.',
        done: questionCount > 0,
        icon: Icons.quiz_rounded,
        hint: questionCount > 0 ? '$questionCount ready' : 'Still missing',
      ),
      _SetupStep(
        title: 'Invite students',
        description: 'Open enrollment or invite a cohort to start learning.',
        done: studentCount > 0,
        icon: Icons.people_rounded,
        hint: studentCount > 0 ? '$studentCount enrolled' : 'Still missing',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: setupProgress,
                  minHeight: 8,
                  backgroundColor: AppColors.pageBg,
                  color: setupProgress == 1
                      ? const Color(0xFF16A34A)
                      : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(setupProgress * 100).round()}%',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textTitle,),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _H.surfaceDecoration(),
          child: Column(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                _SetupProgressTile(step: steps[i]),
                if (i != steps.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SetupStep {
  final String title;
  final String description;
  final bool done;
  final IconData icon;
  final String hint;

  const _SetupStep({
    required this.title,
    required this.description,
    required this.done,
    required this.icon,
    required this.hint,
  });
}

class _SetupProgressTile extends StatelessWidget {
  final _SetupStep step;
  const _SetupProgressTile({required this.step});

  static const _doneColor = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: step.done ? const Color(0xFFDCFCE7) : AppColors.pageBg,
            shape: BoxShape.circle,
            border: Border.all(
                color: step.done ? _doneColor : AppColors.border,),
          ),
          child: Icon(
            step.done ? Icons.check_rounded : step.icon,
            size: 15,
            color: step.done ? _doneColor : AppColors.textHint,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTitle,
                        decoration: step.done
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: AppColors.textHint,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3,),
                    decoration: BoxDecoration(
                      color: step.done
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      step.hint,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: step.done ? _doneColor : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                step.description,
                style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                    height: 1.4,),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Course structure section
// ─────────────────────────────────────────────────────────────────────────────
class _CourseStructureSection extends StatelessWidget {
  final bool modulesLoading;
  final List<dynamic> modules;
  final Map<int, List<dynamic>> materials;

  const _CourseStructureSection({
    required this.modulesLoading,
    required this.modules,
    required this.materials,
  });

  @override
  Widget build(BuildContext context) {
    if (modulesLoading && modules.isEmpty) {
      return const _SectionPlaceholder(
          message: 'Loading modules and materials...',);
    }
    if (modules.isEmpty) {
      return const _FriendlyEmptyState(
        icon: Icons.view_module_rounded,
        title: 'No modules yet',
        message:
            'Once you add modules, the course structure will appear here with file counts and publish status.',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < modules.length; i++) ...[
          _ModuleTile(
            title: modules[i].title as String,
            materialCount: materials[modules[i].id]?.length ?? 0,
            isPublished: modules[i].isPublished as bool,
            orderIndex: (modules[i].orderIndex as int?) ?? i,
          ),
          if (i != modules.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Recent insights section
// ─────────────────────────────────────────────────────────────────────────────
class _RecentInsightsSection extends StatelessWidget {
  final MyCourseItem course;
  final int moduleCount, materialCount, questionCount, studentCount;
  final int publishedModules, draftModules;

  const _RecentInsightsSection({
    required this.course,
    required this.moduleCount,
    required this.materialCount,
    required this.questionCount,
    required this.studentCount,
    required this.publishedModules,
    required this.draftModules,
  });

  @override
  Widget build(BuildContext context) {
    final insights = _buildInsights();
    return Column(
      children: [
        for (var i = 0; i < insights.length; i++) ...[
          _InsightRow(
            icon: insights[i].icon,
            color: insights[i].color,
            title: insights[i].title,
            description: insights[i].description,
          ),
          if (i != insights.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  List<({IconData icon, Color color, String title, String description})>
      _buildInsights() {
    final list = <({IconData icon, Color color, String title, String description})>[];

    list.add((
      icon: Icons.schedule_rounded,
      color: const Color(0xFF0EA5E9),
      title: 'Last updated ${_H.relativeDate(course.updatedAt)}',
      description:
          'Your course shell was created on ${_H.formatDate(course.createdAt)} and is being actively maintained.',
    ),);

    if (moduleCount == 0) {
      list.add((
        icon: Icons.lightbulb_outline_rounded,
        color: const Color(0xFFF59E0B),
        title: 'Start by building the course structure',
        description:
            'Create your first module to unlock materials, topics, and a richer course overview.',
      ),);
    } else if (draftModules > 0) {
      list.add((
        icon: Icons.edit_note_rounded,
        color: const Color(0xFFF59E0B),
        title: '$draftModules module${draftModules == 1 ? '' : 's'} still in draft',
        description:
            'Review unpublished modules before learners access the full curriculum.',
      ),);
    } else {
      list.add((
        icon: Icons.verified_rounded,
        color: const Color(0xFF16A34A),
        title: 'All modules are published',
        description:
            'Your instructional structure is visible and ready for enrolled learners.',
      ),);
    }

    if (materialCount == 0) {
      list.add((
        icon: Icons.folder_off_rounded,
        color: const Color(0xFF7C3AED),
        title: 'No learning materials uploaded yet',
        description:
            'Add PDFs, slides, or videos to give the course substance and support AI-assisted workflows.',
      ),);
    } else if (questionCount == 0) {
      list.add((
        icon: Icons.quiz_outlined,
        color: const Color(0xFFEA580C),
        title: 'Materials are ready for assessment design',
        description:
            'You have uploaded content. Next, create or generate questions to activate the question bank.',
      ),);
    } else {
      list.add((
        icon: Icons.auto_graph_rounded,
        color: const Color(0xFFEA580C),
        title: '$questionCount question${questionCount == 1 ? '' : 's'} prepared',
        description:
            'Your question bank has started taking shape and can support upcoming quizzes or exams.',
      ),);
    }

    if (studentCount == 0) {
      list.add((
        icon: Icons.people_outline_rounded,
        color: const Color(0xFF16A34A),
        title: 'No students enrolled yet',
        description:
            'Invite learners once the course content and question bank are ready for delivery.',
      ),);
    } else {
      list.add((
        icon: Icons.groups_rounded,
        color: const Color(0xFF16A34A),
        title: '$studentCount student${studentCount == 1 ? '' : 's'} enrolled',
        description:
            'Learner reach has started. Keep refining materials and assessments to support engagement.',
      ),);
    }

    return list;
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _InsightRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _H.surfaceDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTitle,),),
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                        height: 1.45,),),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Module tile
// ─────────────────────────────────────────────────────────────────────────────
class _ModuleTile extends StatelessWidget {
  final String title;
  final int materialCount;
  final bool isPublished;
  final int orderIndex;

  const _ModuleTile({
    required this.title,
    required this.materialCount,
    required this.isPublished,
    required this.orderIndex,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        isPublished ? AppColors.primary : const Color(0xFFD97706);
    final chipBg =
        isPublished ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7);
    final chipFg =
        isPublished ? const Color(0xFF16A34A) : const Color(0xFFD97706);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _H.surfaceDecoration(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.folder_rounded, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTitle,),
                ),
                const SizedBox(height: 4),
                Text(
                  'Module ${orderIndex + 1} · $materialCount file${materialCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textMuted,),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isPublished ? 'Published' : 'Draft',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: chipFg,),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Quick actions
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActions extends ConsumerWidget {
  final int courseId;
  final bool hasContent;

  const _QuickActions({required this.courseId, required this.hasContent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courseDetailsControllerProvider(courseId));
    final materialCount =
        state.materials.values.fold<int>(0, (sum, list) => sum + list.length);
    final canGenerate = materialCount > 0;

    final actions = [
      (
        Icons.add_box_outlined,
        AppColors.primary,
        const Color(0xFFEFF6FF),
        'Create Module',
        'Add a new content module',
        () {},
        true,
      ),
      (
        Icons.upload_file_outlined,
        const Color(0xFF9333EA),
        const Color(0xFFF3E8FF),
        'Upload Material',
        'Add videos, PDFs, or docs',
        () {},
        true,
      ),
      (
        Icons.flag_outlined,
        const Color(0xFF16A34A),
        const Color(0xFFDCFCE7),
        'Learning Outcomes',
        'Manage course learning goals',
        () => showCourseOutcomesDialog(context, ref, courseId),
        true,
      ),
      (
        Icons.auto_awesome_rounded,
        const Color(0xFF7C3AED),
        const Color(0xFFF3E8FF),
        'Generate Questions',
        canGenerate
            ? 'Select mixed course content scope'
            : 'Add materials before generating questions',
        () {
          if (!canGenerate) return;
          showDialog(
            context: context,
            builder: (_) => GenerateQuestionsDialog(courseId: courseId),
          );
        },
        canGenerate,
      ),
      (
        Icons.quiz_outlined,
        const Color(0xFFEA580C),
        const Color(0xFFFFEDD5),
        'Add Question',
        'Grow your question bank',
        () {},
        true,
      ),
      (
        Icons.person_add_outlined,
        const Color(0xFF0EA5E9),
        const Color(0xFFE0F2FE),
        'Invite Students',
        'Send course invitations',
        () {},
        true,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasContent)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: Color(0xFFD97706),),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This course is still empty. Start with modules and materials so the overview can surface richer insights.',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                        height: 1.45,),
                  ),
                ),
              ],
            ),
          ),
        ...List.generate(actions.length, (i) {
          final a = actions[i];
          final enabled = a.$7;
          return Padding(
            padding:
                EdgeInsets.only(bottom: i == actions.length - 1 ? 0 : 8),
            child: Opacity(
              opacity: enabled ? 1 : 0.58,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: enabled ? a.$6 : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11,),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFFAFBFC),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: a.$3,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(a.$1, size: 17, color: a.$2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.$4,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textTitle,),),
                              const SizedBox(height: 2),
                              Text(a.$5,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,),),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: enabled
                              ? AppColors.textHint
                              : AppColors.border,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────
class _FriendlyEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _FriendlyEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _H.surfaceDecoration(),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTitle,),),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11.5, color: AppColors.textMuted, height: 1.5,),
          ),
        ],
      ),
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  final String message;
  const _SectionPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(message,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textMuted,),),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _HeroBadge(this.label, this.background, this.foreground);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: foreground,),
      ),
    );
  }
}
