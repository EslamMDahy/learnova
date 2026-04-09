// ─────────────────────────────────────────────────────────────────────────────
//  Course Learning Outcomes Panel
//  Reused both as an embedded tab and as a dialog from quick actions.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/ui/toast.dart';
import '../../data/learning_outcomes_models.dart';
import '../../data/modules_materials_providers.dart';

final courseLOProvider =
    StateProvider.family<List<LearningOutcome>, int>((_, __) => []);
final courseLOLoadingProvider =
    StateProvider.family<bool, int>((_, __) => false);

Future<void> ensureCourseLearningOutcomesLoaded(WidgetRef ref, int courseId) async {
  final isLoading = ref.read(courseLOLoadingProvider(courseId));
  final current = ref.read(courseLOProvider(courseId));
  if (isLoading || current.isNotEmpty) return;

  ref.read(courseLOLoadingProvider(courseId).notifier).state = true;
  try {
    final res = await ref
        .read(learningOutcomesApiProvider)
        .listOutcomes(courseId: courseId);
    ref.read(courseLOProvider(courseId).notifier).state = res.outcomes;
  } catch (_) {
    // Non-fatal: leave list empty on error
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

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: content,
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

class _CourseOutcomesContentState
    extends ConsumerState<_CourseOutcomesContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await ensureCourseLearningOutcomesLoaded(ref, widget.courseId);
  }

  Future<void> _openAddDialog() async {
    final result = await showDialog<LearningOutcome>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => const _AddOutcomeDialog(),
    );
    if (result == null || !mounted) return;
    await _addOutcome(result);
  }

  Future<void> _addOutcome(LearningOutcome lo) async {
    try {
      final saved = await ref
          .read(learningOutcomesApiProvider)
          .createOutcome(courseId: widget.courseId, outcome: lo);
      final current = ref.read(courseLOProvider(widget.courseId));
      final withCode = saved.copyWith(
          code: LearningOutcome.codeForIndex(current.length));
      ref.read(courseLOProvider(widget.courseId).notifier).state = [
        ...current,
        withCode,
      ];
      if (mounted) {
        AppToast.success(context, title: 'Outcome added', message: '${withCode.code} added successfully.');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, message: 'Failed to add outcome.');
      }
    }
  }

  Future<void> _updateOutcome(LearningOutcome lo) async {
    try {
      final updated = await ref
          .read(learningOutcomesApiProvider)
          .updateOutcome(courseId: widget.courseId, outcomeId: lo.id, outcome: lo);
      final current = ref.read(courseLOProvider(widget.courseId));
      ref.read(courseLOProvider(widget.courseId).notifier).state =
          current.map((o) => o.id == lo.id ? updated.copyWith(code: o.code) : o).toList();
      if (mounted) {
        AppToast.success(context, title: 'Saved', message: '${lo.code} updated.');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, message: 'Failed to update outcome.');
      }
    }
  }

  Future<void> _deleteOutcome(int id) async {
    try {
      await ref
          .read(learningOutcomesApiProvider)
          .deleteOutcome(courseId: widget.courseId, outcomeId: id);
      final current = ref.read(courseLOProvider(widget.courseId));
      final updated = current.where((o) => o.id != id).toList();
      for (var i = 0; i < updated.length; i++) {
        updated[i] = updated[i].copyWith(code: LearningOutcome.codeForIndex(i));
      }
      ref.read(courseLOProvider(widget.courseId).notifier).state = updated;
      if (mounted) {
        AppToast.success(context, title: 'Removed', message: 'Learning outcome removed.');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, message: 'Failed to remove outcome.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final outcomes = ref.watch(courseLOProvider(widget.courseId));
    final loading = ref.watch(courseLOLoadingProvider(widget.courseId));
    final beginnerCount = outcomes.where((o) => o.difficulty == OutcomeDifficulty.beginner).length;
    final intermediateCount = outcomes.where((o) => o.difficulty == OutcomeDifficulty.intermediate).length;
    final advancedCount = outcomes.where((o) => o.difficulty == OutcomeDifficulty.advanced).length;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF145CCB), Color(0xFF3FA9FF)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 760;
                      final textBlock = Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Learning Outcomes',
                                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Define what students should achieve by the end of this course and keep outcomes structured, measurable, and easy to manage.',
                                        style: TextStyle(fontSize: 12.5, height: 1.45, color: Colors.white.withOpacity(0.82)),
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
                                _HeroChip(label: '${outcomes.length} outcome${outcomes.length == 1 ? '' : 's'}'),
                                _HeroChip(label: '$beginnerCount beginner'),
                                _HeroChip(label: '$intermediateCount intermediate'),
                                _HeroChip(label: '$advancedCount advanced'),
                              ],
                            ),
                          ],
                        ),
                      );

                      final action = FilledButton.icon(
                        onPressed: _openAddDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Outcome'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [textBlock, const SizedBox(height: 14), action],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [textBlock, const SizedBox(width: 14), action],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _OutcomeStatCard(icon: Icons.flag_outlined, title: 'Total Outcomes', value: '${outcomes.length}', color: AppColors.primary, bg: AppColors.badgeBlueBg)),
                    const SizedBox(width: 12),
                    Expanded(child: _OutcomeStatCard(icon: Icons.trending_up_rounded, title: 'Beginner', value: '$beginnerCount', color: const Color(0xFF16A34A), bg: const Color(0xFFDCFCE7))),
                    const SizedBox(width: 12),
                    Expanded(child: _OutcomeStatCard(icon: Icons.adjust_rounded, title: 'Intermediate', value: '$intermediateCount', color: const Color(0xFFD97706), bg: const Color(0xFFFFEDD5))),
                    const SizedBox(width: 12),
                    Expanded(child: _OutcomeStatCard(icon: Icons.stars_rounded, title: 'Advanced', value: '$advancedCount', color: const Color(0xFFDC2626), bg: const Color(0xFFFEE2E2))),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : _LOBody(
                    outcomes: outcomes,
                    onEdit: (lo) async {
                      final result = await showDialog<LearningOutcome>(
                        context: context,
                        barrierColor: Colors.black.withOpacity(0.4),
                        builder: (_) => _EditLODialog(outcome: lo),
                      );
                      if (result != null) await _updateOutcome(result);
                    },
                    onDelete: _deleteOutcome,
                    onAddFirst: _openAddDialog,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Add Outcome Dialog  (professional modal, replaces the inline form)
// ─────────────────────────────────────────────────────────────────────────────
class _AddOutcomeDialog extends StatefulWidget {
  const _AddOutcomeDialog();

  @override
  State<_AddOutcomeDialog> createState() => _AddOutcomeDialogState();
}

class _AddOutcomeDialogState extends State<_AddOutcomeDialog> {
  final _titleCtrl = TextEditingController();
  OutcomeDifficulty _diff = OutcomeDifficulty.beginner;
  String? _titleError;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _titleCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _titleError = 'Outcome description is required.');
      return;
    }
    Navigator.pop(
      context,
      LearningOutcome(
        id: 0,
        title: text,
        difficulty: _diff,
      ),
    );
  }

  static Color _diffColor(OutcomeDifficulty d) {
    switch (d) {
      case OutcomeDifficulty.beginner:     return const Color(0xFF16A34A);
      case OutcomeDifficulty.intermediate: return const Color(0xFFD97706);
      case OutcomeDifficulty.advanced:     return const Color(0xFFDC2626);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.badgeBlueBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.badgeBlueBorder),
                  ),
                  child: const Icon(Icons.flag_outlined, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Add Learning Outcome',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
                    Text('Define what students will achieve',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.textMuted,
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ]),
              const SizedBox(height: 22),

              // Outcome description
              const Text('Description',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                maxLines: 3,
                minLines: 2,
                onChanged: (_) {
                  if (_titleError != null) setState(() => _titleError = null);
                },
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'e.g. Students will be able to explain the key concepts of...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint, height: 1.5),
                  errorText: _titleError,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                  errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFEF4444))),
                ),
              ),
              const SizedBox(height: 18),

              // Difficulty
              const Text('Difficulty Level',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
              const SizedBox(height: 8),
              Row(children: OutcomeDifficulty.values.map((d) {
                final sel = _diff == d;
                final color = _diffColor(d);
                return Expanded(child: Padding(
                  padding: EdgeInsets.only(right: d != OutcomeDifficulty.advanced ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _diff = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? color.withOpacity(0.09) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: sel ? color : AppColors.border, width: sel ? 1.5 : 1),
                      ),
                      alignment: Alignment.center,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(d.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: sel ? color : AppColors.textMuted,
                            )),
                      ]),
                    ),
                  ),
                ));
              }).toList()),
              const SizedBox(height: 24),

              // Actions
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textTitle,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Outcome'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LO Body (list only — add is now handled by modal)
// ─────────────────────────────────────────────────────────────────────────────
class _LOBody extends StatelessWidget {
  final List<LearningOutcome> outcomes;
  final ValueChanged<LearningOutcome> onEdit;
  final ValueChanged<int> onDelete;
  final VoidCallback onAddFirst;

  const _LOBody({
    required this.outcomes,
    required this.onEdit,
    required this.onDelete,
    required this.onAddFirst,
  });

  @override
  Widget build(BuildContext context) {
    if (outcomes.isEmpty) return _EmptyLO(onAdd: onAddFirst);

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: outcomes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) => _LOTile(
        outcome: outcomes[i],
        index: i,
        onEdit:   () => onEdit(outcomes[i]),
        onDelete: () => onDelete(outcomes[i].id),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;
  const _HeroChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      );
}

class _OutcomeStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final Color bg;

  const _OutcomeStatCard({required this.icon, required this.title, required this.value, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
                ],
              ),
            )
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Edit LO Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _EditLODialog extends StatefulWidget {
  final LearningOutcome outcome;
  const _EditLODialog({required this.outcome});

  @override
  State<_EditLODialog> createState() => _EditLODialogState();
}

class _EditLODialogState extends State<_EditLODialog> {
  late TextEditingController _ctrl;
  late OutcomeDifficulty _diff;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.outcome.title);
    _diff = widget.outcome.difficulty;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static Color _diffColor(OutcomeDifficulty d) {
    switch (d) {
      case OutcomeDifficulty.beginner:     return const Color(0xFF16A34A);
      case OutcomeDifficulty.intermediate: return const Color(0xFFD97706);
      case OutcomeDifficulty.advanced:     return const Color(0xFFDC2626);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Edit ${widget.outcome.code}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
              const Text('Update this learning outcome',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ])),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: AppColors.textMuted,
              onPressed: () => Navigator.pop(context),
              visualDensity: VisualDensity.compact,
            ),
          ]),
          const SizedBox(height: 22),

          // Description
          const Text('Description',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            minLines: 2,
            onChanged: (_) {
              if (_titleError != null) setState(() => _titleError = null);
            },
            decoration: InputDecoration(
              hintText: 'Describe the learning outcome...',
              errorText: _titleError,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
          const SizedBox(height: 18),

          // Difficulty
          const Text('Difficulty Level',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
          const SizedBox(height: 8),
          Row(children: OutcomeDifficulty.values.map((d) {
            final sel = _diff == d;
            final color = _diffColor(d);
            return Expanded(child: Padding(
              padding: EdgeInsets.only(right: d != OutcomeDifficulty.advanced ? 8 : 0),
              child: GestureDetector(
                onTap: () => setState(() => _diff = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? color.withOpacity(0.09) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: sel ? color : AppColors.border, width: sel ? 1.5 : 1),
                  ),
                  alignment: Alignment.center,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(d.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sel ? color : AppColors.textMuted,
                        )),
                  ]),
                ),
              ),
            ));
          }).toList()),
          const SizedBox(height: 24),

          // Actions
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textTitle,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () {
                final t = _ctrl.text.trim();
                if (t.isEmpty) {
                  setState(() => _titleError = 'Description is required.');
                  return;
                }
                Navigator.pop(context, widget.outcome.copyWith(title: t, difficulty: _diff));
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Save Changes'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub widgets
// ─────────────────────────────────────────────────────────────────────────────
class _LOTile extends StatelessWidget {
  final LearningOutcome outcome;
  final int index;
  final VoidCallback onEdit, onDelete;
  const _LOTile({required this.outcome, required this.index, required this.onEdit, required this.onDelete});

  Color get _diffColor {
    switch (outcome.difficulty) {
      case OutcomeDifficulty.beginner:     return const Color(0xFF16A34A);
      case OutcomeDifficulty.intermediate: return const Color(0xFFD97706);
      case OutcomeDifficulty.advanced:     return const Color(0xFFDC2626);
    }
  }

  Color get _diffBg {
    switch (outcome.difficulty) {
      case OutcomeDifficulty.beginner:     return const Color(0xFFDCFCE7);
      case OutcomeDifficulty.intermediate: return const Color(0xFFFFEDD5);
      case OutcomeDifficulty.advanced:     return const Color(0xFFFEE2E2);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.badgeBlueBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.badgeBlueBorder),
              ),
              alignment: Alignment.center,
              child: Text(
                outcome.code,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.badgeBlueFg),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(color: _diffBg, borderRadius: BorderRadius.circular(999)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 7, height: 7, decoration: BoxDecoration(color: _diffColor, shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text(outcome.difficulty.label, style: TextStyle(fontSize: 10.8, fontWeight: FontWeight.w700, color: _diffColor)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(999)),
                        child: Text('Outcome ${index + 1}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    outcome.title,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textTitle, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Row(
              children: [
                _ActionIconButton(icon: Icons.edit_outlined, color: AppColors.primary, bg: AppColors.badgeBlueBg, onTap: onEdit),
                const SizedBox(width: 8),
                _ActionIconButton(icon: Icons.delete_outline_rounded, color: AppColors.dangerText, bg: const Color(0xFFFEE2E2), onTap: onDelete),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _ActionIconButton({required this.icon, required this.color, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: color),
        ),
      );
}

class _EmptyLO extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyLO({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF145CCB), Color(0xFF3FA9FF)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.flag_rounded, size: 30, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text('No learning outcomes yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
          const SizedBox(height: 8),
          const Text(
            'Create structured learning goals so instructors and learners can clearly understand what this course is expected to achieve.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.55),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add First Outcome'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      ),
    ),
  );
}
