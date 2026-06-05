import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learnova/core/network/error_mapper.dart';
import 'package:learnova/core/theme/app_theme.dart';
import 'package:learnova/core/utils/file_download_stub.dart'
    if (dart.library.html) 'package:learnova/core/utils/file_download_web.dart';
import 'package:learnova/core/ui/toast.dart';
import 'package:learnova/features/instructor/data/courses_models.dart';
import 'package:learnova/features/instructor/data/courses_providers.dart';
import 'package:learnova/features/instructor/data/exam_models.dart';
import 'package:learnova/features/instructor/data/question_models.dart';
import 'package:learnova/features/instructor/data/modules_materials_providers.dart';

class InstructorQuizzesScreen extends ConsumerStatefulWidget {
  final int? courseId;
  final String? courseTitle;

  const InstructorQuizzesScreen({super.key, this.courseId, this.courseTitle});

  @override
  ConsumerState<InstructorQuizzesScreen> createState() =>
      _InstructorQuizzesScreenState();
}

class _InstructorQuizzesScreenState extends ConsumerState<InstructorQuizzesScreen> {
  bool _loading = true;
  String? _error;
  List<_CourseQuizGroup> _groups = const [];
  Set<int> _expandedCourseIds = const {};
  int? _activeCourseId;
  ExamModel? _selectedExam;
  int? _selectedExamCourseId;
  ExamDetailsModel? _selectedDetails;
  bool _detailsLoading = false;
  bool _exportingExamPdf = false;
  String? _detailsError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAllCourseQuizzes());
  }

  Future<void> _loadAllCourseQuizzes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final coursesResponse = await ref.read(coursesApiProvider).myCourses();
      final courses = [...coursesResponse.items]
        ..sort((a, b) => a.safeTitle.toLowerCase().compareTo(b.safeTitle.toLowerCase()));

      final groups = await Future.wait<_CourseQuizGroup>(courses.map((course) async {
        try {
          final response = await ref.read(examsApiProvider).listExams(courseId: course.id);
          final exams = [...response.exams]
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return _CourseQuizGroup(course: course, exams: exams);
        } catch (e) {
          return _CourseQuizGroup(
            course: course,
            exams: const [],
            error: mapApiFailure(e).message,
          );
        }
      }),);

      if (!mounted) return;
      final groupsWithExams = groups.where((group) => group.exams.isNotEmpty).toList();
      final preferredCourseId = widget.courseId;
      final activeCourseId = preferredCourseId != null && groupsWithExams.any((g) => g.course.id == preferredCourseId)
          ? preferredCourseId
          : groupsWithExams.isNotEmpty
              ? groupsWithExams.first.course.id
              : null;
      setState(() {
        _groups = groupsWithExams;
        _expandedCourseIds = groupsWithExams.map((g) => g.course.id).toSet();
        _activeCourseId = activeCourseId;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mapApiFailure(e).message;
        _groups = const [];
        _expandedCourseIds = const {};
        _activeCourseId = null;
        _loading = false;
      });
    }
  }

  List<_CourseQuizGroup> get _visibleGroups => _groups;

  _CourseQuizGroup? get _activeGroup {
    final activeId = _activeCourseId;
    if (activeId == null) return _visibleGroups.isNotEmpty ? _visibleGroups.first : null;
    for (final group in _visibleGroups) {
      if (group.course.id == activeId) return group;
    }
    return _visibleGroups.isNotEmpty ? _visibleGroups.first : null;
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedExam != null || _detailsLoading) {
      return _ExamAnalyticsPage(
        exam: _selectedDetails?.exam ?? _selectedExam,
        courseId: _selectedExamCourseId,
        details: _selectedDetails,
        loading: _detailsLoading,
        exportingPdf: _exportingExamPdf,
        error: _detailsError,
        onBack: _backToQuizWorkspace,
        onExportPdf: _exportExamPdfFromBackend,
        onRetry: () {
          final exam = _selectedExam;
          final courseId = _selectedExamCourseId;
          if (exam != null && courseId != null) {
            unawaited(_openExamDetails(courseId: courseId, exam: exam));
          }
        },
      );
    }

    final visibleGroups = _visibleGroups;
    final activeGroup = _activeGroup;
    return Container(
      color: AppColors.pageBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1220),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WorkspaceHeader(
                    stats: _QuizWorkspaceStats.fromGroups(_groups),
                  ),
                  const SizedBox(height: 16),
                  _QuizWorkspaceBody(
                    loading: _loading,
                    error: _error,
                    groups: visibleGroups,
                    activeCourseId: activeGroup?.course.id,
                    expandedCourseIds: _expandedCourseIds,
                    onRetry: _loadAllCourseQuizzes,
                    onToggleCourse: _toggleCourse,
                    onSelectCourse: (courseId) => setState(() => _activeCourseId = courseId),
                    onOpenExam: (courseId, exam) => _openExamDetails(courseId: courseId, exam: exam),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleCourse(int courseId) {
    setState(() {
      _activeCourseId = courseId;
      final next = {..._expandedCourseIds};
      if (next.contains(courseId)) {
        next.remove(courseId);
      } else {
        next.add(courseId);
      }
      _expandedCourseIds = next;
    });
  }

  Future<void> _openExamDetails({required int courseId, required ExamModel exam}) async {
    setState(() {
      _selectedExam = exam;
      _selectedExamCourseId = courseId;
      _selectedDetails = null;
      _detailsLoading = true;
      _detailsError = null;
    });

    try {
      final details = await ref.read(examsApiProvider).getExam(
            courseId: courseId,
            examId: exam.id,
          );
      if (!mounted) return;
      setState(() {
        _selectedDetails = details;
        _selectedExam = details.exam;
        _detailsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detailsError = mapApiFailure(e).message;
        _detailsLoading = false;
      });
    }
  }

  Future<void> _exportExamPdfFromBackend(ExamModel exam) async {
    final courseId = _selectedExamCourseId;
    if (courseId == null || _exportingExamPdf) return;

    final options = await _showExamPdfExportOptionsDialog();
    if (options == null || !mounted) return;

    setState(() => _exportingExamPdf = true);
    try {
      final export = await ref.read(examsApiProvider).exportExamPdf(
            courseId: courseId,
            examId: exam.id,
            includeLearnovaLogo: options.includeLearnovaLogo,
            includeCourseTitle: options.includeCourseTitle,
            includeCourseCode: options.includeCourseCode,
            includeExamMetadata: options.includeExamMetadata,
            includeInstructions: options.includeInstructions,
            includeSectionDescriptions: options.includeSectionDescriptions,
            includePoints: options.includePoints,
            includeStudentInfoFields: options.includeStudentInfoFields,
            includeAnswerSpace: options.includeAnswerSpace,
          );
      if (!mounted) return;
      downloadBytesFile(
        filename: export.filename,
        bytes: export.bytes,
        mimeType: 'application/pdf',
      );
      AppToast.success(
        context,
        title: 'PDF exported',
        message: 'Downloaded the backend-generated exam PDF.',
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.error(
        context,
        title: 'Export failed',
        message: mapApiFailure(e).message,
      );
    } finally {
      if (mounted) setState(() => _exportingExamPdf = false);
    }
  }

  Future<_ExamPdfExportOptions?> _showExamPdfExportOptionsDialog() {
    return showDialog<_ExamPdfExportOptions>(
      context: context,
      builder: (_) => const _ExamPdfExportOptionsDialog(),
    );
  }

  void _backToQuizWorkspace() {
    setState(() {
      _selectedExam = null;
      _selectedExamCourseId = null;
      _selectedDetails = null;
      _detailsLoading = false;
      _exportingExamPdf = false;
      _detailsError = null;
    });
  }
}

class _ExamPdfExportOptions {
  final bool includeLearnovaLogo;
  final bool includeCourseTitle;
  final bool includeCourseCode;
  final bool includeExamMetadata;
  final bool includeInstructions;
  final bool includeSectionDescriptions;
  final bool includePoints;
  final bool includeStudentInfoFields;
  final bool includeAnswerSpace;

  const _ExamPdfExportOptions({
    this.includeLearnovaLogo = true,
    this.includeCourseTitle = true,
    this.includeCourseCode = false,
    this.includeExamMetadata = true,
    this.includeInstructions = false,
    this.includeSectionDescriptions = true,
    this.includePoints = true,
    this.includeStudentInfoFields = true,
    this.includeAnswerSpace = true,
  });
}

class _ExamPdfExportOptionsDialog extends StatefulWidget {
  const _ExamPdfExportOptionsDialog();

  @override
  State<_ExamPdfExportOptionsDialog> createState() => _ExamPdfExportOptionsDialogState();
}

class _ExamPdfExportOptionsDialogState extends State<_ExamPdfExportOptionsDialog> {
  bool _includeLearnovaLogo = true;
  bool _includeCourseTitle = true;
  bool _includeCourseCode = false;
  bool _includeExamMetadata = true;
  bool _includeInstructions = false;
  bool _includeSectionDescriptions = true;
  bool _includePoints = true;
  bool _includeStudentInfoFields = true;
  bool _includeAnswerSpace = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('PDF export options'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _switchTile(
                title: 'Learnova logo',
                value: _includeLearnovaLogo,
                onChanged: (value) => setState(() => _includeLearnovaLogo = value),
              ),
              _switchTile(
                title: 'Course title',
                value: _includeCourseTitle,
                onChanged: (value) => setState(() => _includeCourseTitle = value),
              ),
              _switchTile(
                title: 'Course code',
                value: _includeCourseCode,
                onChanged: (value) => setState(() => _includeCourseCode = value),
              ),
              _switchTile(
                title: 'Exam metadata',
                value: _includeExamMetadata,
                onChanged: (value) => setState(() => _includeExamMetadata = value),
              ),
              _switchTile(
                title: 'Instructions',
                subtitle: 'Off by default.',
                value: _includeInstructions,
                onChanged: (value) => setState(() => _includeInstructions = value),
              ),
              _switchTile(
                title: 'Section descriptions',
                value: _includeSectionDescriptions,
                onChanged: (value) => setState(() => _includeSectionDescriptions = value),
              ),
              _switchTile(
                title: 'Question points',
                value: _includePoints,
                onChanged: (value) => setState(() => _includePoints = value),
              ),
              _switchTile(
                title: 'Student info fields',
                value: _includeStudentInfoFields,
                onChanged: (value) => setState(() => _includeStudentInfoFields = value),
              ),
              _switchTile(
                title: 'Answer space',
                value: _includeAnswerSpace,
                onChanged: (value) => setState(() => _includeAnswerSpace = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _ExamPdfExportOptions(
                includeLearnovaLogo: _includeLearnovaLogo,
                includeCourseTitle: _includeCourseTitle,
                includeCourseCode: _includeCourseCode,
                includeExamMetadata: _includeExamMetadata,
                includeInstructions: _includeInstructions,
                includeSectionDescriptions: _includeSectionDescriptions,
                includePoints: _includePoints,
                includeStudentInfoFields: _includeStudentInfoFields,
                includeAnswerSpace: _includeAnswerSpace,
              ),
            );
          },
          child: const Text('Export'),
        ),
      ],
    );
  }

  Widget _switchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _CourseQuizGroup {
  final MyCourseItem course;
  final List<ExamModel> exams;
  final String? error;

  const _CourseQuizGroup({required this.course, required this.exams, this.error});

  int get published => exams.where((exam) => exam.isPublished).length;
  int get draft => exams.length - published;
  int get totalQuestions => exams.fold<int>(0, (sum, exam) => sum + exam.totalQuestions);

  _CourseQuizGroup copyWith({List<ExamModel>? exams}) {
    return _CourseQuizGroup(
      course: course,
      exams: exams ?? this.exams,
      error: error,
    );
  }
}

class _QuizWorkspaceStats {
  final int courses;
  final int quizzes;
  final int published;
  final int draft;
  final int questions;

  const _QuizWorkspaceStats({required this.courses, required this.quizzes, required this.published, required this.draft, required this.questions});

  factory _QuizWorkspaceStats.fromGroups(List<_CourseQuizGroup> groups) {
    final quizzes = groups.fold<int>(0, (sum, group) => sum + group.exams.length);
    final published = groups.fold<int>(0, (sum, group) => sum + group.published);
    final questions = groups.fold<int>(0, (sum, group) => sum + group.totalQuestions);
    return _QuizWorkspaceStats(
      courses: groups.length,
      quizzes: quizzes,
      published: published,
      draft: quizzes - published,
      questions: questions,
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  final _QuizWorkspaceStats stats;

  const _WorkspaceHeader({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1155CC), Color(0xFF1787E8), Color(0xFF22C3DD)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.shadowThin, blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.18))),
            child: const Icon(Icons.account_tree_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quiz Workspace', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text('Browse every course and open its saved exams from one tree.', style: TextStyle(color: Colors.white.withOpacity(0.86), fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          _HeaderMetric(value: '${stats.courses}', label: 'Courses'),
          const SizedBox(width: 10),
          _HeaderMetric(value: '${stats.quizzes}', label: 'Quizzes'),
          const SizedBox(width: 10),
          _HeaderMetric(value: '${stats.questions}', label: 'Questions'),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String value;
  final String label;

  const _HeaderMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.18))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _QuizWorkspaceBody extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<_CourseQuizGroup> groups;
  final int? activeCourseId;
  final Set<int> expandedCourseIds;
  final VoidCallback onRetry;
  final ValueChanged<int> onToggleCourse;
  final ValueChanged<int> onSelectCourse;
  final void Function(int courseId, ExamModel exam) onOpenExam;

  const _QuizWorkspaceBody({
    required this.loading,
    required this.error,
    required this.groups,
    required this.activeCourseId,
    required this.expandedCourseIds,
    required this.onRetry,
    required this.onToggleCourse,
    required this.onSelectCourse,
    required this.onOpenExam,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _WorkspaceShell(
        child: SizedBox(
          height: 360,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (error != null) {
      return _WorkspaceShell(
        child: _TableMessage(icon: Icons.error_outline_rounded, title: 'Could not load quizzes', message: error!, actionLabel: 'Retry', onAction: onRetry),
      );
    }
    if (groups.isEmpty) {
      return const _WorkspaceShell(
        child: _TableMessage(icon: Icons.school_outlined, title: 'No quizzes found', message: 'Only courses that already have saved exams appear here. Create an exam from a course Question Bank first.'),
      );
    }

    final activeGroup = groups.firstWhere(
      (group) => group.course.id == activeCourseId,
      orElse: () => groups.first,
    );

    return _WorkspaceShell(
      child: SizedBox(
        height: 560,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 390,
              child: _CourseQuizTree(
                groups: groups,
                activeCourseId: activeGroup.course.id,
                expandedCourseIds: expandedCourseIds,
                onToggleCourse: onToggleCourse,
                onSelectCourse: onSelectCourse,
                onOpenExam: onOpenExam,
              ),
            ),
            VerticalDivider(width: 1, color: AppColors.border),
            Expanded(
              child: _CourseExamsPanel(
                group: activeGroup,
                onOpenExam: (exam) => onOpenExam(activeGroup.course.id, exam),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceShell extends StatelessWidget {
  final Widget child;

  const _WorkspaceShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.shadowThin, blurRadius: 20, offset: const Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _CourseQuizTree extends StatelessWidget {
  final List<_CourseQuizGroup> groups;
  final int activeCourseId;
  final Set<int> expandedCourseIds;
  final ValueChanged<int> onToggleCourse;
  final ValueChanged<int> onSelectCourse;
  final void Function(int courseId, ExamModel exam) onOpenExam;

  const _CourseQuizTree({required this.groups, required this.activeCourseId, required this.expandedCourseIds, required this.onToggleCourse, required this.onSelectCourse, required this.onOpenExam});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          color: AppColors.surfaceBg,
          child: Row(
            children: [
              const Icon(Icons.account_tree_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('Course quiz tree', style: TextStyle(color: AppColors.textTitle, fontSize: 14, fontWeight: FontWeight.w900))),
              _Badge(label: '${groups.length}', color: AppColors.primary),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final group = groups[index];
              final expanded = expandedCourseIds.contains(group.course.id);
              final active = group.course.id == activeCourseId;
              return _CourseTreeNode(
                group: group,
                expanded: expanded,
                active: active,
                onToggle: () => onToggleCourse(group.course.id),
                onSelect: () => onSelectCourse(group.course.id),
                onOpenExam: (exam) => onOpenExam(group.course.id, exam),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CourseTreeNode extends StatelessWidget {
  final _CourseQuizGroup group;
  final bool expanded;
  final bool active;
  final VoidCallback onToggle;
  final VoidCallback onSelect;
  final ValueChanged<ExamModel> onOpenExam;

  const _CourseTreeNode({required this.group, required this.expanded, required this.active, required this.onToggle, required this.onSelect, required this.onOpenExam});

  @override
  Widget build(BuildContext context) {
    final course = group.course;
    return Container(
      decoration: BoxDecoration(
        color: active ? AppColors.primarySoft : AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? AppColors.primary.withOpacity(0.28) : AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              onSelect();
              if (!expanded) onToggle();
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(
                children: [
                  InkWell(
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(expanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded, size: 22, color: AppColors.textMuted),
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: AppColors.surfaceBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.folder_copy_outlined, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(course.safeTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textTitle, fontSize: 13, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text('${group.exams.length} quiz${group.exams.length == 1 ? '' : 'zes'} • ${course.safeCourseCode}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: AppColors.border),
            if (group.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Text(group.error!, style: const TextStyle(color: AppColors.errorDot, fontSize: 12, fontWeight: FontWeight.w700)),
              )
            else if (group.exams.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 10, 14, 12),
                child: Text('No exams in this course', style: TextStyle(color: AppColors.textHint, fontSize: 12, fontWeight: FontWeight.w700)),
              )
            else
              ...group.exams.map((exam) => _ExamTreeLeaf(exam: exam, onTap: () => onOpenExam(exam))),
          ],
        ],
      ),
    );
  }
}

class _ExamTreeLeaf extends StatelessWidget {
  final ExamModel exam;
  final VoidCallback onTap;

  const _ExamTreeLeaf({required this.exam, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(54, 8, 12, 8),
        child: Row(
          children: [
            Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: AppColors.textHint),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exam.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textGray, fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${exam.totalQuestions} q • ${exam.durationMinutes == null ? 'No limit' : '${exam.durationMinutes} min'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _StatusDot(published: exam.isPublished),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool published;

  const _StatusDot({required this.published});

  @override
  Widget build(BuildContext context) {
    final color = published ? AppColors.successDot : AppColors.textHint;
    return Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

class _CourseExamsPanel extends StatelessWidget {
  final _CourseQuizGroup group;
  final ValueChanged<ExamModel> onOpenExam;

  const _CourseExamsPanel({required this.group, required this.onOpenExam});

  @override
  Widget build(BuildContext context) {
    final course = group.course;
    return Column(
      children: [
        Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.school_outlined, color: AppColors.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.safeTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textTitle, fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('${group.exams.length} quizzes • ${group.published} published • ${group.draft} draft', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              _Badge(label: course.isPrivate ? 'Private' : 'Public', color: course.isPrivate ? AppColors.warningText : AppColors.successText),
            ],
          ),
        ),
        Expanded(
          child: group.error != null
              ? _TableMessage(icon: Icons.error_outline_rounded, title: 'Could not load course exams', message: group.error!)
              : group.exams.isEmpty
                  ? const _TableMessage(icon: Icons.assignment_outlined, title: 'No quizzes in this course', message: 'Create an exam from this course Question Bank. It will appear here under the course node.')
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: group.exams.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _CourseExamTile(
                        index: index + 1,
                        exam: group.exams[index],
                        onTap: () => onOpenExam(group.exams[index]),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _CourseExamTile extends StatelessWidget {
  final int index;
  final ExamModel exam;
  final VoidCallback onTap;

  const _CourseExamTile({required this.index, required this.exam, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = exam.isPublished ? AppColors.successText : AppColors.textMuted;
    final type = _ExamRow._titleCase(exam.examType);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
              child: Text('$index', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exam.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textTitle, fontSize: 14, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text('$type • ${exam.totalQuestions} questions • ${_points(exam.totalScore)} points • ${exam.durationMinutes == null ? 'No limit' : '${exam.durationMinutes} min'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _Badge(label: exam.isPublished ? 'Published' : 'Draft', color: statusColor),
            const SizedBox(width: 14),
            Text(_ExamRow._formatDate(exam.updatedAt), style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(width: 14),
            TextButton(onPressed: onTap, child: const Text('Open')),
          ],
        ),
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;
  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.5));
  }
}

class _ExamRow {
  static String _subtitle(ExamModel exam) {
    final type = exam.examType.trim().isEmpty ? 'Quiz' : _titleCase(exam.examType);
    final score = exam.totalScore == exam.totalScore.roundToDouble() ? exam.totalScore.toInt().toString() : exam.totalScore.toStringAsFixed(1);
    return '$type • $score total points • ${exam.maxAttempts} attempt${exam.maxAttempts == 1 ? '' : 's'}';
  }

  static String _titleCase(String value) {
    final normalized = value.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return 'Quiz';
    return normalized.split(RegExp(r'\s+')).map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}').join(' ');
  }

  static String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return '-';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _TableMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _TableMessage({required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 34, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textTitle)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _ExamAnalyticsPage extends StatelessWidget {
  final ExamModel? exam;
  final int? courseId;
  final ExamDetailsModel? details;
  final bool loading;
  final bool exportingPdf;
  final String? error;
  final VoidCallback onBack;
  final Future<void> Function(ExamModel exam) onExportPdf;
  final VoidCallback onRetry;

  const _ExamAnalyticsPage({
    required this.exam,
    required this.courseId,
    required this.details,
    required this.loading,
    required this.exportingPdf,
    required this.error,
    required this.onBack,
    required this.onExportPdf,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final resolvedExam = details?.exam ?? exam;
    final questions = details?.questions ?? const <ExamQuestionDetail>[];
    final totalQuestions = questions.isNotEmpty
        ? questions.length
        : resolvedExam?.totalQuestions ?? 0;
    final totalPoints = resolvedExam == null
        ? 0.0
        : resolvedExam.totalScore;

    return Container(
      color: AppColors.pageBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ExamDetailsHeader(
                    exam: resolvedExam,
                    questionsCount: totalQuestions,
                    onBack: onBack,
                    exportingPdf: exportingPdf,
                    onExportPdf: resolvedExam == null || courseId == null || exportingPdf
                        ? null
                        : () => onExportPdf(resolvedExam),
                  ),
                  const SizedBox(height: 22),
                  _ExamDetailsStats(
                    exam: resolvedExam,
                    questionsCount: totalQuestions,
                    totalPoints: totalPoints,
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: Column(
                          children: [
                            _ScoreDistributionCard(
                              loading: loading,
                              hasSubmissions: false,
                            ),
                            const SizedBox(height: 18),
                            _QuestionBreakdownCard(
                              loading: loading,
                              error: error,
                              questions: questions,
                              onRetry: onRetry,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      const SizedBox(
                        width: 300,
                        child: _StudentResultsCard(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamDetailsHeader extends StatelessWidget {
  final ExamModel? exam;
  final int questionsCount;
  final bool exportingPdf;
  final VoidCallback onBack;
  final VoidCallback? onExportPdf;

  const _ExamDetailsHeader({
    required this.exam,
    required this.questionsCount,
    required this.exportingPdf,
    required this.onBack,
    required this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final title = exam?.title.trim().isNotEmpty ?? false
        ? exam!.title
        : 'Exam details';
    final updated = exam == null ? '-' : _ExamRow._formatDate(exam!.updatedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Back to quizzes'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary.withOpacity(0.24)),
            backgroundColor: AppColors.primarySoft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textTitle,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Updated $updated • $questionsCount question${questionsCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: onExportPdf,
              icon: exportingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: Text(exportingPdf ? 'Exporting...' : 'Export PDF'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border,
                disabledForegroundColor: AppColors.textHint,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ExamDetailsStats extends StatelessWidget {
  final ExamModel? exam;
  final int questionsCount;
  final double totalPoints;

  const _ExamDetailsStats({
    required this.exam,
    required this.questionsCount,
    required this.totalPoints,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: 'Questions',
            value: '$questionsCount',
            subtitle: 'saved in this quiz',
            icon: Icons.quiz_outlined,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            title: 'Total Points',
            value: _points(totalPoints),
            subtitle: 'from selected questions',
            icon: Icons.stacked_line_chart_rounded,
            color: AppColors.successDot,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            title: 'Time Limit',
            value: exam?.durationMinutes == null
                ? 'No limit'
                : '${exam!.durationMinutes}m',
            subtitle: 'student attempt time',
            icon: Icons.timer_outlined,
            color: AppColors.warningText,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            title: 'Status',
            value: exam?.isPublished ?? false ? 'Published' : 'Draft',
            subtitle: exam?.isPublished ?? false ? 'visible to students' : 'not visible yet',
            icon: Icons.verified_outlined,
            color: exam?.isPublished ?? false
                ? AppColors.successDot
                : AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  static String _points(double value) {
    return value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      height: 118,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowThin,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textTitle,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
        ],
      ),
    );
  }
}

class _ScoreDistributionCard extends StatelessWidget {
  final bool loading;
  final bool hasSubmissions;

  const _ScoreDistributionCard({
    required this.loading,
    required this.hasSubmissions,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return _PanelCard(
      title: 'Score Distribution',
      trailing: const _TinyLegend(label: 'Students'),
      child: SizedBox(
        height: 165,
        child: Center(
          child: loading
              ? const CircularProgressIndicator()
              : hasSubmissions
                  ? const Text('Distribution will appear here.')
                  : Text(
                      'No student submissions yet.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
        ),
      ),
    );
  }
}

class _QuestionBreakdownCard extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<ExamQuestionDetail> questions;
  final VoidCallback onRetry;

  const _QuestionBreakdownCard({
    required this.loading,
    required this.error,
    required this.questions,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    Widget body;
    if (loading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 42),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (error != null) {
      body = _TableMessage(
        icon: Icons.error_outline_rounded,
        title: 'Could not load exam details',
        message: error!,
        actionLabel: 'Retry',
        onAction: onRetry,
      );
    } else if (questions.isEmpty) {
      body = const _TableMessage(
        icon: Icons.quiz_outlined,
        title: 'No questions attached',
        message: 'This quiz was created but no questions were returned by the backend.',
      );
    } else {
      body = Column(
        children: [
          const _QuestionBreakdownHeader(),
          ...questions.asMap().entries.map((entry) {
            return _QuestionBreakdownRow(
              index: entry.key + 1,
              question: entry.value.question,
            );
          }),
        ],
      );
    }

    return _PanelCard(
      title: 'Question Breakdown',
      trailing: const SizedBox.shrink(),
      child: body,
    );
  }
}

class _QuestionBreakdownHeader extends StatelessWidget {
  const _QuestionBreakdownHeader();

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      height: 42,
      color: AppColors.surfaceBg,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const Row(
        children: [
          SizedBox(width: 48, child: _HeaderText('#')),
          Expanded(flex: 5, child: _HeaderText('QUESTION')),
          Expanded(flex: 2, child: _HeaderText('TYPE')),
          Expanded(flex: 2, child: _HeaderText('DIFFICULTY')),
          Expanded(flex: 2, child: _HeaderText('CORRECT RATE')),
        ],
      ),
    );
  }
}

class _QuestionBreakdownRow extends StatelessWidget {
  final int index;
  final QuestionModel question;

  const _QuestionBreakdownRow({
    required this.index,
    required this.question,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final rate = question.successRate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.headerBg)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              index.toString().padLeft(2, '0'),
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              question.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textTitle,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              question.typeLabel,
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _DifficultyPill(question.difficultyLabel),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              rate == null ? '-' : '${rate.toStringAsFixed(0)}%',
              style: TextStyle(
                color: rate == null ? AppColors.textHint : AppColors.successText,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentResultsCard extends StatelessWidget {
  const _StudentResultsCard();

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return _PanelCard(
      title: 'Student Results',
      trailing: Text(
        'TOP 5',
        style: TextStyle(
          color: AppColors.textHint,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 48),
        child: Column(
          children: [
            Icon(Icons.people_alt_outlined, color: AppColors.textHint, size: 34),
            const SizedBox(height: 12),
            Text(
              'No submissions yet',
              style: TextStyle(
                color: AppColors.textTitle,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Student scores will appear here after learners attempt this quiz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  final String title;
  final Widget trailing;
  final Widget child;

  const _PanelCard({
    required this.title,
    required this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowThin,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textTitle,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                trailing,
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          child,
        ],
      ),
    );
  }
}

class _TinyLegend extends StatelessWidget {
  final String label;

  const _TinyLegend({required this.label});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DifficultyPill extends StatelessWidget {
  final String label;

  const _DifficultyPill(this.label);

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final normalized = label.toLowerCase();
    final color = normalized == 'easy'
        ? AppColors.successText
        : normalized == 'hard'
            ? AppColors.errorDot
            : const Color(0xFFF97316);
    return _Badge(label: label, color: color);
  }
}

String _points(double value) {
  return value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
}


class _ExamDetailsDialog extends StatelessWidget {
  final ExamModel exam;
  final int questionsCount;
  const _ExamDetailsDialog({required this.exam, required this.questionsCount});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(exam.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textTitle))),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(label: exam.isPublished ? 'Published' : 'Draft', color: exam.isPublished ? AppColors.successText : AppColors.textMuted),
                  _Badge(label: _ExamRow._titleCase(exam.examType), color: AppColors.primary),
                ],
              ),
              if ((exam.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('Description', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textGray)),
                const SizedBox(height: 6),
                Text(exam.description!, style: TextStyle(color: AppColors.textGray, height: 1.45)),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _DetailTile(label: 'Questions', value: '$questionsCount')),
                  const SizedBox(width: 12),
                  Expanded(child: _DetailTile(label: 'Total Points', value: _points(exam.totalScore))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _DetailTile(label: 'Time Limit', value: exam.durationMinutes == null ? 'No limit' : '${exam.durationMinutes} min')),
                  const SizedBox(width: 12),
                  Expanded(child: _DetailTile(label: 'Attempts', value: '${exam.maxAttempts}')),
                ],
              ),
              const SizedBox(height: 20),
              Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done'))),
            ],
          ),
        ),
      ),
    );
  }

  static String _points(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
}

class _DetailTile extends StatelessWidget {
  final String label;
  final String value;
  const _DetailTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: AppColors.textTitle, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
