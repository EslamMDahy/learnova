import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../data/learning_outcomes_models.dart';
import '../../../data/topics_models.dart';

class TopicManageDialog extends StatefulWidget {
  final TopicItem topic;
  final List<LearningOutcome> outcomes;
  final Future<void> Function(TopicItem updated) onSave;
  final Future<void> Function() onDelete;

  const TopicManageDialog({
    super.key,
    required this.topic,
    required this.outcomes,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<TopicManageDialog> createState() => _TopicManageDialogState();
}

class _TopicManageDialogState extends State<TopicManageDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  late TopicReadiness _readiness;
  late TopicDifficulty _difficulty;
  late final Set<int> _selectedOutcomeIds;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.topic.title);
    _notesCtrl = TextEditingController(text: widget.topic.instructorNotes ?? '');
    _readiness = widget.topic.readiness;
    _difficulty = widget.topic.difficulty;
    _selectedOutcomeIds = {...widget.topic.learningOutcomeIds};
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x220F172A),
              blurRadius: 28,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF137FEC), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Topic',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textTitle,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Edit the essentials only: name, readiness, outcomes, and instructor notes.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _saving || _deleting ? null : () => Navigator.of(context).pop(false),
                    splashRadius: 18,
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel('Topic name'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleCtrl,
                      decoration: _inputDecoration('Write a clear, concise topic title'),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionLabel('Difficulty'),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<TopicDifficulty>(
                                value: _difficulty,
                                decoration: _inputDecoration('Select difficulty'),
                                items: TopicDifficulty.values
                                    .map<DropdownMenuItem<TopicDifficulty>>(
                                      (d) => DropdownMenuItem<TopicDifficulty>(
                                        value: d,
                                        child: Text(d.label),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _saving
                                    ? null
                                    : (TopicDifficulty? v) {
                                        if (v == null) return;
                                        setState(() => _difficulty = v);
                                      },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionLabel('Readiness'),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<TopicReadiness>(
                                value: _readiness,
                                decoration: _inputDecoration('Select readiness'),
                                items: TopicReadiness.values
                                    .map<DropdownMenuItem<TopicReadiness>>(
                                      (r) => DropdownMenuItem<TopicReadiness>(
                                        value: r,
                                        child: Text(r.label),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _saving
                                    ? null
                                    : (TopicReadiness? v) {
                                        if (v == null) return;
                                        setState(() => _readiness = v);
                                      },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const _SectionLabel('Learning outcomes'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: widget.outcomes.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No course outcomes yet. Add them from the Outcomes tab first.',
                                style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
                              ),
                            )
                          : Column(
                              children: [
                                for (int i = 0; i < widget.outcomes.length; i++) ...[
                                  _OutcomeTile(
                                    outcome: widget.outcomes[i],
                                    selected: _selectedOutcomeIds.contains(widget.outcomes[i].id),
                                    onChanged: _saving
                                        ? null
                                        : (checked) {
                                            setState(() {
                                              if (checked) {
                                                _selectedOutcomeIds.add(widget.outcomes[i].id);
                                              } else {
                                                _selectedOutcomeIds.remove(widget.outcomes[i].id);
                                              }
                                            });
                                          },
                                  ),
                                  if (i != widget.outcomes.length - 1)
                                    const Divider(height: 1, indent: 16, endIndent: 16),
                                ],
                              ],
                            ),
                    ),
                    const SizedBox(height: 18),
                    const _SectionLabel('Instructor notes'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 4,
                      decoration: _inputDecoration(
                        'Add delivery notes, examples, pitfalls, or assessment guidance.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _saving || _deleting ? null : _delete,
                    icon: _deleting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: _saving || _deleting ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _saving || _deleting ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Save changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textHint),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        widget.topic.copyWith(
          title: title,
          readiness: _readiness,
          difficulty: _difficulty,
          learningOutcomeIds: _selectedOutcomeIds.toList(),
          linkedOutcomeId: _selectedOutcomeIds.isEmpty ? null : _selectedOutcomeIds.first.toString(),
          linkedOutcomeIds: _selectedOutcomeIds.map((e) => e.toString()).toList(),
          instructorNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await widget.onDelete();
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _OutcomeTile extends StatelessWidget {
  final LearningOutcome outcome;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  const _OutcomeTile({
    required this.outcome,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
      onTap: onChanged == null ? null : () => onChanged!(!selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                outcome.code,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outcome.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTitle,
                    ),
                  ),
                  if ((outcome.description ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        outcome.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),
                ],
              ),
            ),
            Checkbox(
              value: selected,
              onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
            ),
          ],
        ),
      ),
    );
  }
}


class _ChoiceGroup<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T value) labelBuilder;
  final ValueChanged<T>? onChanged;

  const _ChoiceGroup({
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        final isSelected = value == selected;
        return ChoiceChip(
          label: Text(labelBuilder(value)),
          selected: isSelected,
          onSelected: onChanged == null ? null : (_) => onChanged!(value),
        );
      }).toList(),
    );
  }
}
