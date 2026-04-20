import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/network/error_mapper.dart';
import '../../../data/courses_models.dart';
import '../../../data/modules_materials_providers.dart';
import '../../../data/question_models.dart';
import '../../controllers/course_details_controller.dart';
import '../question_bank/question_bank_authoring_flow.dart';

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
      final resp = await ref.read(questionsApiProvider).getCourseQuestions(
            courseId: widget.course.id,
          );
      if (!mounted) return;
      setState(() {
        _questions = resp.questions;
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
    final easyCount = _questions.where((q) => q.difficulty == QuestionDifficulty.easy).length;
    final mediumCount = _questions.where((q) => q.difficulty == QuestionDifficulty.medium).length;
    final hardCount = _questions.where((q) => q.difficulty == QuestionDifficulty.hard).length;

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
            _QuestionBankAuthoringEntry(
              course: widget.course,
              onCreated: () async { await _loadQuestions(); },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MiniStatCard(
                    icon: Icons.inventory_2_outlined,
                    label: 'Saved questions',
                    value: '${_questions.length}',
                    accent: AppColors.primary,
                    softColor: const Color(0xFFEFF6FF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStatCard(
                    icon: Icons.sentiment_satisfied_alt_rounded,
                    label: 'Easy',
                    value: '$easyCount',
                    accent: const Color(0xFF16A34A),
                    softColor: const Color(0xFFDCFCE7),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStatCard(
                    icon: Icons.tune_rounded,
                    label: 'Medium',
                    value: '$mediumCount',
                    accent: const Color(0xFFD97706),
                    softColor: const Color(0xFFFEF3C7),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStatCard(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Hard',
                    value: '$hardCount',
                    accent: AppColors.dangerText,
                    softColor: AppColors.dangerBg,
                  ),
                ),
              ],
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
              ...filtered.map((q) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _QuestionLibraryCard(question: q),
                  )),
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
        if (!matchesText && !matchesTopic && !matchesModule) return false;
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


class _QuestionBankAuthoringEntry extends StatelessWidget {
  final MyCourseItem course;
  final Future<void> Function()? onCreated;

  const _QuestionBankAuthoringEntry({
    required this.course,
    this.onCreated,
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
              Icons.add_task_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Question Bank questions',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTitle,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Select modules, materials, and topics from the course structure, then author reusable questions mapped to one exact topic each.',
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
            onPressed: () async {
              final savedCount = await showDialog<int>(
                context: context,
                barrierDismissible: false,
                builder: (_) => QuestionBankAuthoringFlow(course: course),
              );

              if (savedCount != null && savedCount > 0 && onCreated != null) {
                await onCreated!.call();
              }
            },
            icon: const Icon(Icons.auto_awesome_mosaic_rounded, size: 18),
            label: const Text('Start authoring'),
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

class _QuestionLibraryCard extends StatelessWidget {
  final QuestionModel question;
  const _QuestionLibraryCard({required this.question});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.quiz_outlined, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _MetaBadge(question.typeLabel, const Color(0xFFF8FAFC), AppColors.textMuted),
                        const SizedBox(width: 6),
                        _DifficultyBadge(question.difficulty),
                        if ((question.topicName ?? '').isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _MetaBadge(question.topicName!, const Color(0xFFEFF6FF), AppColors.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      question.text,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textTitle, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InlineMeta(icon: Icons.account_tree_outlined, label: question.moduleName ?? 'Module not specified'),
              _InlineMeta(icon: Icons.menu_book_outlined, label: question.contextLabel),
              _InlineMeta(icon: Icons.schedule_rounded, label: _formatDate(question.createdAt)),
              _InlineMeta(icon: Icons.repeat_rounded, label: '${question.usageCount} uses'),
            ],
          ),
          if (question.options.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFBFD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Preview choices', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  ...question.options.take(4).map((opt) {
                    final isCorrect = opt.id == question.correctOptionId || opt.isCorrect;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            isCorrect ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: 14,
                            color: isCorrect ? const Color(0xFF16A34A) : AppColors.textHint,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              opt.text,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isCorrect ? const Color(0xFF166534) : AppColors.textMuted,
                                fontWeight: isCorrect ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
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

    final result = await showMenu<T>(
      context: context,
      position: RelativeRect.fromLTRB(offset.dx, offset.dy + size.height, offset.dx + size.width, 0),
      items: options.entries
          .map(
            (e) => PopupMenuItem<T>(
              value: e.key,
              child: Text(
                e.value,
                style: TextStyle(fontSize: 13, fontWeight: e.key == value ? FontWeight.w700 : FontWeight.w400),
              ),
            ),
          )
          .toList(),
    );
    if (result != null) onChanged(result);
  }
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
