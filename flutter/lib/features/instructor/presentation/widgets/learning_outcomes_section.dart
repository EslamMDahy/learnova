import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/components/buttons.dart';
import '../../data/learning_outcomes_models.dart';

class LearningOutcomesSection extends StatefulWidget {
  final List<LearningOutcome> initialOutcomes;
  final ValueChanged<List<LearningOutcome>> onChanged;

  const LearningOutcomesSection({
    super.key,
    required this.initialOutcomes,
    required this.onChanged,
  });

  @override
  State<LearningOutcomesSection> createState() => _LearningOutcomesSectionState();
}

class _LearningOutcomesSectionState extends State<LearningOutcomesSection> {
  late List<LearningOutcome> _outcomes;
  final _descCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _isFocused = false;
  OutcomeDifficulty _selectedDiff = OutcomeDifficulty.beginner;
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    _outcomes = List.from(widget.initialOutcomes);
    _counter = _outcomes.length;
    _focusNode.addListener(() => setState(() => _isFocused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _add() {
    final text = _descCtrl.text.trim();
    if (text.isEmpty) return;
    final lo = LearningOutcome(
      id: 0,  // backend will assign the real id
      code: LearningOutcome.codeForIndex(_counter),
      title: text,
      difficulty: _selectedDiff,
    );
    setState(() {
      _outcomes = [..._outcomes, lo];
      _counter++;
      _descCtrl.clear();
      _selectedDiff = OutcomeDifficulty.beginner;
    });
    widget.onChanged(_outcomes);
    _focusNode.requestFocus();
  }

  void _delete(int id) {
    setState(() {
      _outcomes = _outcomes.where((o) => o.id != id).toList();
      _outcomes = List.generate(
        _outcomes.length,
        (i) => _outcomes[i].copyWith(code: LearningOutcome.codeForIndex(i)),
      );
    });
    widget.onChanged(_outcomes);
  }

  void _editOutcome(LearningOutcome lo) async {
    final result = await showDialog<LearningOutcome>(
      context: context,
      builder: (_) => _EditOutcomeDialog(outcome: lo),
    );
    if (result == null || !mounted) return;
    setState(() {
      _outcomes = _outcomes.map((o) => o.id == lo.id ? result : o).toList();
    });
    widget.onChanged(_outcomes);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Outcomes list ────────────────────────────────────────────────────
      if (_outcomes.isEmpty)
        _EmptyHint()
      else
        ...List.generate(_outcomes.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _OutcomeTile(
            outcome: _outcomes[i],
            onEdit:   () => _editOutcome(_outcomes[i]),
            onDelete: () => _delete(_outcomes[i].id),
          ),
        )),

      const SizedBox(height: 10),

      // ── Input card ───────────────────────────────────────────────────────
      AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isFocused ? AppColors.primary : AppColors.borderSoft,
            width: _isFocused ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 1)),
            if (_isFocused)
              BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Difficulty label + chips row
          Row(children: [
            Text('Difficulty',
                style: AppText.label.copyWith(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.textTitle)),
            const SizedBox(width: 12),
            ...OutcomeDifficulty.values.map((d) {
              final sel   = _selectedDiff == d;
              final color = _diffColor(d);
              return Padding(
                padding: EdgeInsets.only(right: d != OutcomeDifficulty.advanced ? 6 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDiff = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? color.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? color : AppColors.border,
                          width: sel ? 1.5 : 1),
                    ),
                    child: Text(d.label, style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w600,
                        color: sel ? color : AppColors.textMuted)),
                  ),
                ),
              );
            }),
          ]),

          const SizedBox(height: 10),

          // Description input row
          Row(children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.pageBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: _descCtrl,
                  focusNode: _focusNode,
                  onSubmitted: (_) => _add(),
                  style: AppText.input.copyWith(fontSize: 13),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: 'e.g. Understand database normalization',
                    hintStyle: AppText.hint.copyWith(fontSize: 13),
                    border: InputBorder.none,
                    isCollapsed: true,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40, height: 40,
              child: AppButton(
                label: '+',
                onTap: _add,
                height: 40,
                padding: EdgeInsets.zero,
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }

  static Color _diffColor(OutcomeDifficulty d) {
    switch (d) {
      case OutcomeDifficulty.beginner:     return const Color(0xFF16A34A);
      case OutcomeDifficulty.intermediate: return const Color(0xFFD97706);
      case OutcomeDifficulty.advanced:     return const Color(0xFFDC2626);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Edit Outcome Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _EditOutcomeDialog extends StatefulWidget {
  final LearningOutcome outcome;
  const _EditOutcomeDialog({required this.outcome});
  @override
  State<_EditOutcomeDialog> createState() => _EditOutcomeDialogState();
}

class _EditOutcomeDialogState extends State<_EditOutcomeDialog> {
  late TextEditingController _ctrl;
  late OutcomeDifficulty _diff;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.outcome.title);
    _diff = widget.outcome.difficulty;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Title
            Text('Edit ${widget.outcome.code}',
                style: AppText.h1.copyWith(fontSize: 17, color: AppColors.textTitle)),
            const SizedBox(height: 18),

            // Description label + input
            Text('Description', style: AppText.label.copyWith(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSoft),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: TextField(
                controller: _ctrl,
                maxLines: 3,
                style: AppText.input.copyWith(fontSize: 13, height: 1.5),
                decoration: InputDecoration(
                  hintText: 'Describe what students will achieve...',
                  hintStyle: AppText.hint.copyWith(fontSize: 13),
                  border: InputBorder.none,
                  isCollapsed: true,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Difficulty label + chips
            Text('Difficulty', style: AppText.label.copyWith(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
            const SizedBox(height: 8),
            Row(children: OutcomeDifficulty.values.map((d) {
              final sel   = _diff == d;
              final color = _diffColor(d);
              return Expanded(child: Padding(
                padding: EdgeInsets.only(right: d != OutcomeDifficulty.advanced ? 8 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _diff = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? color.withOpacity(0.08) : AppColors.pageBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sel ? color : AppColors.border, width: sel ? 1.5 : 1),
                    ),
                    alignment: Alignment.center,
                    child: Text(d.label, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: sel ? color : AppColors.textMuted)),
                  ),
                ),
              ));
            }).toList()),

            const SizedBox(height: 22),

            // Footer buttons
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              AppButton(
                label: 'Cancel',
                onTap: () => Navigator.pop(context),
                variant: AppButtonVariant.soft,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              const SizedBox(width: 8),
              AppButton(
                label: 'Save',
                onTap: () {
                  final t = _ctrl.text.trim();
                  if (t.isEmpty) return;
                  Navigator.pop(context,
                      widget.outcome.copyWith(title: t, difficulty: _diff));
                },
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
            ]),
          ]),
        ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  _OutcomeTile
// ─────────────────────────────────────────────────────────────────────────────
class _OutcomeTile extends StatelessWidget {
  final LearningOutcome outcome;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _OutcomeTile({required this.outcome, required this.onEdit, required this.onDelete});

  static Color _diffColor(OutcomeDifficulty d) {
    switch (d) {
      case OutcomeDifficulty.beginner:     return const Color(0xFF16A34A);
      case OutcomeDifficulty.intermediate: return const Color(0xFFD97706);
      case OutcomeDifficulty.advanced:     return const Color(0xFFDC2626);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diffColor = _diffColor(outcome.difficulty);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        // LO code badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.badgeBlueBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.badgeBlueBorder),
          ),
          child: Text(outcome.code, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.badgeBlueFg)),
        ),
        const SizedBox(width: 8),

        // Difficulty chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: diffColor.withOpacity(0.09),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(outcome.difficulty.label, style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: diffColor)),
        ),
        const SizedBox(width: 10),

        // Description
        Expanded(child: Text(outcome.title,
            style: AppText.input.copyWith(fontSize: 12.5, height: 1.4))),

        // Edit
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 15),
          color: AppColors.muted,
          tooltip: 'Edit',
          visualDensity: VisualDensity.compact,
          onPressed: onEdit,
        ),

        // Delete
        IconButton(
          icon: const Icon(Icons.close, size: 15),
          color: AppColors.dangerText,
          tooltip: 'Remove',
          visualDensity: VisualDensity.compact,
          onPressed: onDelete,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _EmptyHint
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    decoration: BoxDecoration(
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(children: [
      const Icon(Icons.info_outline, size: 14, color: AppColors.hint),
      const SizedBox(width: 8),
      Expanded(child: Text(
        'No outcomes added yet. Add learning outcomes to guide students and link topics.',
        style: AppText.mutedSmall.copyWith(fontSize: 12, height: 1.5),
      )),
    ]),
  );
}
