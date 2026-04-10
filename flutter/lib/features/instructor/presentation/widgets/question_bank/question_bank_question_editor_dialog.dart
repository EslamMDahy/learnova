import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../data/materials_models.dart';
import '../../../data/modules_materials_providers.dart';
import '../../../data/modules_models.dart';
import '../../../data/question_models.dart';
import '../../../data/questions_api.dart';
import '../../../data/topics_models.dart';

class QuestionBankQuestionEditorDialog extends ConsumerStatefulWidget {
  final int courseId;
  final List<QuestionAuthoringTopicTarget> topicTargets;

  const QuestionBankQuestionEditorDialog({
    super.key,
    required this.courseId,
    required this.topicTargets,
  });

  @override
  ConsumerState<QuestionBankQuestionEditorDialog> createState() =>
      _QuestionBankQuestionEditorDialogState();
}

class _QuestionBankQuestionEditorDialogState
    extends ConsumerState<QuestionBankQuestionEditorDialog> {
  final List<QuestionDraftItem> _drafts = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.topicTargets.isNotEmpty) {
      _drafts.add(QuestionDraftItem.empty(widget.topicTargets.first.topic.id));
    }
  }

  Future<void> _saveAll() async {
    if (_drafts.isEmpty || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    var successCount = 0;
    final errors = <String>[];

    for (var i = 0; i < _drafts.length; i++) {
      final draft = _drafts[i];
      final validation = draft.validate();
      if (validation != null) {
        errors.add('Question ${i + 1}: $validation');
        continue;
      }

      try {
        await ref.read(questionsApiProvider).createQuestion(
              courseId: widget.courseId,
              payload: draft.toPayload(),
            );
        successCount++;
      } catch (e) {
        errors.add('Question ${i + 1}: ${_friendlyError(e)}');
      }
    }

    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = errors.isEmpty ? null : errors.join('\n');
    });

    if (successCount > 0) {
      Navigator.of(context).pop(successCount);
    }
  }

  String _friendlyError(Object e) {
    final raw = e.toString();
    if (raw.contains('422')) return 'The backend rejected this question payload.';
    if (raw.contains('401')) return 'Your session expired.';
    return 'Could not save this question.';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 760),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Question Bank Authoring',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textTitle,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Create reusable questions for selected course topics. Every question is assigned to one exact topic before save.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted.withOpacity(0.95),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Close'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 300,
                    child: Container(
                      color: const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selected authoring scope',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textTitle,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${widget.topicTargets.length} topic target${widget.topicTargets.length == 1 ? '' : 's'} available for assignment.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: ListView.separated(
                              itemCount: widget.topicTargets.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final target = widget.topicTargets[index];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        target.topic.title,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textTitle,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        target.material.displayTitle,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textTitle,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        target.module.title,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Draft questions',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textTitle,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: widget.topicTargets.isEmpty || _saving
                                    ? null
                                    : () {
                                        setState(() {
                                          _drafts.add(QuestionDraftItem.empty(
                                            widget.topicTargets.first.topic.id,
                                          ),);
                                        });
                                      },
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Add question'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_error != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppColors.dangerBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.dangerBorder),
                              ),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.dangerText,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          Expanded(
                            child: _drafts.isEmpty
                                ? _EditorEmptyState(
                                    onAdd: widget.topicTargets.isEmpty
                                        ? null
                                        : () {
                                            setState(() {
                                              _drafts.add(QuestionDraftItem.empty(
                                                widget.topicTargets.first.topic.id,
                                              ),);
                                            });
                                          },
                                  )
                                : ListView.separated(
                                    itemCount: _drafts.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                                    itemBuilder: (context, index) {
                                      final draft = _drafts[index];
                                      return _QuestionDraftCard(
                                        key: ValueKey(draft.id),
                                        index: index,
                                        draft: draft,
                                        topicTargets: widget.topicTargets,
                                        onChanged: (next) {
                                          setState(() => _drafts[index] = next);
                                        },
                                        onDelete: _saving
                                            ? null
                                            : () {
                                                setState(() => _drafts.removeAt(index));
                                              },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Text(
                    '${_drafts.length} draft question${_drafts.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saving || _drafts.isEmpty ? null : _saveAll,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_saving ? 'Saving...' : 'Save to Question Bank'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorEmptyState extends StatelessWidget {
  final VoidCallback? onAdd;
  const _EditorEmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.edit_note_rounded, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            const Text(
              'No draft questions yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start by adding a question draft. You can create several questions in one pass and assign each one to a single topic.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.6),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add first question'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionDraftCard extends StatelessWidget {
  final int index;
  final QuestionDraftItem draft;
  final List<QuestionAuthoringTopicTarget> topicTargets;
  final ValueChanged<QuestionDraftItem> onChanged;
  final VoidCallback? onDelete;

  const _QuestionDraftCard({
    super.key,
    required this.index,
    required this.draft,
    required this.topicTargets,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final assignedTarget = topicTargets.cast<QuestionAuthoringTopicTarget?>().firstWhere(
          (element) => element?.topic.id == draft.topicId,
          orElse: () => topicTargets.isNotEmpty ? topicTargets.first : null,
        );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Question draft',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Remove draft',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  value: topicTargets.any((t) => t.topic.id == draft.topicId)
                      ? draft.topicId
                      : null,
                  decoration: _fieldDecoration('Assigned topic'),
                  items: topicTargets
                      .map(
                        (t) => DropdownMenuItem<int>(
                          value: t.topic.id,
                          child: Text('${t.module.title} · ${t.topic.title}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    onChanged(draft.copyWith(topicId: value));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<QuestionType>(
                  value: draft.type,
                  decoration: _fieldDecoration('Question type'),
                  items: const [
                    DropdownMenuItem(
                      value: QuestionType.multipleChoice,
                      child: Text('Multiple Choice'),
                    ),
                    DropdownMenuItem(
                      value: QuestionType.trueFalse,
                      child: Text('True / False'),
                    ),
                    DropdownMenuItem(
                      value: QuestionType.shortAnswer,
                      child: Text('Short Answer'),
                    ),
                    DropdownMenuItem(
                      value: QuestionType.essay,
                      child: Text('Essay'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    onChanged(draft.withType(value));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<QuestionDifficulty>(
                  value: draft.difficulty,
                  decoration: _fieldDecoration('Difficulty'),
                  items: const [
                    DropdownMenuItem(value: QuestionDifficulty.easy, child: Text('Easy')),
                    DropdownMenuItem(value: QuestionDifficulty.medium, child: Text('Medium')),
                    DropdownMenuItem(value: QuestionDifficulty.hard, child: Text('Hard')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    onChanged(draft.copyWith(difficulty: value));
                  },
                ),
              ),
            ],
          ),
          if (assignedTarget != null) ...[
            const SizedBox(height: 10),
            Text(
              'Saving under: ${assignedTarget.module.title} → ${assignedTarget.material.displayTitle} → ${assignedTarget.topic.title}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            initialValue: draft.questionText,
            decoration: _fieldDecoration('Question text'),
            minLines: 2,
            maxLines: 5,
            onChanged: (value) => onChanged(draft.copyWith(questionText: value)),
          ),
          const SizedBox(height: 12),
          if (draft.type == QuestionType.multipleChoice) ...[
            _OptionEditor(
              draft: draft,
              onChanged: onChanged,
            ),
            const SizedBox(height: 12),
          ],
          if (draft.type == QuestionType.trueFalse) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Text(
                    'Correct answer',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  ChoiceChip(
                    selected: draft.correctBool ?? false,
                    label: const Text('True'),
                    onSelected: (_) => onChanged(draft.copyWith(correctBool: true)),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    selected: draft.correctBool == false,
                    label: const Text('False'),
                    onSelected: (_) => onChanged(draft.copyWith(correctBool: false)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (draft.type == QuestionType.shortAnswer || draft.type == QuestionType.essay) ...[
            TextFormField(
              initialValue: draft.expectedAnswer,
              decoration: _fieldDecoration(
                draft.type == QuestionType.shortAnswer
                    ? 'Expected answer'
                    : 'Model answer / rubric notes',
              ),
              minLines: draft.type == QuestionType.shortAnswer ? 2 : 4,
              maxLines: draft.type == QuestionType.shortAnswer ? 4 : 6,
              onChanged: (value) => onChanged(draft.copyWith(expectedAnswer: value)),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            initialValue: draft.explanation,
            decoration: _fieldDecoration('Explanation (optional)'),
            minLines: 2,
            maxLines: 4,
            onChanged: (value) => onChanged(draft.copyWith(explanation: value)),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      );
}

class _OptionEditor extends StatelessWidget {
  final QuestionDraftItem draft;
  final ValueChanged<QuestionDraftItem> onChanged;

  const _OptionEditor({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Answer options',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: draft.options.length >= 6
                    ? null
                    : () {
                        final nextOptions = [...draft.options, ''];
                        onChanged(draft.copyWith(options: nextOptions));
                      },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add option'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(draft.options.length, (index) {
            final optionLabel = String.fromCharCode(65 + index);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Radio<int>(
                    value: index,
                    groupValue: draft.correctOptionIndex,
                    onChanged: (value) {
                      if (value == null) return;
                      onChanged(draft.copyWith(correctOptionIndex: value));
                    },
                  ),
                  Container(
                    width: 28,
                    alignment: Alignment.center,
                    child: Text(
                      optionLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: draft.options[index],
                      decoration: InputDecoration(
                        hintText: 'Option ${index + 1}',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      onChanged: (value) {
                        final nextOptions = [...draft.options];
                        nextOptions[index] = value;
                        onChanged(draft.copyWith(options: nextOptions));
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: draft.options.length <= 2
                        ? null
                        : () {
                            final nextOptions = [...draft.options]..removeAt(index);
                            final currentCorrect = draft.correctOptionIndex;
                            int? nextCorrect = currentCorrect;
                            if (currentCorrect != null) {
                              if (currentCorrect == index) {
                                nextCorrect = null;
                              } else if (currentCorrect > index) {
                                nextCorrect = currentCorrect - 1;
                              }
                            }
                            onChanged(
                              draft.copyWith(
                                options: nextOptions,
                                correctOptionIndex: nextCorrect,
                              ),
                            );
                          },
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            );
          }),
          const Text(
            'Choose the correct option using the radio button.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class QuestionAuthoringTopicTarget {
  final ModuleItem module;
  final MaterialItem material;
  final TopicItem topic;

  const QuestionAuthoringTopicTarget({
    required this.module,
    required this.material,
    required this.topic,
  });
}

class QuestionDraftItem {
  final String id;
  final int topicId;
  final QuestionType type;
  final QuestionDifficulty difficulty;
  final String questionText;
  final List<String> options;
  final int? correctOptionIndex;
  final bool? correctBool;
  final String explanation;
  final String expectedAnswer;

  const QuestionDraftItem({
    required this.id,
    required this.topicId,
    required this.type,
    required this.difficulty,
    required this.questionText,
    required this.options,
    required this.correctOptionIndex,
    required this.correctBool,
    required this.explanation,
    required this.expectedAnswer,
  });

  factory QuestionDraftItem.empty(int topicId) {
    return QuestionDraftItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      topicId: topicId,
      type: QuestionType.multipleChoice,
      difficulty: QuestionDifficulty.medium,
      questionText: '',
      options: const ['', '', '', ''],
      correctOptionIndex: null,
      correctBool: true,
      explanation: '',
      expectedAnswer: '',
    );
  }

  QuestionDraftItem copyWith({
    int? topicId,
    QuestionType? type,
    QuestionDifficulty? difficulty,
    String? questionText,
    List<String>? options,
    Object? correctOptionIndex = _unset,
    Object? correctBool = _unset,
    String? explanation,
    String? expectedAnswer,
  }) {
    return QuestionDraftItem(
      id: id,
      topicId: topicId ?? this.topicId,
      type: type ?? this.type,
      difficulty: difficulty ?? this.difficulty,
      questionText: questionText ?? this.questionText,
      options: options ?? this.options,
      correctOptionIndex: identical(correctOptionIndex, _unset)
          ? this.correctOptionIndex
          : correctOptionIndex as int?,
      correctBool: identical(correctBool, _unset)
          ? this.correctBool
          : correctBool as bool?,
      explanation: explanation ?? this.explanation,
      expectedAnswer: expectedAnswer ?? this.expectedAnswer,
    );
  }

  QuestionDraftItem withType(QuestionType nextType) {
    if (nextType == QuestionType.multipleChoice) {
      return copyWith(
        type: nextType,
        options: options.length >= 2 ? options : const ['', '', '', ''],
        correctOptionIndex: 0,
        correctBool: null,
      );
    }
    if (nextType == QuestionType.trueFalse) {
      return copyWith(
        type: nextType,
        correctBool: true,
        correctOptionIndex: null,
      );
    }
    return copyWith(
      type: nextType,
      correctOptionIndex: null,
      correctBool: null,
    );
  }

  String? validate() {
    if (questionText.trim().isEmpty) return 'Question text is required.';
    if (topicId <= 0) return 'Each question must be assigned to a topic.';
    if (type == QuestionType.multipleChoice) {
      final cleaned = options.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (cleaned.length < 2) return 'Multiple-choice questions need at least 2 options.';
      if (correctOptionIndex == null) return 'Choose the correct answer option.';
      if (correctOptionIndex! >= options.length || options[correctOptionIndex!].trim().isEmpty) {
        return 'The correct option must point to a non-empty answer.';
      }
    }
    if ((type == QuestionType.shortAnswer || type == QuestionType.essay) && expectedAnswer.trim().isEmpty) {
      return 'Provide an expected answer or rubric note.';
    }
    if (type == QuestionType.trueFalse && correctBool == null) {
      return 'Choose whether the statement is true or false.';
    }
    return null;
  }

  CreateQuestionPayload toPayload() {
    String difficultyValue;
    switch (difficulty) {
      case QuestionDifficulty.easy:
        difficultyValue = 'easy';
        break;
      case QuestionDifficulty.medium:
        difficultyValue = 'medium';
        break;
      case QuestionDifficulty.hard:
        difficultyValue = 'hard';
        break;
    }

    String typeValue;
    switch (type) {
      case QuestionType.multipleChoice:
        typeValue = 'multiple_choice';
        break;
      case QuestionType.trueFalse:
        typeValue = 'true_false';
        break;
      case QuestionType.shortAnswer:
        typeValue = 'short_answer';
        break;
      case QuestionType.essay:
        typeValue = 'essay';
        break;
      default:
        typeValue = 'short_answer';
    }

    final cleanedOptions = options
        .asMap()
        .entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .map(
          (entry) => CreateQuestionOption(
            id: String.fromCharCode(65 + entry.key),
            text: entry.value.trim(),
          ),
        )
        .toList();

    Object? expectedAnswer;
    if (type == QuestionType.multipleChoice && correctOptionIndex != null) {
      expectedAnswer = String.fromCharCode(65 + correctOptionIndex!);
    } else if (type == QuestionType.trueFalse) {
      expectedAnswer = (correctBool ?? false).toString();
    } else if (type == QuestionType.shortAnswer || type == QuestionType.essay) {
      expectedAnswer = expectedAnswerText;
    }

    return CreateQuestionPayload(
      topicId: topicId,
      questionText: questionText.trim(),
      type: typeValue,
      difficulty: difficultyValue,
      explanation: explanation.trim().isEmpty ? null : explanation.trim(),
      options: cleanedOptions.isEmpty ? null : cleanedOptions,
      expectedAnswer: expectedAnswer,
    );
  }

  String get expectedAnswerText => expectedAnswer.trim();
}

const _unset = Object();
