import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/network/error_mapper.dart';
import '../../../data/courses_models.dart';
import '../../../data/modules_materials_providers.dart';
import '../../../data/question_models.dart';
import '../../controllers/course_details_controller.dart';
import 'create_exam_flow.dart';

class CourseQuestionBankTab extends ConsumerStatefulWidget {
  final MyCourseItem course;
  const CourseQuestionBankTab({super.key, required this.course});

  @override
  ConsumerState<CourseQuestionBankTab> createState() => _CourseQuestionBankTabState();
}

class _CourseQuestionBankTabState extends ConsumerState<CourseQuestionBankTab> {
  String _search = '';
  QuestionType? _filterType;
  QuestionDifficulty? _filterDiff;
  int? _filterModuleId;

  bool _loading = true;
  bool _creatingExam = false;
  String? _error;
  List<QuestionModel> _questions = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuestions());
  }

  Future<void> _loadQuestions() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(questionsApiProvider);
      final resp = await api.getCourseQuestions(courseId: widget.course.id);
      final enriched = await Future.wait(
        resp.questions.map((question) async {
          final id = question.remoteId;
          if (id == null) return question;
          try {
            return await api.getQuestion(
              courseId: widget.course.id,
              questionId: id,
            );
          } catch (_) {
            return question;
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        _questions = enriched;
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

  @override
  Widget build(BuildContext context) {
    final courseState = ref.watch(courseDetailsControllerProvider(widget.course.id));
    final filtered = _applyFilters(_questions);

    if (_creatingExam) {
      return CreateExamFlow(
        course: widget.course,
        questions: _questions,
        onCancel: () => setState(() => _creatingExam = false),
        onCreated: () async {
          await _loadQuestions();
          if (!mounted) return;
          setState(() => _creatingExam = false);
        },
      );
    }

    return Container(
      color: AppColors.pageBg,
      child: RefreshIndicator(
        onRefresh: _loadQuestions,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            _QuestionLibraryHero(
              total: _questions.length,
              filtered: filtered.length,
              loading: _loading,
              search: _search,
            ),
            const SizedBox(height: 14),
            _CreateExamEntry(
              course: widget.course,
              questions: _questions,
              onStart: () => setState(() => _creatingExam = true),
            ),
            const SizedBox(height: 16),
            _FilterPanel(
              search: _search,
              onSearchChanged: (v) => setState(() => _search = v),
              filterModuleId: _filterModuleId,
              onModuleChanged: (v) => setState(() => _filterModuleId = v),
              filterDiff: _filterDiff,
              onDifficultyChanged: (v) => setState(() => _filterDiff = v),
              filterType: _filterType,
              onTypeChanged: (v) => setState(() => _filterType = v),
              modules: courseState.modules,
              onClear: () => setState(() {
                _search = '';
                _filterType = null;
                _filterDiff = null;
                _filterModuleId = null;
              }),
            ),
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'Question library',
              subtitle: _loading
                  ? 'Loading questions from the database...'
                  : '${filtered.length} result${filtered.length == 1 ? '' : 's'} matching the current filters',
              trailing: _error != null
                  ? TextButton.icon(
                      onPressed: _loadQuestions,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retry'),
                    )
                  : null,
            ),
            const SizedBox(height: 10),
            if (_loading)
              const _QuestionListSkeleton()
            else if (_error != null)
              _QuestionErrorState(message: _friendlyError(_error!))
            else if (filtered.isEmpty)
              _QuestionEmptyState(hasQuestions: _questions.isNotEmpty)
            else
              _QuestionLibraryTable(questions: filtered),
          ],
        ),
      ),
    );
  }

  List<QuestionModel> _applyFilters(List<QuestionModel> input) {
    return input.where((q) {
      final s = _search.trim().toLowerCase();
      if (s.isNotEmpty) {
        final matchesText = q.text.toLowerCase().contains(s);
        final matchesTopic = (q.topicName ?? '').toLowerCase().contains(s);
        final matchesModule = (q.moduleName ?? '').toLowerCase().contains(s);
        final matchesOutcome = q.learningOutcomes.any(
          (outcome) => outcome.title.toLowerCase().contains(s),
        );
        if (!matchesText && !matchesTopic && !matchesModule && !matchesOutcome) return false;
      }
      if (_filterType != null && q.type != _filterType) return false;
      if (_filterDiff != null && q.difficulty != _filterDiff) return false;
      if (_filterModuleId != null && q.moduleId != _filterModuleId) return false;
      return true;
    }).toList();
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('session expired') || lower.contains('login again')) {
      return 'Your session expired while loading questions. Please log in again.';
    }
    return raw.trim().isNotEmpty
        ? raw
        : 'Could not load saved questions right now.';
  }
}


class _CreateExamEntry extends StatelessWidget {
  final MyCourseItem course;
  final List<QuestionModel> questions;
  final VoidCallback onStart;

  const _CreateExamEntry({
    required this.course,
    required this.questions,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create exam from question bank',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTitle,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Select saved database questions, configure quiz settings, then create the exam without changing backend APIs.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: questions.isEmpty ? null : onStart,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create Exam'),
          ),
        ],
      ),
    );
  }
}

class _QuestionLibraryHero extends StatelessWidget {
  final int total;
  final int filtered;
  final bool loading;
  final String search;
  const _QuestionLibraryHero({required this.total, required this.filtered, required this.loading, required this.search});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF145CCB), Color(0xFF2D8CFF)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.16),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _HeroPill('Library mode'),
                    _HeroPill('Browse only'),
                    _HeroPill('Database questions'),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Question Library',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Browse the stored questions already saved in your database. Use search and filters to find the right question fast.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.86),
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Container(
            width: 220,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Database status', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(loading ? 'Loading...' : '$total', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  search.trim().isEmpty ? 'saved questions available' : '$filtered result${filtered == 1 ? '' : 's'} visible',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  const _HeroPill(this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.9))),
      );
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color softColor;
  const _MiniStatCard({required this.icon, required this.label, required this.value, required this.accent, required this.softColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: softColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearchChanged;
  final int? filterModuleId;
  final ValueChanged<int?> onModuleChanged;
  final QuestionDifficulty? filterDiff;
  final ValueChanged<QuestionDifficulty?> onDifficultyChanged;
  final QuestionType? filterType;
  final ValueChanged<QuestionType?> onTypeChanged;
  final List<dynamic> modules;
  final VoidCallback onClear;

  const _FilterPanel({
    required this.search,
    required this.onSearchChanged,
    required this.filterModuleId,
    required this.onModuleChanged,
    required this.filterDiff,
    required this.onDifficultyChanged,
    required this.filterType,
    required this.onTypeChanged,
    required this.modules,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilters = search.trim().isNotEmpty || filterModuleId != null || filterDiff != null || filterType != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Search & filters', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
          const SizedBox(height: 4),
          const Text('Search the database question library by keyword, topic, module, type, or difficulty.', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: TextEditingController(text: search)
                      ..selection = TextSelection.collapsed(offset: search.length),
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search by question text, topic, or module...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      filled: true,
                      fillColor: AppColors.pageBg,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _DropFilter<int?>(
                label: 'All modules',
                value: filterModuleId,
                options: {null: 'All modules', for (final m in modules) m.id as int: m.title as String},
                onChanged: onModuleChanged,
              ),
              const SizedBox(width: 8),
              _DropFilter<QuestionDifficulty?>(
                label: 'Any difficulty',
                value: filterDiff,
                options: const {
                  null: 'Any difficulty',
                  QuestionDifficulty.easy: 'Easy',
                  QuestionDifficulty.medium: 'Medium',
                  QuestionDifficulty.hard: 'Hard',
                },
                onChanged: onDifficultyChanged,
              ),
              const SizedBox(width: 8),
              _DropFilter<QuestionType?>(
                label: 'All types',
                value: filterType,
                options: const {
                  null: 'All types',
                  QuestionType.multipleChoice: 'Multiple Choice',
                  QuestionType.trueFalse: 'True / False',
                  QuestionType.shortAnswer: 'Short Answer',
                  QuestionType.essay: 'Essay',
                  QuestionType.multiSelect: 'Multi-Select',
                },
                onChanged: onTypeChanged,
              ),
              if (hasFilters) ...[
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Clear'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  const _SectionHeader({required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      );
}


class _QuestionLibraryTable extends StatelessWidget {
  final List<QuestionModel> questions;

  const _QuestionLibraryTable({required this.questions});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE6F2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _QuestionTableHeader(),
            ...List.generate(questions.length, (index) {
              return _QuestionTableRow(
                question: questions[index],
                isLast: index == questions.length - 1,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _QuestionTableHeader extends StatelessWidget {
  const _QuestionTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 42, child: _HeaderCell('Question')),
          SizedBox(width: 18),
          Expanded(flex: 22, child: _HeaderCell('Topic')),
          SizedBox(width: 18),
          Expanded(flex: 18, child: _HeaderCell('Learning outcome')),
          SizedBox(width: 18),
          SizedBox(width: 132, child: _HeaderCell('Type')),
          SizedBox(width: 18),
          SizedBox(width: 104, child: _HeaderCell('Difficulty')),
          SizedBox(width: 18),
          SizedBox(width: 86, child: _HeaderCell('Action', alignEnd: true)),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final bool alignEnd;

  const _HeaderCell(this.label, {this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .55,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _QuestionTableRow extends StatefulWidget {
  final QuestionModel question;
  final bool isLast;

  const _QuestionTableRow({required this.question, required this.isLast});

  @override
  State<_QuestionTableRow> createState() => _QuestionTableRowState();
}

class _QuestionTableRowState extends State<_QuestionTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final topic = _topicLabel(q);
    final outcome = q.learningOutcomes.isEmpty
        ? 'No linked LO'
        : q.learningOutcomes.map((item) => item.title).take(2).join(' • ');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered ? const Color(0xFFF8FBFF) : Colors.white,
        child: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => _QuestionDetailsDialog(question: q),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              border: widget.isLast
                  ? null
                  : const Border(bottom: BorderSide(color: Color(0xFFE6EEF7))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 42,
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.help_outline_rounded,
                          size: 19,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              q.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.8,
                                height: 1.35,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textTitle,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Click to view answer details',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.2,
                                fontWeight: FontWeight.w700,
                                color: _hovered ? AppColors.primary : AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(flex: 22, child: _TableText(topic, strong: true)),
                const SizedBox(width: 18),
                Expanded(flex: 18, child: _TableText(outcome)),
                const SizedBox(width: 18),
                SizedBox(width: 132, child: Align(alignment: Alignment.centerLeft, child: _QuestionTypeBadge(q.typeLabel))),
                const SizedBox(width: 18),
                SizedBox(width: 104, child: Align(alignment: Alignment.centerLeft, child: _DifficultyBadge(q.difficulty))),
                const SizedBox(width: 18),
                SizedBox(
                  width: 86,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _ViewDetailsButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => _QuestionDetailsDialog(question: q),
                      ),
                    ),
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

class _ViewDetailsButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ViewDetailsButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(72, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        side: const BorderSide(color: Color(0xFFD6E3F1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        foregroundColor: AppColors.primary,
      ),
      child: const Text(
        'View',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _TableText extends StatelessWidget {
  final String text;
  final bool strong;

  const _TableText(this.text, {this.strong = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12.5,
        height: 1.35,
        fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
        color: strong ? AppColors.textTitle : AppColors.textMuted,
      ),
    );
  }
}

class _QuestionLibraryCard extends StatelessWidget {
  final QuestionModel question;
  const _QuestionLibraryCard({required this.question});

  @override
  Widget build(BuildContext context) {
    final topicLabel = _topicLabel(question);
    final outcomes = question.learningOutcomes;
    final outcomePreview = outcomes.isEmpty
        ? 'No linked learning outcome'
        : outcomes.map((outcome) => outcome.title).take(2).join(' • ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _QuestionDetailsDialog(question: question),
        ),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDDE7F3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.quiz_outlined,
                  size: 21,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _QuestionTypeBadge(question.typeLabel),
                        const SizedBox(width: 8),
                        _DifficultyBadge(question.difficulty),
                        const Spacer(),
                        const Icon(Icons.visibility_outlined, size: 16, color: AppColors.textHint),
                        const SizedBox(width: 5),
                        const Text(
                          'View details',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      question.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textTitle,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SummaryChip(
                          icon: Icons.topic_outlined,
                          label: topicLabel,
                          strong: true,
                        ),
                        _SummaryChip(
                          icon: Icons.flag_outlined,
                          label: outcomePreview,
                        ),
                        if (outcomes.length > 2)
                          _SummaryChip(
                            icon: Icons.more_horiz_rounded,
                            label: '+${outcomes.length - 2} more',
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
    );
  }
}

class _QuestionDetailsDialog extends StatelessWidget {
  final QuestionModel question;

  const _QuestionDetailsDialog({required this.question});

  @override
  Widget build(BuildContext context) {
    final topicLabel = _topicLabel(question);
    final expected = (question.expectedAnswer ?? '').trim();
    final hasOptions = question.options.isNotEmpty;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 18, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.quiz_outlined, color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Question Details',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textTitle,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _QuestionTypeBadge(question.typeLabel),
                            _DifficultyBadge(question.difficulty),
                            _SummaryChip(icon: Icons.topic_outlined, label: topicLabel, strong: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailsSectionCard(
                      title: 'Question',
                      child: Text(
                        question.text,
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.6,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textTitle,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _DetailsSectionCard(
                      title: 'Learning Outcomes',
                      child: question.learningOutcomes.isEmpty
                          ? const Text(
                              'No learning outcomes linked to this topic.',
                              style: TextStyle(color: AppColors.textMuted, height: 1.5),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: question.learningOutcomes
                                  .map((outcome) => _SummaryChip(icon: Icons.flag_outlined, label: outcome.title))
                                  .toList(),
                            ),
                    ),
                    if (hasOptions) ...[
                      const SizedBox(height: 14),
                      _DetailsSectionCard(
                        title: 'Answers',
                        child: Column(
                          children: question.options.map((option) {
                            final isCorrect = _isCorrectOption(question, option);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 9),
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                              decoration: BoxDecoration(
                                color: isCorrect ? const Color(0xFFECFDF3) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: isCorrect ? const Color(0xFF86EFAC) : AppColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isCorrect ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    size: 18,
                                    color: isCorrect ? const Color(0xFF16A34A) : AppColors.textHint,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      option.text,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.45,
                                        fontWeight: isCorrect ? FontWeight.w800 : FontWeight.w600,
                                        color: isCorrect ? const Color(0xFF166534) : AppColors.text,
                                      ),
                                    ),
                                  ),
                                  if (isCorrect)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: const Color(0xFFBBF7D0)),
                                      ),
                                      child: const Text(
                                        'Correct',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    if (expected.isNotEmpty && !hasOptions) ...[
                      const SizedBox(height: 14),
                      _DetailsSectionCard(
                        title: 'Expected Answer',
                        child: Text(
                          expected,
                          style: const TextStyle(fontSize: 14, height: 1.55, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    if ((question.explanation ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _DetailsSectionCard(
                        title: 'Explanation',
                        child: Text(
                          question.explanation!.trim(),
                          style: const TextStyle(fontSize: 14, height: 1.55, color: AppColors.text),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionTypeBadge extends StatelessWidget {
  final String label;
  const _QuestionTypeBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool strong;

  const _SummaryChip({
    required this.icon,
    required this.label,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: strong ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: strong ? const Color(0xFFBFDBFE) : AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: strong ? AppColors.primary : AppColors.textHint,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.4,
                color: strong ? AppColors.primary : AppColors.textMuted,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailsSectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

String _topicLabel(QuestionModel question) {
  final name = question.topicName?.trim();
  if (name != null && name.isNotEmpty) return name;
  final id = question.topicId;
  return id == null ? 'Unassigned topic' : 'Topic #$id';
}

bool _isCorrectOption(QuestionModel question, QuestionOption option) {
  final expected = (question.expectedAnswer ?? '').trim();
  final correctOptionId = question.correctOptionId?.trim();
  final optionId = option.id.trim();

  if (option.isCorrect) return true;
  if (correctOptionId != null && correctOptionId.isNotEmpty && optionId == correctOptionId) {
    return true;
  }
  if (expected.isEmpty) return false;
  if (optionId == expected) return true;
  return option.text.trim().toLowerCase() == expected.toLowerCase();
}

class _DetailsGrid extends StatelessWidget {
  final QuestionModel question;

  const _DetailsGrid({required this.question});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _DetailsPill('Course', question.courseId?.toString() ?? '-'),
        _DetailsPill('Module', question.moduleName ?? question.moduleId?.toString() ?? '-'),
        _DetailsPill('Material', question.materialName ?? question.materialId?.toString() ?? '-'),
        _DetailsPill('Topic', question.topicName ?? question.topicId?.toString() ?? '-'),
        _DetailsPill('Max score', question.maxScore.toString()),
        _DetailsPill('Auto gradable', question.autoGradable ? 'Yes' : 'No'),
      ],
    );
  }
}

class _DetailsPill extends StatelessWidget {
  final String label;
  final String value;

  const _DetailsPill(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _DetailsLabel extends StatelessWidget {
  final String text;
  const _DetailsLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final QuestionDifficulty diff;
  const _DifficultyBadge(this.diff);
  @override
  Widget build(BuildContext context) {
    switch (diff) {
      case QuestionDifficulty.easy:
        return const _MetaBadge('Easy', Color(0xFFDCFCE7), Color(0xFF16A34A));
      case QuestionDifficulty.medium:
        return const _MetaBadge('Medium', Color(0xFFFEF3C7), Color(0xFFD97706));
      case QuestionDifficulty.hard:
        return const _MetaBadge('Hard', AppColors.dangerBg, AppColors.dangerText);
    }
  }
}

class _MetaBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _MetaBadge(this.label, this.bg, this.fg);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(fontSize: 10.8, fontWeight: FontWeight.w700, color: fg)),
      );
}

class _InlineMeta extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InlineMeta({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.textHint),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11.2, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _QuestionListSkeleton extends StatelessWidget {
  const _QuestionListSkeleton();
  @override
  Widget build(BuildContext context) => Column(
        children: List.generate(
          4,
          (i) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 138,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
          ),
        ),
      );
}

class _QuestionEmptyState extends StatelessWidget {
  final bool hasQuestions;
  const _QuestionEmptyState({required this.hasQuestions});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.library_books_outlined, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              hasQuestions ? 'No questions match the current filters' : 'No saved questions in this library yet',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textTitle),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuestions
                  ? 'Try adjusting the search term, module, difficulty, or question type to see more results.'
                  : 'This page only displays questions already stored in the database. Questions will appear here once they are saved elsewhere in the system.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
            ),
          ],
        ),
      );
}

class _QuestionErrorState extends StatelessWidget {
  final String message;
  const _QuestionErrorState({required this.message});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, size: 34, color: AppColors.dangerText),
            const SizedBox(height: 12),
            const Text('Could not load question library', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.45)),
          ],
        ),
      );
}

class _DropFilter<T> extends StatelessWidget {
  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T?> onChanged;

  const _DropFilter({required this.label, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isActive = value != null;
    return GestureDetector(
      onTap: () => _showMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEFF6FF) : Colors.white,
          border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isActive ? (options[value] ?? label) : label,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isActive ? AppColors.primary : AppColors.textMuted),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: isActive ? AppColors.primary : AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    final entries = options.entries.toList();

    final result = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + size.width,
        0,
      ),
      items: List.generate(
        entries.length,
        (index) {
          final entry = entries[index];
          return PopupMenuItem<int>(
            value: index,
            child: Text(
              entry.value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: entry.key == value ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          );
        },
      ),
    );

    if (result != null) {
      onChanged(entries[result].key);
    }
  }
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
