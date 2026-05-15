import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learnova/core/network/error_mapper.dart';
import 'package:learnova/core/theme/app_theme.dart';
import 'package:learnova/core/ui/toast.dart';
import 'package:learnova/features/instructor/data/exam_models.dart';
import 'package:learnova/features/instructor/data/question_models.dart';
import 'package:learnova/features/instructor/data/modules_materials_providers.dart';
import 'package:learnova/features/instructor/presentation/controllers/selected_course_provider.dart';

class InstructorQuizzesScreen extends ConsumerStatefulWidget {
  final int? courseId;
  final String? courseTitle;

  const InstructorQuizzesScreen({super.key, this.courseId, this.courseTitle});

  @override
  ConsumerState<InstructorQuizzesScreen> createState() =>
      _InstructorQuizzesScreenState();
}

class _InstructorQuizzesScreenState extends ConsumerState<InstructorQuizzesScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  String _query = '';
  String _statusFilter = 'all';
  String _typeFilter = 'all';
  List<ExamModel> _exams = const [];
  ExamModel? _selectedExam;
  ExamDetailsModel? _selectedDetails;
  bool _detailsLoading = false;
  String? _detailsError;

  int? get _courseId => widget.courseId ?? SelectedCourseCache.cachedCourseId;

  String get _courseTitle {
    final explicit = widget.courseTitle?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final cached = SelectedCourseCache.value?.title.trim();
    if (cached != null && cached.isNotEmpty) return cached;
    return 'selected course';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExams());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExams() async {
    final courseId = _courseId;
    if (courseId == null || courseId <= 0) {
      setState(() {
        _loading = false;
        _error = 'Open a course first to view its quizzes.';
        _exams = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ref.read(examsApiProvider).listExams(courseId: courseId);
      if (!mounted) return;
      setState(() {
        _exams = response.exams;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mapApiFailure(e).message;
        _loading = false;
      });
    }
  }

  List<ExamModel> get _filteredExams {
    final q = _query.trim().toLowerCase();
    return _exams.where((exam) {
      final matchesText = q.isEmpty ||
          exam.title.toLowerCase().contains(q) ||
          (exam.description ?? '').toLowerCase().contains(q) ||
          exam.examType.toLowerCase().contains(q);
      final matchesStatus = _statusFilter == 'all' ||
          (_statusFilter == 'published' && exam.isPublished) ||
          (_statusFilter == 'draft' && !exam.isPublished);
      final matchesType = _typeFilter == 'all' ||
          exam.examType.toLowerCase() == _typeFilter;
      return matchesText && matchesStatus && matchesType;
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedExam != null || _detailsLoading) {
      return _ExamAnalyticsPage(
        exam: _selectedDetails?.exam ?? _selectedExam,
        details: _selectedDetails,
        loading: _detailsLoading,
        error: _detailsError,
        onBack: _backToQuizList,
        onRetry: () {
          final exam = _selectedExam;
          if (exam != null) unawaited(_openExamDetails(exam));
        },
      );
    }

    final filtered = _filteredExams;
    return Container(
      color: AppColors.pageBg,
      child: RefreshIndicator(
        onRefresh: _loadExams,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(courseTitle: _courseTitle, onCreate: () {
                      AppToast.info(
                        context,
                        title: 'Create from Question Bank',
                        message: 'Open the course Question Bank tab to create a quiz from saved questions.',
                      );
                    }),
                    const SizedBox(height: 22),
                    _StatsSection(exams: _exams),
                    const SizedBox(height: 22),
                    _FiltersBar(
                      controller: _searchController,
                      status: _statusFilter,
                      type: _typeFilter,
                      onSearchChanged: (value) => setState(() => _query = value),
                      onStatusChanged: (value) => setState(() => _statusFilter = value ?? 'all'),
                      onTypeChanged: (value) => setState(() => _typeFilter = value ?? 'all'),
                    ),
                    const SizedBox(height: 14),
                    _ExamTable(
                      loading: _loading,
                      error: _error,
                      exams: filtered,
                      onRetry: _loadExams,
                      onOpen: _openExamDetails,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${filtered.length} of ${_exams.length} quizzes',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExamDetails(ExamModel exam) async {
    final courseId = _courseId;
    if (courseId == null) return;

    setState(() {
      _selectedExam = exam;
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

  void _backToQuizList() {
    setState(() {
      _selectedExam = null;
      _selectedDetails = null;
      _detailsLoading = false;
      _detailsError = null;
    });
  }
}

class _Header extends StatelessWidget {
  final String courseTitle;
  final VoidCallback onCreate;
  const _Header({required this.courseTitle, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quiz Management',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage created exams and quizzes for $courseTitle.',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Create New Quiz'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1682F3),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  final List<ExamModel> exams;
  const _StatsSection({required this.exams});

  @override
  Widget build(BuildContext context) {
    final active = exams.where((exam) => exam.isPublished).length;
    final draft = exams.length - active;
    final totalQuestions = exams.fold<int>(0, (sum, exam) => sum + exam.totalQuestions);
    return Row(
      children: [
        Expanded(child: _StatCard(title: 'Active Quizzes', value: '$active', subtitle: '${exams.length} total created', icon: Icons.assignment_rounded, color: const Color(0xFF1682F3))),
        const SizedBox(width: 16),
        Expanded(child: _StatCard(title: 'Draft Quizzes', value: '$draft', subtitle: 'not published yet', icon: Icons.edit_note_rounded, color: const Color(0xFFF59E0B))),
        const SizedBox(width: 16),
        Expanded(child: _StatCard(title: 'Bank Questions Used', value: '$totalQuestions', subtitle: 'questions across quizzes', icon: Icons.fact_check_rounded, color: const Color(0xFF22C55E))),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x080F172A), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
        ],
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  final TextEditingController controller;
  final String status;
  final String type;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onTypeChanged;
  const _FiltersBar({required this.controller, required this.status, required this.type, required this.onSearchChanged, required this.onStatusChanged, required this.onTypeChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: controller,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search quizzes by title, description, or type...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1682F3))),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _DropdownShell(
            width: 150,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: status,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All status')),
                  DropdownMenuItem(value: 'published', child: Text('Published')),
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                ],
                onChanged: onStatusChanged,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _DropdownShell(
            width: 140,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: type,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All types')),
                  DropdownMenuItem(value: 'quiz', child: Text('Quiz')),
                  DropdownMenuItem(value: 'exam', child: Text('Exam')),
                ],
                onChanged: onTypeChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownShell extends StatelessWidget {
  final double width;
  final Widget child;
  const _DropdownShell({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w700),
        child: child,
      ),
    );
  }
}

class _ExamTable extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<ExamModel> exams;
  final VoidCallback onRetry;
  final ValueChanged<ExamModel> onOpen;
  const _ExamTable({required this.loading, required this.error, required this.exams, required this.onRetry, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x060F172A), blurRadius: 20, offset: Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const _ExamTableHeader(),
          if (loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 44), child: CircularProgressIndicator())
          else if (error != null)
            _TableMessage(icon: Icons.error_outline_rounded, title: 'Could not load quizzes', message: error!, actionLabel: 'Retry', onAction: onRetry)
          else if (exams.isEmpty)
            const _TableMessage(icon: Icons.assignment_outlined, title: 'No quizzes found', message: 'Created exams will appear here after they are saved from the Question Bank.')
          else
            ...exams.map((exam) => _ExamRow(exam: exam, onTap: () => onOpen(exam))),
        ],
      ),
    );
  }
}

class _ExamTableHeader extends StatelessWidget {
  const _ExamTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: const Row(
        children: [
          Expanded(flex: 5, child: _HeaderText('QUIZ TITLE')),
          Expanded(flex: 2, child: _HeaderText('STATUS')),
          Expanded(flex: 2, child: _HeaderText('QUESTIONS')),
          Expanded(flex: 2, child: _HeaderText('TIME LIMIT')),
          Expanded(flex: 2, child: _HeaderText('UPDATED')),
          SizedBox(width: 82, child: _HeaderText('ACTIONS')),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;
  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5));
  }
}

class _ExamRow extends StatelessWidget {
  final ExamModel exam;
  final VoidCallback onTap;
  const _ExamRow({required this.exam, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = exam.isPublished ? const Color(0xFF16A34A) : const Color(0xFF64748B);
    final statusLabel = exam.isPublished ? 'Published' : 'Draft';
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.assignment_outlined, color: Color(0xFF1682F3), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exam.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
                        const SizedBox(height: 4),
                        Text(_subtitle(exam), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _Badge(label: statusLabel, color: statusColor))),
            Expanded(flex: 2, child: Text('${exam.totalQuestions} question${exam.totalQuestions == 1 ? '' : 's'}', style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w700))),
            Expanded(flex: 2, child: Text(exam.durationMinutes == null ? 'No limit' : '${exam.durationMinutes} min', style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w700))),
            Expanded(flex: 2, child: Text(_formatDate(exam.updatedAt), style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w700))),
            SizedBox(width: 82, child: TextButton(onPressed: onTap, child: const Text('View'))),
          ],
        ),
      ),
    );
  }

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
        children: [
          Icon(icon, size: 34, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
  final ExamDetailsModel? details;
  final bool loading;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  const _ExamAnalyticsPage({
    required this.exam,
    required this.details,
    required this.loading,
    required this.error,
    required this.onBack,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
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
  final VoidCallback onBack;

  const _ExamDetailsHeader({
    required this.exam,
    required this.questionsCount,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final title = exam?.title.trim().isNotEmpty == true
        ? exam!.title
        : 'Exam details';
    final updated = exam == null ? '-' : _ExamRow._formatDate(exam!.updatedAt);

    return Row(
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
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Updated $updated • $questionsCount question${questionsCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Back to quizzes'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF334155),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.rocket_launch_outlined, size: 18),
          label: const Text('Release Grades'),
          style: FilledButton.styleFrom(
            disabledBackgroundColor: const Color(0xFFE2E8F0),
            disabledForegroundColor: const Color(0xFF94A3B8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
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
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: 'Questions',
            value: '$questionsCount',
            subtitle: 'saved in this quiz',
            icon: Icons.quiz_outlined,
            color: const Color(0xFF1682F3),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            title: 'Total Points',
            value: _points(totalPoints),
            subtitle: 'from selected questions',
            icon: Icons.stacked_line_chart_rounded,
            color: const Color(0xFF22C55E),
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
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            title: 'Status',
            value: exam?.isPublished == true ? 'Published' : 'Draft',
            subtitle: exam?.isPublished == true ? 'visible to students' : 'not visible yet',
            icon: Icons.verified_outlined,
            color: exam?.isPublished == true
                ? const Color(0xFF22C55E)
                : const Color(0xFF64748B),
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
    return Container(
      height: 118,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 20,
            offset: Offset(0, 10),
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
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
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
                  : const Text(
                      'No student submissions yet.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.filter_list_rounded, size: 18, color: Color(0xFF64748B)),
          SizedBox(width: 12),
          Icon(Icons.download_outlined, size: 18, color: Color(0xFF64748B)),
        ],
      ),
      child: body,
    );
  }
}

class _QuestionBreakdownHeader extends StatelessWidget {
  const _QuestionBreakdownHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      color: const Color(0xFFF8FAFC),
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
    final rate = question.successRate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              index.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: Color(0xFF64748B),
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
              style: const TextStyle(
                color: Color(0xFF0F172A),
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
              style: const TextStyle(
                color: Color(0xFF475569),
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
                color: rate == null ? const Color(0xFF94A3B8) : const Color(0xFF16A34A),
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
    return _PanelCard(
      title: 'Student Results',
      trailing: const Text(
        'TOP 5',
        style: TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 48),
        child: Column(
          children: [
            Icon(Icons.people_alt_outlined, color: Color(0xFF94A3B8), size: 34),
            SizedBox(height: 12),
            Text(
              'No submissions yet',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Student scores will appear here after learners attempt this quiz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 20,
            offset: Offset(0, 10),
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
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                trailing,
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Color(0xFF1682F3),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
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
    final normalized = label.toLowerCase();
    final color = normalized == 'easy'
        ? const Color(0xFF16A34A)
        : normalized == 'hard'
            ? const Color(0xFFEF4444)
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
                  Expanded(child: Text(exam.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)))),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(label: exam.isPublished ? 'Published' : 'Draft', color: exam.isPublished ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
                  _Badge(label: _ExamRow._titleCase(exam.examType), color: const Color(0xFF1682F3)),
                ],
              ),
              if ((exam.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text('Description', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                Text(exam.description!, style: const TextStyle(color: Color(0xFF475569), height: 1.45)),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
