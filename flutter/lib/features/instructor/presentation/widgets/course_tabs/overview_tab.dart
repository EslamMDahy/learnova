import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/routing/routes.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../data/courses_models.dart';
import '../../../data/materials_models.dart';
import '../../../data/modules_models.dart';
import '../../controllers/course_details_controller.dart';
import '../../controllers/selected_course_provider.dart';
import '../../course_route_identity.dart';
import '../generate_questions_dialog.dart';

abstract final class _H {
  static String titleCase(String value) {
    final s = value.trim();
    if (s.isEmpty) return value;
    return s[0].toUpperCase() + s.substring(1);
  }

  static String statusLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'active':
      case 'published':
        return 'Active';
      case 'draft':
        return 'Draft';
      case 'archived':
        return 'Archived';
      default:
        return titleCase(value.trim().isEmpty ? 'Unknown' : value.trim());
    }
  }

  static Color statusColor(String value) {
    switch (value.trim().toLowerCase()) {
      case 'active':
      case 'published':
        return AppColors.successText;
      case 'draft':
        return const Color(0xFFD97706);
      case 'archived':
        return AppColors.textMuted;
      default:
        return AppColors.primary;
    }
  }

  static Color statusBg(String value) {
    switch (value.trim().toLowerCase()) {
      case 'active':
      case 'published':
        return AppColors.successBg;
      case 'draft':
        return AppThemeRuntime.isDark
            ? const Color(0xFF451A03)
            : const Color(0xFFFFF7ED);
      case 'archived':
        return AppColors.surfaceBg;
      default:
        return AppColors.primarySoft;
    }
  }

  static String date(DateTime value) {
    if (value.millisecondsSinceEpoch == 0) return 'Not available';
    return '${value.day}/${value.month}/${value.year}';
  }

  static String since(DateTime value) {
    if (value.millisecondsSinceEpoch == 0) return 'No date';
    final diff = DateTime.now().difference(value);
    if (diff.inDays <= 0) return 'Updated today';
    if (diff.inDays == 1) return 'Updated yesterday';
    if (diff.inDays < 30) return 'Updated ${diff.inDays} days ago';
    final months = (diff.inDays / 30).floor();
    if (months <= 1) return 'Updated 1 month ago';
    if (months < 12) return 'Updated $months months ago';
    final years = (months / 12).floor();
    return years <= 1 ? 'Updated 1 year ago' : 'Updated $years years ago';
  }

  static BoxDecoration cardDecoration({Color? color, double radius = 18}) {
    return BoxDecoration(
      color: color ?? AppColors.cardBg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowThin,
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static void openTab(BuildContext context, MyCourseItem course, String route) {
    SelectedCourseCache.set(course);
    context.go(route);
  }
}

class CourseOverviewTab extends ConsumerWidget {
  final MyCourseItem course;

  const CourseOverviewTab({super.key, required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courseDetailsControllerProvider(course.id));
    final modules = [...state.modules]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final moduleCount = modules.isNotEmpty ? modules.length : (course.moduleCount ?? 0);
    final materialsByModule = state.materials;
    final materialCount = materialsByModule.values.fold<int>(0, (sum, list) => sum + list.length);
    final questionCount = state.questions.length;
    final studentCount = course.enrollmentCount ?? 0;
    final publishedModules = modules.where((m) => m.isPublished).length;
    final draftModules = (moduleCount - publishedModules).clamp(0, moduleCount).toInt();
    final readiness = _readiness(
      moduleCount: moduleCount,
      materialCount: materialCount,
      questionCount: questionCount,
      studentCount: studentCount,
    );
    final slug = buildCourseRouteSlug(course);

    return Container(
      color: AppColors.pageBg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1080;
          final medium = constraints.maxWidth >= 760;
          final horizontal = wide ? 24.0 : 16.0;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OverviewHeader(
                  course: course,
                  readiness: readiness,
                  moduleCount: moduleCount,
                  materialCount: materialCount,
                  questionCount: questionCount,
                  studentCount: studentCount,
                ),
                const SizedBox(height: 14),
                _SignalGrid(
                  medium: medium,
                  signals: [
                    _Signal(
                      icon: Icons.account_tree_rounded,
                      title: 'Structure',
                      value: '$moduleCount modules',
                      note: materialCount == 0
                          ? 'No materials loaded yet'
                          : '$materialCount learning files attached',
                      accent: AppColors.primary,
                    ),
                    _Signal(
                      icon: Icons.fact_check_outlined,
                      title: 'Assessment',
                      value: questionCount == 0 ? 'Not started' : '$questionCount questions',
                      note: materialCount == 0
                          ? 'Upload content before question design'
                          : questionCount == 0
                              ? 'Ready to generate or add questions'
                              : 'Question bank has active content',
                      accent: const Color(0xFF7C3AED),
                    ),
                    _Signal(
                      icon: Icons.groups_2_outlined,
                      title: 'Delivery',
                      value: studentCount == 0 ? 'No students' : '$studentCount students',
                      note: '${_H.statusLabel(course.status)} · ${course.isPrivate ? 'Private' : 'Public'}',
                      accent: AppColors.successText,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _CourseMapCard(
                          modules: modules,
                          materialsByModule: materialsByModule,
                          loading: state.modulesLoading,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _NextMoveCard(
                              course: course,
                              slug: slug,
                              moduleCount: moduleCount,
                              materialCount: materialCount,
                              questionCount: questionCount,
                              studentCount: studentCount,
                            ),
                            const SizedBox(height: 14),
                            _CompactCourseFacts(
                              course: course,
                              readiness: readiness,
                              publishedModules: publishedModules,
                              draftModules: draftModules,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _NextMoveCard(
                        course: course,
                        slug: slug,
                        moduleCount: moduleCount,
                        materialCount: materialCount,
                        questionCount: questionCount,
                        studentCount: studentCount,
                      ),
                      const SizedBox(height: 14),
                      _CourseMapCard(
                        modules: modules,
                        materialsByModule: materialsByModule,
                        loading: state.modulesLoading,
                      ),
                      const SizedBox(height: 14),
                      _CompactCourseFacts(
                        course: course,
                        readiness: readiness,
                        publishedModules: publishedModules,
                        draftModules: draftModules,
                      ),
                    ],
                  ),
                const SizedBox(height: 14),
                _UsefulShortcuts(
                  course: course,
                  slug: slug,
                  canGenerate: materialCount > 0,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static double _readiness({
    required int moduleCount,
    required int materialCount,
    required int questionCount,
    required int studentCount,
  }) {
    var score = 0.0;
    if (moduleCount > 0) score += 0.32;
    if (materialCount > 0) score += 0.30;
    if (questionCount > 0) score += 0.23;
    if (studentCount > 0) score += 0.15;
    return score.clamp(0.0, 1.0).toDouble();
  }
}

class _OverviewHeader extends StatelessWidget {
  final MyCourseItem course;
  final double readiness;
  final int moduleCount;
  final int materialCount;
  final int questionCount;
  final int studentCount;

  const _OverviewHeader({
    required this.course,
    required this.readiness,
    required this.moduleCount,
    required this.materialCount,
    required this.questionCount,
    required this.studentCount,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 760;
    final readinessPct = (readiness * 100).round();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          end: Alignment.centerRight,
          colors: [
            Color(0xFF1D4ED8),
            Color(0xFF2563EB),
            Color(0xFF38BDF8),
          ],
        ),
        border: Border.all(color: const Color(0x332563EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x262563EB),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderTitle(course: course, onGradient: true),
                const SizedBox(height: 18),
                _ReadinessDial(readiness: readiness, readinessPct: readinessPct, onGradient: true),
              ],
            )
          : Row(
              children: [
                Expanded(child: _HeaderTitle(course: course, onGradient: true)),
                const SizedBox(width: 24),
                _ReadinessDial(readiness: readiness, readinessPct: readinessPct, onGradient: true),
              ],
            ),
    );
  }
}

class _HeaderTitle extends StatelessWidget {
  final MyCourseItem course;
  final bool onGradient;

  const _HeaderTitle({required this.course, this.onGradient = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(
              label: _H.statusLabel(course.status),
              background: _H.statusBg(course.status),
              foreground: _H.statusColor(course.status),
            ),
            _Chip(
              label: course.safeCourseCode,
              background: onGradient ? Colors.white.withOpacity(0.16) : AppColors.primarySoft,
              foreground: onGradient ? Colors.white : AppColors.primary,
            ),
            _Chip(
              label: course.isPrivate ? 'Private' : 'Public',
              background: onGradient ? Colors.white.withOpacity(0.14) : AppColors.surfaceBg,
              foreground: onGradient ? Colors.white.withOpacity(0.92) : AppColors.textMuted,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          course.safeTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: MediaQuery.of(context).size.width < 760 ? 24 : 30,
            fontWeight: FontWeight.w800,
            height: 1.12,
            letterSpacing: -0.5,
            color: onGradient ? Colors.white : AppColors.textTitle,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _summary(course),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            height: 1.55,
            color: onGradient ? Colors.white.withOpacity(0.82) : AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  String _summary(MyCourseItem course) {
    final type = _H.titleCase(course.courseType);
    final category = (course.category ?? '').trim();
    final categoryText = category.isEmpty ? 'general workspace' : category;
    return '$type course · $categoryText · ${_H.since(course.updatedAt)}';
  }
}

class _ReadinessDial extends StatelessWidget {
  final double readiness;
  final int readinessPct;
  final bool onGradient;

  const _ReadinessDial({
    required this.readiness,
    required this.readinessPct,
    this.onGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: onGradient ? Colors.white.withOpacity(0.14) : AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: onGradient ? Colors.white.withOpacity(0.26) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: readiness,
                  strokeWidth: 7,
                  backgroundColor: onGradient ? Colors.white.withOpacity(0.28) : AppColors.border,
                  color: onGradient ? Colors.white : AppColors.primary,
                ),
                Text(
                  '$readinessPct%',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: onGradient ? Colors.white : AppColors.textTitle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label(readinessPct),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: onGradient ? Colors.white : AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Readiness score',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    color: onGradient ? Colors.white.withOpacity(0.72) : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _label(int value) {
    if (value >= 85) return 'Ready to deliver';
    if (value >= 55) return 'Almost ready';
    if (value >= 25) return 'Building phase';
    return 'Needs setup';
  }
}

class _Signal {
  final IconData icon;
  final String title;
  final String value;
  final String note;
  final Color accent;

  const _Signal({
    required this.icon,
    required this.title,
    required this.value,
    required this.note,
    required this.accent,
  });
}

class _SignalGrid extends StatelessWidget {
  final bool medium;
  final List<_Signal> signals;

  const _SignalGrid({required this.medium, required this.signals});

  @override
  Widget build(BuildContext context) {
    if (medium) {
      return Row(
        children: [
          for (var i = 0; i < signals.length; i++) ...[
            Expanded(child: _SignalCard(signal: signals[i])),
            if (i != signals.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < signals.length; i++) ...[
          _SignalCard(signal: signals[i]),
          if (i != signals.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SignalCard extends StatelessWidget {
  final _Signal signal;

  const _SignalCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _H.cardDecoration(radius: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: signal.accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Icon(signal.icon, size: 19, color: signal.accent),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signal.title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  signal.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  signal.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextMoveCard extends StatelessWidget {
  final MyCourseItem course;
  final String slug;
  final int moduleCount;
  final int materialCount;
  final int questionCount;
  final int studentCount;

  const _NextMoveCard({
    required this.course,
    required this.slug,
    required this.moduleCount,
    required this.materialCount,
    required this.questionCount,
    required this.studentCount,
  });

  @override
  Widget build(BuildContext context) {
    final move = _resolveMove(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowThin,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: move.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(move.icon, color: move.accent, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next best move',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      move.title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textTitle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            move.body,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              height: 1.55,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: _PrimaryActionButton(
              label: move.label,
              onTap: move.onTap,
            ),
          ),
        ],
      ),
    );
  }

  _Move _resolveMove(BuildContext context) {
    if (moduleCount == 0) {
      return _Move(
        icon: Icons.add_box_outlined,
        accent: AppColors.primary,
        title: 'Create the first module',
        body: 'Start with a single learning unit. Materials, topics, and questions become easier to organize after that.',
        label: 'Open Materials',
        onTap: () => _H.openTab(context, course, Routes.courseMaterials(slug)),
      );
    }
    if (materialCount == 0) {
      return _Move(
        icon: Icons.upload_file_outlined,
        accent: const Color(0xFF7C3AED),
        title: 'Attach content to the structure',
        body: 'Your modules exist. Add PDFs, slides, or documents so the course has teachable substance.',
        label: 'Upload Material',
        onTap: () => _H.openTab(context, course, Routes.courseMaterials(slug)),
      );
    }
    if (questionCount == 0) {
      return _Move(
        icon: Icons.auto_awesome_rounded,
        accent: const Color(0xFFEA580C),
        title: 'Turn materials into assessment',
        body: 'Content is ready. Build a question bank manually or generate questions from the uploaded materials.',
        label: 'Open Question Bank',
        onTap: () => _H.openTab(context, course, Routes.courseQuestionBank(slug)),
      );
    }
    if (studentCount == 0) {
      return _Move(
        icon: Icons.person_add_alt_1_outlined,
        accent: AppColors.successText,
        title: 'Prepare learner access',
        body: 'The academic structure is ready. Invite students when you want the course to start being used.',
        label: 'Open Students',
        onTap: () => _H.openTab(context, course, Routes.courseStudents(slug)),
      );
    }
    return _Move(
      icon: Icons.tune_rounded,
      accent: AppColors.primary,
      title: 'Review and refine',
      body: 'The course has structure, content, assessment, and learners. Use this page to monitor drift and keep it clean.',
      label: 'View Materials',
      onTap: () => _H.openTab(context, course, Routes.courseMaterials(slug)),
    );
  }
}

class _Move {
  final IconData icon;
  final Color accent;
  final String title;
  final String body;
  final String label;
  final VoidCallback onTap;

  const _Move({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
    required this.label,
    required this.onTap,
  });
}

class _CourseMapCard extends StatelessWidget {
  final List<ModuleItem> modules;
  final Map<int, List<MaterialItem>> materialsByModule;
  final bool loading;

  const _CourseMapCard({
    required this.modules,
    required this.materialsByModule,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final shown = modules.take(6).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _H.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.route_outlined,
            title: 'Course map',
            subtitle: 'Compact view of the teaching sequence.',
            trailing: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          if (modules.isEmpty && !loading)
            const _EmptyInline(
              icon: Icons.account_tree_outlined,
              title: 'No modules yet',
              message: 'Create one module to make the course structure visible here.',
            )
          else
            Column(
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  _ModuleRow(
                    module: shown[i],
                    index: i,
                    materials: materialsByModule[shown[i].id] ?? const [],
                  ),
                  if (i != shown.length - 1) const SizedBox(height: 10),
                ],
                if (modules.length > shown.length) ...[
                  const SizedBox(height: 12),
                  Text(
                    '+${modules.length - shown.length} more module${modules.length - shown.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  final ModuleItem module;
  final int index;
  final List<MaterialItem> materials;

  const _ModuleRow({
    required this.module,
    required this.index,
    required this.materials,
  });

  @override
  Widget build(BuildContext context) {
    final accent = module.isPublished ? AppColors.successText : const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.title.trim().isEmpty ? 'Untitled module' : module.title.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${materials.length} file${materials.length == 1 ? '' : 's'} · ${module.isPublished ? 'Published' : 'Draft'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactCourseFacts extends StatelessWidget {
  final MyCourseItem course;
  final double readiness;
  final int publishedModules;
  final int draftModules;

  const _CompactCourseFacts({
    required this.course,
    required this.readiness,
    required this.publishedModules,
    required this.draftModules,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _H.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.radar_rounded,
            title: 'Course pulse',
            subtitle: 'Only the signals that matter.',
          ),
          const SizedBox(height: 14),
          _FactRow(label: 'Readiness', value: '${(readiness * 100).round()}%'),
          _FactRow(label: 'Published modules', value: '$publishedModules'),
          _FactRow(label: 'Draft modules', value: '$draftModules'),
          _FactRow(label: 'Created', value: _H.date(course.createdAt)),
          _FactRow(label: 'Updated', value: _H.date(course.updatedAt), isLast: true),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _FactRow({required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10, top: isLast ? 10 : 0),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textTitle,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsefulShortcuts extends StatelessWidget {
  final MyCourseItem course;
  final String slug;
  final bool canGenerate;

  const _UsefulShortcuts({
    required this.course,
    required this.slug,
    required this.canGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _Shortcut(
        icon: Icons.folder_open_outlined,
        label: 'Materials',
        onTap: () => _H.openTab(context, course, Routes.courseMaterials(slug)),
      ),
      _Shortcut(
        icon: Icons.flag_outlined,
        label: 'Outcomes',
        onTap: () => _H.openTab(context, course, Routes.courseOutcomes(slug)),
      ),
      _Shortcut(
        icon: Icons.quiz_outlined,
        label: 'Question Bank',
        onTap: () => _H.openTab(context, course, Routes.courseQuestionBank(slug)),
      ),
      _Shortcut(
        icon: Icons.people_outline_rounded,
        label: 'Students',
        onTap: () => _H.openTab(context, course, Routes.courseStudents(slug)),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _H.cardDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Useful shortcuts',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textTitle,
                        ),
                      ),
                    ),
                    if (canGenerate)
                      _TextLink(
                        label: 'Generate questions',
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => GenerateQuestionsDialog(courseId: course.id),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (compact)
                Column(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      _ShortcutTile(shortcut: actions[i]),
                      if (i != actions.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                )
              else
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      Expanded(child: _ShortcutTile(shortcut: actions[i])),
                      if (i != actions.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Shortcut {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Shortcut({required this.icon, required this.label, required this.onTap});
}

class _ShortcutTile extends StatelessWidget {
  final _Shortcut shortcut;

  const _ShortcutTile({required this.shortcut});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: shortcut.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceBg,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(shortcut.icon, size: 17, color: AppColors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  shortcut.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTitle,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _CardTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textTitle,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _Chip({required this.label, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TextLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyInline extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyInline({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textTitle,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
