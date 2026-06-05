import 'package:flutter/material.dart';
import 'package:learnova/shared/widgets/components/dropdowns.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../data/modules_models.dart';
import '../../data/question_models.dart';

class QuestionAuthoringTarget {
  final int? moduleId;
  final String? moduleName;
  final int? materialId;
  final String? materialName;
  final int topicId;
  final String topicName;
  final bool isSubtopic;
  final String? parentTopicName;

  const QuestionAuthoringTarget({
    this.moduleId,
    this.moduleName,
    this.materialId,
    this.materialName,
    required this.topicId,
    required this.topicName,
    this.isSubtopic = false,
    this.parentTopicName,
  });

  String get label =>
      isSubtopic && parentTopicName != null ? '$parentTopicName / $topicName' : topicName;

  String get subtitle {
    final parts = <String>[];
    if (moduleName != null && moduleName!.isNotEmpty) parts.add(moduleName!);
    if (materialName != null && materialName!.isNotEmpty) parts.add(materialName!);
    parts.add(isSubtopic ? 'Subtopic' : 'Topic');
    return parts.join(' • ');
  }
}

class AddQuestionSheet extends StatefulWidget {
  final bool isDialog;
  final int? moduleId;
  final String? moduleName;
  final int? materialId;
  final String? materialName;
  final int? topicId;
  final String? topicName;
  final List<QuestionAuthoringTarget> topicTargets;
  final List<ModuleItem> modules;
  final bool showAiHint;
  final Future<void> Function(QuestionModel question) onAdd;

  const AddQuestionSheet({
    super.key,
    this.moduleId,
    this.moduleName,
    this.materialId,
    this.materialName,
    this.topicId,
    this.topicName,
    this.topicTargets = const [],
    this.modules = const [],
    this.showAiHint = false,
    this.isDialog = false,
    required this.onAdd,
  });

  @override
  State<AddQuestionSheet> createState() => _AddQuestionSheetState();
}

class _QuestionTabSpec {
  final String label;
  final QuestionType type;

  const _QuestionTabSpec(this.label, this.type);
}

class _AddQuestionSheetState extends State<AddQuestionSheet>
    with SingleTickerProviderStateMixin {
  static const List<_QuestionTabSpec> _tabs = <_QuestionTabSpec>[
    _QuestionTabSpec('Multiple Choice', QuestionType.multipleChoice),
    _QuestionTabSpec('Multi Select', QuestionType.multiSelect),
    _QuestionTabSpec('True / False', QuestionType.trueFalse),
    _QuestionTabSpec('Short Answer', QuestionType.shortAnswer),
    _QuestionTabSpec('Essay', QuestionType.essay),
  ];

  late final TabController _tabController;

  QuestionType _type = QuestionType.multipleChoice;
  QuestionDifficulty _difficulty = QuestionDifficulty.medium;

  final TextEditingController _questionCtrl = TextEditingController();
  final TextEditingController _explanationCtrl = TextEditingController();
  final TextEditingController _answerCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  int _correctIdx = 0;
  final Set<int> _multiCorrectIndexes = <int>{0};
  bool _correctBool = true;
  bool _saving = false;
  String? _error;
  int? _selectedTopicId;

  List<QuestionAuthoringTarget> get _targets {
    if (widget.topicTargets.isNotEmpty) return widget.topicTargets;
    if (widget.topicId != null && widget.topicName != null) {
      return <QuestionAuthoringTarget>[
        QuestionAuthoringTarget(
          moduleId: widget.moduleId,
          moduleName: widget.moduleName,
          materialId: widget.materialId,
          materialName: widget.materialName,
          topicId: widget.topicId!,
          topicName: widget.topicName!,
        ),
      ];
    }
    return const <QuestionAuthoringTarget>[];
  }

  QuestionAuthoringTarget? get _selectedTarget {
    if (_targets.isEmpty) return null;
    return _targets.firstWhere(
      (QuestionAuthoringTarget t) => t.topicId == _selectedTopicId,
      orElse: () => _targets.first,
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      final QuestionType nextType = _tabs[_tabController.index].type;
      if (_type == nextType) return;
      setState(() {
        _type = nextType;
        _error = null;
      });
    });
    _selectedTopicId = widget.topicId ?? (_targets.isNotEmpty ? _targets.first.topicId : null);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _questionCtrl.dispose();
    _explanationCtrl.dispose();
    _answerCtrl.dispose();
    for (final TextEditingController controller in _optionCtrls) {
      controller.dispose();
    }
    super.dispose();
  }

  void _resetForAnother() {
    _questionCtrl.clear();
    _explanationCtrl.clear();
    _answerCtrl.clear();
    for (final TextEditingController controller in _optionCtrls) {
      controller.clear();
    }
    _correctIdx = 0;
    _multiCorrectIndexes
      ..clear()
      ..add(0);
    _correctBool = true;
    _error = null;
  }

  Future<void> _submit({required bool addAnother}) async {
    if (_saving) return;
    final String text = _questionCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Question text is required.');
      return;
    }

    if (_targets.isNotEmpty && _selectedTarget == null) {
      setState(() => _error = 'Choose where this question belongs.');
      return;
    }

    List<QuestionOption> options = <QuestionOption>[];
    String? correctOptionId;
    bool? correctBool;
    String? sampleAnswer;

    if (_type == QuestionType.multipleChoice || _type == QuestionType.multiSelect) {
      final List<TextEditingController> nonEmpty = _optionCtrls
          .where((TextEditingController c) => c.text.trim().isNotEmpty)
          .toList();
      if (nonEmpty.length < 2) {
        setState(() => _error = 'Add at least 2 answer options.');
        return;
      }
      options = nonEmpty.asMap().entries.map((MapEntry<int, TextEditingController> entry) {
        final isCorrect = _type == QuestionType.multiSelect
            ? _multiCorrectIndexes.contains(entry.key)
            : entry.key == _correctIdx;
        return QuestionOption(
          id: 'opt_${entry.key}',
          text: entry.value.text.trim(),
          isCorrect: isCorrect,
          orderIndex: entry.key,
        );
      }).toList();
      if (_type == QuestionType.multipleChoice) {
        correctOptionId = _correctIdx < options.length ? options[_correctIdx].id : options.first.id;
      } else {
        final hasValidMultiAnswer = _multiCorrectIndexes.any((idx) => idx >= 0 && idx < options.length);
        if (!hasValidMultiAnswer) {
          setState(() => _error = 'Select at least one correct answer.');
          return;
        }
      }
    } else if (_type == QuestionType.trueFalse) {
      correctBool = _correctBool;
      sampleAnswer = _correctBool ? 'True' : 'False';
    } else {
      sampleAnswer = _answerCtrl.text.trim();
    }

    final QuestionAuthoringTarget? target = _selectedTarget;
    final QuestionModel question = QuestionModel(
      id: 'q_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      type: _type,
      difficulty: _difficulty,
      options: options,
      correctOptionId: correctOptionId,
      correctBool: correctBool,
      sampleAnswer: sampleAnswer,
      explanation: _explanationCtrl.text.trim().isEmpty ? null : _explanationCtrl.text.trim(),
      moduleId: target?.moduleId ?? widget.moduleId,
      moduleName: target?.moduleName ?? widget.moduleName,
      materialId: target?.materialId ?? widget.materialId,
      materialName: target?.materialName ?? widget.materialName,
      topicId: target?.topicId ?? widget.topicId,
      topicName: target?.topicName ?? widget.topicName,
      createdAt: DateTime.now(),
    );

    setState(() => _saving = true);
    try {
      await widget.onAdd(question);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this question. Check the fields and try again.';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);

    if (addAnother) {
      setState(_resetForAnother);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(widget.isDialog ? 16 : 20),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Add New Question',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textTitle,
                          height: 1.22,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create a new assessment item for your students.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderGray),
                ),
                child: Column(
                  children: <Widget>[
                    _buildTabs(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _buildMetaSection(),
                            const SizedBox(height: 18),
                            _buildQuestionTextSection(),
                            const SizedBox(height: 18),
                            if (_type == QuestionType.multipleChoice || _type == QuestionType.multiSelect) ...<Widget>[
                              _buildMultipleChoiceSection(),
                            ] else if (_type == QuestionType.trueFalse) ...<Widget>[
                              _buildTrueFalseSection(),
                            ] else ...<Widget>[
                              _buildWrittenAnswerSection(),
                            ],
                            const SizedBox(height: 18),
                            _buildExplanationSection(),
                            if (_error != null) ...<Widget>[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: AppColors.dangerText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
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
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Row(
              children: <Widget>[
                const Spacer(),
                ElevatedButton(
                  onPressed: _saving ? null : () => _submit(addAnother: true),
                  style: _primaryButtonStyle(),
                  child: Text(_saving ? 'Adding...' : 'Add Another'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _saving ? null : () => _submit(addAnother: false),
                  style: _primaryButtonStyle(),
                  child: Text(_saving ? 'Adding...' : 'Add'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderGray)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        indicatorColor: AppColors.primary,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all<Color>(Colors.transparent),
        onTap: (int index) {
          final QuestionType nextType = _tabs[index].type;
          if (_type == nextType) return;
          setState(() {
            _type = nextType;
            _error = null;
          });
        },
        tabs: _tabs.map((_QuestionTabSpec tab) => Tab(text: tab.label)).toList(),
      ),
    );
  }

  Widget _buildMetaSection() {
    final List<Widget> fields = <Widget>[
      Expanded(
        flex: 2,
        child: _targets.isEmpty || _selectedTopicId == null
            ? const _ReadonlyField(
                label: 'Target Topic',
                value: 'No topic selected',
              )
            : _QuestionTargetPicker(
                selectedTopicId: _selectedTopicId!,
                targets: _targets,
                onChanged: (int value) {
                  setState(() => _selectedTopicId = value);
                },
              ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: AppModernDropdown<QuestionDifficulty>(
          label: 'Difficulty',
          value: _difficulty,
          icon: Icons.signal_cellular_alt_rounded,
          items: const <DropdownMenuItem<QuestionDifficulty>>[
            DropdownMenuItem<QuestionDifficulty>(
              value: QuestionDifficulty.easy,
              child: Text('Easy'),
            ),
            DropdownMenuItem<QuestionDifficulty>(
              value: QuestionDifficulty.medium,
              child: Text('Medium'),
            ),
            DropdownMenuItem<QuestionDifficulty>(
              value: QuestionDifficulty.hard,
              child: Text('Hard'),
            ),
          ],
          onChanged: (QuestionDifficulty? value) {
            if (value == null) return;
            setState(() => _difficulty = value);
          },
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: <Widget>[
              fields.first,
              const SizedBox(height: 16),
              fields.last,
            ],
          );
        }
        return Row(children: fields);
      },
    );
  }

  Widget _buildQuestionTextSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(child: _SectionLabel('Question Text')),
            TextButton.icon(
              onPressed: widget.showAiHint ? () {} : null,
              icon: const Icon(Icons.auto_awesome_outlined, size: 14),
              label: const Text('Generate with AI'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                padding: const EdgeInsets.symmetric(),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: <Widget>[
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBg,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: <Widget>[
                    const _ToolbarButton(label: 'B'),
                    const SizedBox(width: 4),
                    const _ToolbarButton(label: 'I', italic: true),
                    const SizedBox(width: 4),
                    const _ToolbarButton(label: 'U', underlined: true),
                    const SizedBox(width: 8),
                    Icon(Icons.format_list_bulleted_rounded, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 10),
                    Icon(Icons.image_outlined, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 10),
                    Icon(Icons.code_rounded, size: 16, color: AppColors.textMuted),
                    const Spacer(),
                    if (_selectedTarget != null)
                      Text(
                        _selectedTarget!.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              TextField(
                controller: _questionCtrl,
                maxLines: 5,
                decoration: _inputDecoration(
                  'Enter your question here... e.g. What is the primary function of the mitochondria?',
                ).copyWith(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMultipleChoiceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const _SectionLabel('Answer Options'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _type == QuestionType.multiSelect ? 'Select all correct answers' : 'Select the correct answer',
                style: TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List<Widget>.generate(_optionCtrls.length, (int index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 26),
                  child: _type == QuestionType.multiSelect
                      ? Checkbox(
                          value: _multiCorrectIndexes.contains(index),
                          onChanged: (value) {
                            setState(() {
                              if (value ?? false) {
                                _multiCorrectIndexes.add(index);
                              } else {
                                _multiCorrectIndexes.remove(index);
                              }
                            });
                          },
                        )
                      : InkWell(
                          onTap: () => setState(() => _correctIdx = index),
                          borderRadius: BorderRadius.circular(100),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _correctIdx == index ? AppColors.primary : AppColors.borderSoft,
                                width: _correctIdx == index ? 5 : 1.5,
                              ),
                              color: AppColors.cardBg,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Option ${String.fromCharCode(65 + index)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _optionCtrls[index],
                        decoration: _inputDecoration(
                          index == 0 ? 'Powerhouse of the cell' : 'Enter answer option',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => setState(() => _optionCtrls.add(TextEditingController())),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
          label: const Text('Add another option'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildTrueFalseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionLabel('Correct Answer'),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: _BooleanAnswerCard(
                label: 'True',
                selected: _correctBool,
                onTap: () => setState(() => _correctBool = true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BooleanAnswerCard(
                label: 'False',
                selected: !_correctBool,
                onTap: () => setState(() => _correctBool = false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWrittenAnswerSection() {
    final String hint = _type == QuestionType.essay
        ? 'Enter the expected problem-solving answer or rubric.'
        : 'Enter the expected short answer.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionLabel('Expected Answer'),
        const SizedBox(height: 10),
        TextField(
          controller: _answerCtrl,
          maxLines: 4,
          decoration: _inputDecoration(hint),
        ),
      ],
    );
  }

  Widget _buildExplanationSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SectionLabel('Explanation (Optional)'),
          const SizedBox(height: 10),
          TextField(
            controller: _explanationCtrl,
            maxLines: 3,
            decoration: _inputDecoration('Explain why the correct answer is correct...'),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                'This will be shown to students after they submit their answer.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textHint,
      ),
      filled: true,
      fillColor: AppColors.surfaceBg,
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadonlyField({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.textGray,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 44,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: AppColors.surfaceBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textGray,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionTargetPicker extends StatefulWidget {
  final int selectedTopicId;
  final List<QuestionAuthoringTarget> targets;
  final ValueChanged<int> onChanged;

  const _QuestionTargetPicker({
    required this.selectedTopicId,
    required this.targets,
    required this.onChanged,
  });

  @override
  State<_QuestionTargetPicker> createState() => _QuestionTargetPickerState();
}

class _QuestionTargetPickerState extends State<_QuestionTargetPicker> {
  bool _hovered = false;

  QuestionAuthoringTarget get _selectedTarget {
    return widget.targets.firstWhere(
      (QuestionAuthoringTarget target) => target.topicId == widget.selectedTopicId,
      orElse: () => widget.targets.first,
    );
  }

  Future<void> _openPicker() async {
    final int? result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.30),
      builder: (_) => _QuestionTargetPickerDialog(
        targets: widget.targets,
        selectedTopicId: widget.selectedTopicId,
      ),
    );
    if (result == null) return;
    widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final QuestionAuthoringTarget selected = _selectedTarget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Target Topic',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.textGray,
          ),
        ),
        const SizedBox(height: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: _openPicker,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _hovered ? AppColors.primarySoft : AppColors.surfaceBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hovered ? AppColors.primary : AppColors.border,
                  width: _hovered ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.account_tree_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selected.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textGray,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.unfold_more_rounded, color: AppColors.textMuted, size: 19),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionTargetPickerDialog extends StatefulWidget {
  final int selectedTopicId;
  final List<QuestionAuthoringTarget> targets;

  const _QuestionTargetPickerDialog({
    required this.selectedTopicId,
    required this.targets,
  });

  @override
  State<_QuestionTargetPickerDialog> createState() => _QuestionTargetPickerDialogState();
}

class _QuestionTargetPickerDialogState extends State<_QuestionTargetPickerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String query = _searchCtrl.text.trim().toLowerCase();
    final List<QuestionAuthoringTarget> filtered = widget.targets.where((QuestionAuthoringTarget target) {
      if (query.isEmpty) return true;
      return <String>[
        target.topicName,
        target.parentTopicName ?? '',
        target.materialName ?? '',
        target.moduleName ?? '',
      ].join(' ').toLowerCase().contains(query);
    }).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 14, 16),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.infoBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_tree_outlined, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Choose target topic',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textTitle,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Pick the exact topic or subtopic where this question belongs.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderGray),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
                      hintText: 'Search topic, material, or module...',
                      hintStyle: TextStyle(color: AppColors.textHint),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No matching topics found.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        children: _buildGroupedTargetRows(context, filtered),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedTargetRows(
    BuildContext context,
    List<QuestionAuthoringTarget> targets,
  ) {
    final List<Widget> rows = <Widget>[];
    String? currentModule;
    String? currentMaterial;

    for (final QuestionAuthoringTarget target in targets) {
      if (target.moduleName != currentModule) {
        currentModule = target.moduleName;
        rows.add(_groupHeader(Icons.school_outlined, currentModule ?? 'Module'));
        currentMaterial = null;
      }
      if (target.materialName != currentMaterial) {
        currentMaterial = target.materialName;
        rows.add(_groupHeader(Icons.description_outlined, currentMaterial ?? 'Material', indent: 14));
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(left: 28, top: 6),
          child: _treeOption(
            context,
            selected: widget.selectedTopicId == target.topicId,
            icon: target.isSubtopic ? Icons.subdirectory_arrow_right_rounded : Icons.topic_outlined,
            title: target.label,
            subtitle: target.subtitle,
            onTap: () => Navigator.of(context).pop(target.topicId),
          ),
        ),
      );
    }
    return rows;
  }

  Widget _groupHeader(IconData icon, String title, {double indent = 0}) {
    return Padding(
      padding: EdgeInsets.only(left: indent, top: 14, bottom: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.45,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _treeOption(
    BuildContext context, {
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.selectedBg : AppColors.surfaceBg,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? AppColors.primary.withOpacity(0.50) : AppColors.borderGray,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.cardBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: selected ? Colors.white : AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.2,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textTitle,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textTitle,
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final String label;
  final bool italic;
  final bool underlined;

  const _ToolbarButton({
    required this.label,
    this.italic = false,
    this.underlined = false,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    TextStyle style = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: AppColors.textMuted,
    );
    if (italic) {
      style = style.copyWith(fontStyle: FontStyle.italic);
    }
    if (underlined) {
      style = style.copyWith(decoration: TextDecoration.underline);
    }
    return Text(label, style: style);
  }
}

class _BooleanAnswerCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BooleanAnswerCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: selected ? AppColors.infoBg : AppColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.borderSoft,
                  width: selected ? 5 : 1.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: AppColors.textTitle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAddQuestionDialog(
  BuildContext context, {
  int? moduleId,
  String? moduleName,
  int? materialId,
  String? materialName,
  int? topicId,
  String? topicName,
  List<QuestionAuthoringTarget> topicTargets = const <QuestionAuthoringTarget>[],
  List<ModuleItem> modules = const <ModuleItem>[],
  bool showAiHint = true,
  required Future<void> Function(QuestionModel question) onAdd,
}) {
  final Size size = MediaQuery.of(context).size;
  final bool compact = size.width < 900;
  final double width = compact ? size.width * 0.94 : 860;
  final double height = size.height < 760 ? size.height * 0.94 : size.height * 0.86;

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.36),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 32,
        vertical: compact ? 18 : 36,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width,
            maxHeight: height.clamp(640.0, 820.0),
          ),
          child: AddQuestionSheet(
            isDialog: true,
            moduleId: moduleId,
            moduleName: moduleName,
            materialId: materialId,
            materialName: materialName,
            topicId: topicId,
            topicName: topicName,
            topicTargets: topicTargets,
            modules: modules,
            showAiHint: showAiHint,
            onAdd: onAdd,
          ),
        ),
      ),
    ),
  );
}
