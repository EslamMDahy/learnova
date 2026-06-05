import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/ui/toast.dart';
import '../../data/learning_outcomes_models.dart';
import '../../data/modules_materials_providers.dart';

final courseLOProvider =
    StateProvider.family<List<LearningOutcome>, int>((_, __) => []);
final courseLOLoadingProvider = StateProvider.family<bool, int>((_, __) => false);
final courseLOErrorProvider = StateProvider.family<String?, int>((_, __) => null);

Future<void> ensureCourseLearningOutcomesLoaded(
  WidgetRef ref,
  int courseId, {
  bool force = false,
}) async {
  final isLoading = ref.read(courseLOLoadingProvider(courseId));
  final current = ref.read(courseLOProvider(courseId));
  if (isLoading || (!force && current.isNotEmpty)) return;

  ref.read(courseLOLoadingProvider(courseId).notifier).state = true;
  ref.read(courseLOErrorProvider(courseId).notifier).state = null;
  try {
    final res = await ref
        .read(learningOutcomesApiProvider)
        .listOutcomes(courseId: courseId);
    ref.read(courseLOProvider(courseId).notifier).state = res.outcomes;
  } catch (_) {
    ref.read(courseLOErrorProvider(courseId).notifier).state =
        'Could not load learning outcomes.';
  } finally {
    ref.read(courseLOLoadingProvider(courseId).notifier).state = false;
  }
}

class CourseOutcomesManager extends ConsumerWidget {
  final int courseId;
  final bool embedded;

  const CourseOutcomesManager({
    super.key,
    required this.courseId,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = _CourseOutcomesContent(
      courseId: courseId,
      embedded: embedded,
    );

    if (embedded) return content;

    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width < 1168 ? screenSize.width - 48 : 1120.0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: dialogWidth,
        height: screenSize.height * 0.86,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: content,
        ),
      ),
    );
  }
}

Future<void> showCourseOutcomesDialog(
  BuildContext context,
  WidgetRef ref,
  int courseId,
) {
  return showDialog(
    context: context,
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: CourseOutcomesManager(courseId: courseId),
    ),
  );
}

class _CourseOutcomesContent extends ConsumerStatefulWidget {
  final int courseId;
  final bool embedded;

  const _CourseOutcomesContent({
    required this.courseId,
    this.embedded = false,
  });

  @override
  ConsumerState<_CourseOutcomesContent> createState() =>
      _CourseOutcomesContentState();
}

class _CourseOutcomesContentState extends ConsumerState<_CourseOutcomesContent> {
  final TextEditingController _searchCtrl = TextEditingController();
  OutcomeDifficulty? _levelFilter;
  int? _selectedOutcomeId;
  bool _creating = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    await ensureCourseLearningOutcomesLoaded(
      ref,
      widget.courseId,
      force: force,
    );
    if (!mounted) return;
    final outcomes = ref.read(courseLOProvider(widget.courseId));
    if (outcomes.isNotEmpty && !_creating && _selectedOutcomeId == null) {
      setState(() => _selectedOutcomeId = outcomes.first.id);
    }
  }

  List<LearningOutcome> _filtered(List<LearningOutcome> outcomes) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return outcomes.where((outcome) {
      final matchesLevel = _levelFilter == null || outcome.difficulty == _levelFilter;
      if (!matchesLevel) return false;
      if (query.isEmpty) return true;
      final text = '${outcome.code} ${outcome.title} ${outcome.description ?? ''}'
          .toLowerCase();
      return text.contains(query);
    }).toList();
  }

  LearningOutcome? _selectedOutcome(List<LearningOutcome> outcomes) {
    if (outcomes.isEmpty) return null;
    if (_selectedOutcomeId != null) {
      for (final outcome in outcomes) {
        if (outcome.id == _selectedOutcomeId) return outcome;
      }
    }
    return outcomes.first;
  }

  Future<void> _createOutcome(_OutcomeDraft draft) async {
    try {
      final saved = await ref.read(learningOutcomesApiProvider).createOutcome(
            courseId: widget.courseId,
            outcome: LearningOutcome(
              id: 0,
              title: draft.title,
              description: draft.description,
              difficulty: draft.difficulty,
            ),
          );
      final current = ref.read(courseLOProvider(widget.courseId));
      final withCode = saved.copyWith(
        code: LearningOutcome.codeForIndex(current.length),
      );
      ref.read(courseLOProvider(widget.courseId).notifier).state = [
        ...current,
        withCode,
      ];
      if (mounted) {
        setState(() {
          _creating = false;
          _editing = false;
          _selectedOutcomeId = withCode.id;
        });
        AppToast.success(
          context,
          title: 'Outcome added',
          message: '${withCode.code} was added successfully.',
        );
      }
    } catch (_) {
      if (mounted) AppToast.error(context, message: 'Failed to add outcome.');
    }
  }

  Future<void> _updateOutcome(LearningOutcome existing, _OutcomeDraft draft) async {
    final payload = LearningOutcome(
      id: existing.id,
      courseId: existing.courseId,
      title: draft.title,
      description: draft.description ?? '',
      isAiGenerated: existing.isAiGenerated,
      isReviewed: existing.isReviewed,
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt,
      code: existing.code,
      difficulty: draft.difficulty,
    );

    try {
      final updated = await ref.read(learningOutcomesApiProvider).updateOutcome(
            courseId: widget.courseId,
            outcomeId: existing.id,
            outcome: payload,
          );
      final current = ref.read(courseLOProvider(widget.courseId));
      ref.read(courseLOProvider(widget.courseId).notifier).state = current
          .map((item) => item.id == existing.id
              ? updated.copyWith(code: existing.code)
              : item,)
          .toList();
      if (mounted) {
        setState(() {
          _editing = false;
          _creating = false;
          _selectedOutcomeId = existing.id;
        });
        AppToast.success(
          context,
          title: 'Saved',
          message: '${existing.code} was updated.',
        );
      }
    } catch (_) {
      if (mounted) AppToast.error(context, message: 'Failed to update outcome.');
    }
  }

  Future<void> _deleteOutcome(LearningOutcome outcome) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteOutcomeDialog(outcome: outcome),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(learningOutcomesApiProvider).deleteOutcome(
            courseId: widget.courseId,
            outcomeId: outcome.id,
          );
      final current = ref.read(courseLOProvider(widget.courseId));
      final updated = current.where((item) => item.id != outcome.id).toList();
      for (var i = 0; i < updated.length; i++) {
        updated[i] = updated[i].copyWith(code: LearningOutcome.codeForIndex(i));
      }
      ref.read(courseLOProvider(widget.courseId).notifier).state = updated;
      if (mounted) {
        setState(() {
          _editing = false;
          _creating = false;
          _selectedOutcomeId = updated.isEmpty ? null : updated.first.id;
        });
        AppToast.success(
          context,
          title: 'Removed',
          message: 'Learning outcome removed.',
        );
      }
    } catch (_) {
      if (mounted) AppToast.error(context, message: 'Failed to remove outcome.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final outcomes = ref.watch(courseLOProvider(widget.courseId));
    final loading = ref.watch(courseLOLoadingProvider(widget.courseId));
    final error = ref.watch(courseLOErrorProvider(widget.courseId));
    final visibleOutcomes = _filtered(outcomes);
    final selected = _selectedOutcome(outcomes);

    return Container(
      color: AppColors.pageBg,
      child: Padding(
        padding: widget.embedded
            ? const EdgeInsets.fromLTRB(24, 20, 24, 24)
            : const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OutcomesHeader(
              outcomes: outcomes,
              loading: loading,
              onCreate: () => setState(() {
                _creating = true;
                _editing = false;
                _selectedOutcomeId = null;
              }),
              onRefresh: () => _load(force: true),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: DecoratedBox(
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: error != null && outcomes.isEmpty
                      ? _OutcomeLoadError(
                          message: error,
                          onRetry: () => _load(force: true),
                        )
                      : _OutcomesWorkspace(
                          outcomes: outcomes,
                          visibleOutcomes: visibleOutcomes,
                          selectedOutcome: selected,
                          loading: loading,
                          searchController: _searchCtrl,
                          levelFilter: _levelFilter,
                          creating: _creating,
                          editing: _editing,
                          onFilterChanged: (value) => setState(() {
                            _levelFilter = value;
                          }),
                          onSelect: (outcome) => setState(() {
                            _selectedOutcomeId = outcome.id;
                            _creating = false;
                            _editing = false;
                          }),
                          onCreate: () => setState(() {
                            _creating = true;
                            _editing = false;
                            _selectedOutcomeId = null;
                          }),
                          onEdit: (outcome) => setState(() {
                            _selectedOutcomeId = outcome.id;
                            _creating = false;
                            _editing = true;
                          }),
                          onDelete: _deleteOutcome,
                          onCreateSubmit: _createOutcome,
                          onEditSubmit: (draft) async {
                            final current = selected;
                            if (current == null) return;
                            await _updateOutcome(current, draft);
                          },
                          onCancelEditor: () => setState(() {
                            _creating = false;
                            _editing = false;
                            if (outcomes.isNotEmpty) {
                              _selectedOutcomeId ??= outcomes.first.id;
                            }
                          }),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutcomesHeader extends StatelessWidget {
  final List<LearningOutcome> outcomes;
  final bool loading;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;

  const _OutcomesHeader({
    required this.outcomes,
    required this.loading,
    required this.onCreate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final beginner = outcomes
        .where((item) => item.difficulty == OutcomeDifficulty.beginner)
        .length;
    final intermediate = outcomes
        .where((item) => item.difficulty == OutcomeDifficulty.intermediate)
        .length;
    final advanced = outcomes
        .where((item) => item.difficulty == OutcomeDifficulty.advanced)
        .length;
    final reviewed = outcomes.where((item) => item.isReviewed).length;

    return DecoratedBox(
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.24),
                        ),
                      ),
                      child: const Icon(
                        Icons.flag_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Learning Outcomes',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Write measurable course outcomes and keep them aligned before question generation.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: Colors.white.withOpacity(0.86),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _HeaderMetric(label: 'Total', value: '${outcomes.length}'),
                    _HeaderMetric(label: 'Reviewed', value: '$reviewed'),
                    _HeaderMetric(label: 'Beginner', value: '$beginner'),
                    _HeaderMetric(label: 'Intermediate', value: '$intermediate'),
                    _HeaderMetric(label: 'Advanced', value: '$advanced'),
                  ],
                ),
              ],
            );

            final actions = Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: compact ? WrapAlignment.start : WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: loading ? null : onRefresh,
                  icon: loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    side: BorderSide(color: Colors.white.withOpacity(0.32)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Outcome'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1D4ED8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 16), actions],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: title),
                const SizedBox(width: 24),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white.withOpacity(0.82),
        ),
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(text: ' $label'),
        ],
      ),
    );
  }
}

class _OutcomesWorkspace extends StatelessWidget {
  final List<LearningOutcome> outcomes;
  final List<LearningOutcome> visibleOutcomes;
  final LearningOutcome? selectedOutcome;
  final bool loading;
  final TextEditingController searchController;
  final OutcomeDifficulty? levelFilter;
  final bool creating;
  final bool editing;
  final ValueChanged<OutcomeDifficulty?> onFilterChanged;
  final ValueChanged<LearningOutcome> onSelect;
  final VoidCallback onCreate;
  final ValueChanged<LearningOutcome> onEdit;
  final ValueChanged<LearningOutcome> onDelete;
  final ValueChanged<_OutcomeDraft> onCreateSubmit;
  final ValueChanged<_OutcomeDraft> onEditSubmit;
  final VoidCallback onCancelEditor;

  const _OutcomesWorkspace({
    required this.outcomes,
    required this.visibleOutcomes,
    required this.selectedOutcome,
    required this.loading,
    required this.searchController,
    required this.levelFilter,
    required this.creating,
    required this.editing,
    required this.onFilterChanged,
    required this.onSelect,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onCreateSubmit,
    required this.onEditSubmit,
    required this.onCancelEditor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 940;
        final listPanel = _OutcomeRegistryPanel(
          outcomes: outcomes,
          visibleOutcomes: visibleOutcomes,
          selectedOutcomeId: selectedOutcome?.id,
          loading: loading,
          searchController: searchController,
          levelFilter: levelFilter,
          onFilterChanged: onFilterChanged,
          onSelect: onSelect,
          onCreate: onCreate,
        );

        final detailPanel = _OutcomeSidePanel(
          creating: creating,
          editing: editing,
          outcome: selectedOutcome,
          onCreate: onCreate,
          onCreateSubmit: onCreateSubmit,
          onEditSubmit: onEditSubmit,
          onCancel: onCancelEditor,
          onEdit: selectedOutcome == null ? null : () => onEdit(selectedOutcome!),
          onDelete: selectedOutcome == null ? null : () => onDelete(selectedOutcome!),
        );

        if (compact) {
          return Column(
            children: [
              Expanded(flex: 6, child: listPanel),
              Divider(height: 1, color: AppColors.border),
              Expanded(flex: 5, child: detailPanel),
            ],
          );
        }

        return Row(
          children: [
            SizedBox(width: 500, child: listPanel),
            VerticalDivider(width: 1, color: AppColors.border),
            Expanded(child: detailPanel),
          ],
        );
      },
    );
  }
}

class _OutcomeRegistryPanel extends StatelessWidget {
  final List<LearningOutcome> outcomes;
  final List<LearningOutcome> visibleOutcomes;
  final int? selectedOutcomeId;
  final bool loading;
  final TextEditingController searchController;
  final OutcomeDifficulty? levelFilter;
  final ValueChanged<OutcomeDifficulty?> onFilterChanged;
  final ValueChanged<LearningOutcome> onSelect;
  final VoidCallback onCreate;

  const _OutcomeRegistryPanel({
    required this.outcomes,
    required this.visibleOutcomes,
    required this.selectedOutcomeId,
    required this.loading,
    required this.searchController,
    required this.levelFilter,
    required this.onFilterChanged,
    required this.onSelect,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search outcomes',
                        hintStyle: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
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
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _CompactAddButton(onPressed: onCreate),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _LevelFilterChip(
                      label: 'All',
                      selected: levelFilter == null,
                      onTap: () => onFilterChanged(null),
                    ),
                    const SizedBox(width: 8),
                    ...OutcomeDifficulty.values.map(
                      (level) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _LevelFilterChip(
                          label: level.label,
                          selected: levelFilter == level,
                          onTap: () => onFilterChanged(level),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: AppColors.surfaceBg,
            border: Border(
              top: BorderSide(color: AppColors.border),
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 7,
                child: Text(
                  'Outcome',
                  style: _tableHeaderStyle(),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Level',
                  style: _tableHeaderStyle(),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'State',
                  textAlign: TextAlign.right,
                  style: _tableHeaderStyle(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: loading && outcomes.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : outcomes.isEmpty
                  ? _EmptyOutcomeRegistry(onCreate: onCreate)
                  : visibleOutcomes.isEmpty
                      ? _NoOutcomeMatches(onClear: () {
                          searchController.clear();
                          onFilterChanged(null);
                        },)
                      : ListView.separated(
                          itemCount: visibleOutcomes.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: AppColors.border,
                          ),
                          itemBuilder: (context, index) {
                            final outcome = visibleOutcomes[index];
                            return _OutcomeTableRow(
                              outcome: outcome,
                              selected: outcome.id == selectedOutcomeId,
                              onTap: () => onSelect(outcome),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  static TextStyle _tableHeaderStyle() {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: AppColors.textMuted,
      letterSpacing: 0.2,
    );
  }
}

class _CompactAddButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CompactAddButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'New outcome',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _LevelFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LevelFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.selectedBg : AppColors.surfaceBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _OutcomeTableRow extends StatefulWidget {
  final LearningOutcome outcome;
  final bool selected;
  final VoidCallback onTap;

  const _OutcomeTableRow({
    required this.outcome,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_OutcomeTableRow> createState() => _OutcomeTableRowState();
}

class _OutcomeTableRowState extends State<_OutcomeTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final outcome = widget.outcome;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          color: widget.selected
              ? AppColors.selectedBg
              : _hovered
                  ? AppColors.hoverBg
                  : AppColors.cardBg,
          child: Row(
            children: [
              Expanded(
                flex: 7,
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.selected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        outcome.code.isEmpty ? 'LO' : outcome.code,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: widget.selected
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            outcome.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.3,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textTitle,
                            ),
                          ),
                          if ((outcome.description ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              outcome.description!.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _LevelBadge(level: outcome.difficulty),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: outcome.isReviewed
                      ? Icon(
                          Icons.verified_rounded,
                          size: 18,
                          color: AppColors.successText,
                        )
                      : Icon(
                          Icons.radio_button_unchecked_rounded,
                          size: 17,
                          color: AppColors.textHint,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutcomeSidePanel extends StatelessWidget {
  final bool creating;
  final bool editing;
  final LearningOutcome? outcome;
  final VoidCallback onCreate;
  final ValueChanged<_OutcomeDraft> onCreateSubmit;
  final ValueChanged<_OutcomeDraft> onEditSubmit;
  final VoidCallback onCancel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _OutcomeSidePanel({
    required this.creating,
    required this.editing,
    required this.outcome,
    required this.onCreate,
    required this.onCreateSubmit,
    required this.onEditSubmit,
    required this.onCancel,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (creating) {
      return _OutcomeEditor(
        key: const ValueKey('create-outcome'),
        mode: _OutcomeEditorMode.create,
        onSubmit: onCreateSubmit,
        onCancel: onCancel,
      );
    }

    if (editing && outcome != null) {
      return _OutcomeEditor(
        key: ValueKey('edit-outcome-${outcome!.id}'),
        mode: _OutcomeEditorMode.edit,
        initial: outcome,
        onSubmit: onEditSubmit,
        onCancel: onCancel,
      );
    }

    if (outcome == null) {
      return _OutcomeBlankPanel(onCreate: onCreate);
    }

    return _OutcomeDetailPanel(
      outcome: outcome!,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class _OutcomeDetailPanel extends StatelessWidget {
  final LearningOutcome outcome;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _OutcomeDetailPanel({
    required this.outcome,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final updated = outcome.updatedAt ?? outcome.createdAt;
    return Container(
      color: AppColors.surfaceAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            outcome.code.isEmpty ? 'Outcome' : outcome.code,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _LevelBadge(level: outcome.difficulty),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        outcome.title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                          letterSpacing: -0.45,
                          color: AppColors.textTitle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                _PanelIconButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onTap: onEdit,
                ),
                const SizedBox(width: 8),
                _PanelIconButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  danger: true,
                  onTap: onDelete,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              children: [
                _DetailSection(
                  label: 'Description',
                  child: Text(
                    (outcome.description ?? '').trim().isEmpty
                        ? 'No description added.'
                        : outcome.description!.trim(),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.65,
                      color: (outcome.description ?? '').trim().isEmpty
                          ? AppColors.textMuted
                          : AppColors.text,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                _DetailSection(
                  label: 'Metadata',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MetaBadge(
                        icon: Icons.verified_outlined,
                        label: outcome.isReviewed ? 'Reviewed' : 'Not reviewed',
                      ),
                      if (outcome.isAiGenerated)
                        const _MetaBadge(
                          icon: Icons.auto_awesome_rounded,
                          label: 'AI generated',
                        ),
                      if (updated != null)
                        _MetaBadge(
                          icon: Icons.schedule_rounded,
                          label: _formatDate(updated),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _DetailSection extends StatelessWidget {
  final String label;
  final Widget child;

  const _DetailSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback? onTap;

  const _PanelIconButton({
    required this.icon,
    required this.label,
    this.danger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.dangerText : AppColors.textTitle;
    final bg = danger ? AppColors.dangerBg : AppColors.cardBg;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: danger ? AppColors.dangerBorder : AppColors.border,
            ),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

enum _OutcomeEditorMode { create, edit }

class _OutcomeEditor extends StatefulWidget {
  final _OutcomeEditorMode mode;
  final LearningOutcome? initial;
  final ValueChanged<_OutcomeDraft> onSubmit;
  final VoidCallback onCancel;

  const _OutcomeEditor({
    super.key,
    required this.mode,
    this.initial,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<_OutcomeEditor> createState() => _OutcomeEditorState();
}

class _OutcomeEditorState extends State<_OutcomeEditor> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descriptionCtrl;
  late OutcomeDifficulty _difficulty;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleCtrl = TextEditingController(text: initial?.title ?? '');
    _descriptionCtrl = TextEditingController(text: initial?.description ?? '');
    _difficulty = initial?.difficulty ?? OutcomeDifficulty.beginner;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Outcome title is required.');
      return;
    }
    widget.onSubmit(
      _OutcomeDraft(
        title: title,
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        difficulty: _difficulty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.mode == _OutcomeEditorMode.create;
    return Container(
      color: AppColors.surfaceAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCreate ? 'New Learning Outcome' : 'Edit Learning Outcome',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.35,
                          color: AppColors.textTitle,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isCreate
                            ? 'Use one clear outcome per row. Keep it measurable.'
                            : 'Update the selected outcome without leaving the workspace.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onCancel,
                  icon: Icon(Icons.close_rounded, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              children: [
                const _FormLabel('Outcome title'),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleCtrl,
                  autofocus: true,
                  maxLines: 2,
                  minLines: 1,
                  onChanged: (_) {
                    if (_titleError != null) setState(() => _titleError = null);
                  },
                  decoration: _inputDecoration(
                    hint: 'Example: Explain core concepts of supervised learning',
                    errorText: _titleError,
                  ),
                ),
                const SizedBox(height: 20),
                const _FormLabel('Description'),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionCtrl,
                  maxLines: 5,
                  minLines: 4,
                  decoration: _inputDecoration(
                    hint: 'Add success criteria, assessment notes, or scope.',
                  ),
                ),
                const SizedBox(height: 22),
                const _FormLabel('Level'),
                const SizedBox(height: 10),
                _DifficultySelector(
                  value: _difficulty,
                  onChanged: (value) => setState(() => _difficulty = value),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textTitle,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: Icon(isCreate ? Icons.add_rounded : Icons.check_rounded,
                      size: 17,),
                  label: Text(isCreate ? 'Create Outcome' : 'Save Changes'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static InputDecoration _inputDecoration({String? hint, String? errorText}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: AppColors.textHint),
      errorText: errorText,
      filled: true,
      fillColor: AppColors.fieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.dangerText),
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String text;

  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w900,
        color: AppColors.textTitle,
      ),
    );
  }
}

class _DifficultySelector extends StatelessWidget {
  final OutcomeDifficulty value;
  final ValueChanged<OutcomeDifficulty> onChanged;

  const _DifficultySelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 440;
        final children = OutcomeDifficulty.values.map((level) {
          final selected = value == level;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: compact ? 0 : (level == OutcomeDifficulty.advanced ? 0 : 8),
                bottom: compact ? 8 : 0,
              ),
              child: InkWell(
                onTap: () => onChanged(level),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.selectedBg : AppColors.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    level.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: selected ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList();

        if (compact) return Column(children: children);
        return Row(children: children);
      },
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final OutcomeDifficulty level;

  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final colors = _levelColors(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.$2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.$3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: colors.$1, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            level.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: colors.$1,
            ),
          ),
        ],
      ),
    );
  }

  static (Color, Color, Color) _levelColors(OutcomeDifficulty level) {
    switch (level) {
      case OutcomeDifficulty.beginner:
        return (AppColors.successText, AppColors.successBg, AppColors.greenBorder);
      case OutcomeDifficulty.intermediate:
        return (AppColors.warningText, AppColors.warningBg, AppColors.warningBorder);
      case OutcomeDifficulty.advanced:
        return (AppColors.dangerText, AppColors.dangerBg, AppColors.dangerBorder);
    }
  }
}

class _EmptyOutcomeRegistry extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyOutcomeRegistry({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, size: 38, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              'No outcomes yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.textTitle,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create the first measurable outcome for this course.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('New Outcome'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoOutcomeMatches extends StatelessWidget {
  final VoidCallback onClear;

  const _NoOutcomeMatches({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 34, color: AppColors.textHint),
            const SizedBox(height: 10),
            Text(
              'No matching outcomes',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.textTitle,
              ),
            ),
            const SizedBox(height: 6),
            TextButton(onPressed: onClear, child: const Text('Clear filters')),
          ],
        ),
      ),
    );
  }
}

class _OutcomeBlankPanel extends StatelessWidget {
  final VoidCallback onCreate;

  const _OutcomeBlankPanel({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceAlt,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.article_outlined, size: 42, color: AppColors.textHint),
              const SizedBox(height: 14),
              Text(
                'Select an outcome',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textTitle,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a row from the registry or create a new outcome.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('New Outcome'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutcomeLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _OutcomeLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 38, color: AppColors.dangerText),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textTitle,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteOutcomeDialog extends StatelessWidget {
  final LearningOutcome outcome;

  const _DeleteOutcomeDialog({required this.outcome});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Delete ${outcome.code.isEmpty ? 'outcome' : outcome.code}?',
        style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w900),
      ),
      content: Text(
        'This learning outcome will be removed from the course.',
        style: TextStyle(color: AppColors.textMuted, height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.dangerText,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class _OutcomeDraft {
  final String title;
  final String? description;
  final OutcomeDifficulty difficulty;

  const _OutcomeDraft({
    required this.title,
    required this.description,
    required this.difficulty,
  });
}
