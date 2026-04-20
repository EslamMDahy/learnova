import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../data/question_models.dart';
import '../../data/modules_models.dart';

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

  String get label => isSubtopic && parentTopicName != null
      ? '$parentTopicName / $topicName'
      : topicName;

  String get subtitle {
    final parts = <String>[];
    if (moduleName != null && moduleName!.isNotEmpty) parts.add(moduleName!);
    if (materialName != null && materialName!.isNotEmpty) parts.add(materialName!);
    if (isSubtopic && parentTopicName != null && parentTopicName!.isNotEmpty) {
      parts.add('Subtopic');
    } else {
      parts.add('Topic');
    }
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
  final ValueChanged<QuestionModel> onAdd;

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

class _AddQuestionSheetState extends State<AddQuestionSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  QuestionType _type = QuestionType.multipleChoice;
  final QuestionDifficulty _diff = QuestionDifficulty.medium;

  final _questionCtrl = TextEditingController();
  final _explanationCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();

  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  int _correctIdx = 0;
  bool _correctBool = true;
  String? _error;
  int? _selectedModuleId;
  int? _selectedTopicId;

  List<QuestionAuthoringTarget> get _targets {
    if (widget.topicTargets.isNotEmpty) return widget.topicTargets;
    if (widget.topicId != null && widget.topicName != null) {
      return [
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
    return const [];
  }

  QuestionAuthoringTarget? get _selectedTarget {
    if (_targets.isEmpty) return null;
    return _targets.firstWhere(
      (t) => t.topicId == _selectedTopicId,
      orElse: () => _targets.first,
    );
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) return;
      setState(() {
        _type = QuestionType.values[_tab.index];
        _error = null;
      });
    });
    _selectedModuleId = widget.moduleId;
    _selectedTopicId = widget.topicId ?? (_targets.isNotEmpty ? _targets.first.topicId : null);
  }

  @override
  void dispose() {
    _tab.dispose();
    _questionCtrl.dispose();
    _explanationCtrl.dispose();
    _answerCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit({bool addAnother = false}) {
    final text = _questionCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Question text is required.');
      return;
    }

    if (_targets.isNotEmpty && _selectedTarget == null) {
      setState(() => _error = 'Choose where this question belongs.');
      return;
    }

    List<QuestionOption> options = [];
    String? correctOptionId;
    bool? correctBool;
    String? sampleAnswer;

    if (_type == QuestionType.multipleChoice) {
      final nonEmpty = _optionCtrls.where((c) => c.text.trim().isNotEmpty).toList();
      if (nonEmpty.length < 2) {
        setState(() => _error = 'Add at least 2 answer options.');
        return;
      }
      options = nonEmpty
          .asMap()
          .entries
          .map((e) => QuestionOption(id: 'opt_${e.key}', text: e.value.text.trim()))
          .toList();
      correctOptionId = _correctIdx < options.length ? options[_correctIdx].id : options.first.id;
    } else if (_type == QuestionType.trueFalse) {
      correctBool = _correctBool;
    } else {
      sampleAnswer = _answerCtrl.text.trim();
    }

    final target = _selectedTarget;
    final q = QuestionModel(
      id: 'q_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      type: _type,
      difficulty: _diff,
      options: options,
      correctOptionId: correctOptionId,
      correctBool: correctBool,
      sampleAnswer: sampleAnswer,
      explanation: _explanationCtrl.text.trim().isEmpty ? null : _explanationCtrl.text.trim(),
      moduleId: target?.moduleId ?? _selectedModuleId ?? widget.moduleId,
      moduleName: target?.moduleName ?? widget.moduleName,
      materialId: target?.materialId ?? widget.materialId,
      materialName: target?.materialName ?? widget.materialName,
      topicId: target?.topicId ?? widget.topicId,
      topicName: target?.topicName ?? widget.topicName,
      createdAt: DateTime.now(),
    );

    widget.onAdd(q);

    if (addAnother) {
      setState(() {
        _questionCtrl.clear();
        _explanationCtrl.clear();
        _answerCtrl.clear();
        for (final c in _optionCtrls) {
          c.clear();
        }
        _correctIdx = 0;
        _correctBool = true;
        _error = null;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTarget = _selectedTarget;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F8),
        borderRadius: BorderRadius.circular(widget.isDialog ? 18 : 20),
      ),
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            margin: EdgeInsets.fromLTRB(0, widget.isDialog ? 0 : 10, 0, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Add New Question', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
                    SizedBox(height: 2),
                    Text('Create a new assessment item for your students.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  ]),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                  padding: EdgeInsets.zero,
                ),
              ]),
              const SizedBox(height: 12),
              if (_targets.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.account_tree_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text('Question target', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: _selectedTopicId,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: _targets
                      .map((t) => DropdownMenuItem<int>(
                            value: t.topicId,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(t.label, overflow: TextOverflow.ellipsis),
                                Text(t.subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedTopicId = value),
                ),
                if (selectedTarget != null) ...[
                  const SizedBox(height: 8),
                  Text(selectedTarget.subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                ],
                const SizedBox(height: 14),
              ],
              TabBar(
                controller: _tab,
                isScrollable: true,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(text: 'Multiple Choice'),
                  Tab(text: 'True / False'),
                  Tab(text: 'Problem'),
                  Tab(text: 'Short Answer'),
                ],
              ),
            ]),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Expanded(
                    child: TabBarView(
                      controller: _tab,
                      children: [
                        _buildForm(),
                        _buildForm(),
                        _buildForm(),
                        _buildForm(),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _submit(addAnother: false),
                        icon: const Icon(Icons.save_outlined, size: 16),
                        label: const Text('Save Draft'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => _submit(addAnother: true),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Add Another', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => _submit(addAnother: false),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Add', style: TextStyle(color: Colors.white)),
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

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Question Text'),
          const SizedBox(height: 8),
          TextField(
            controller: _questionCtrl,
            maxLines: 4,
            decoration: _inputDecoration('Enter your question here...'),
          ),
          const SizedBox(height: 18),
          if (_type == QuestionType.multipleChoice) ...[
            Row(
              children: [
                _sectionLabel('Answer Options'),
                const SizedBox(width: 8),
                const Text('Select correct answer', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_optionCtrls.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Radio<int>(value: index, groupValue: _correctIdx, onChanged: (v) => setState(() => _correctIdx = v ?? 0)),
                    Expanded(
                      child: TextField(
                        controller: _optionCtrls[index],
                        decoration: _inputDecoration('Option ${String.fromCharCode(65 + index)}'),
                      ),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () => setState(() => _optionCtrls.add(TextEditingController())),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text('Add another option'),
            ),
          ] else if (_type == QuestionType.trueFalse) ...[
            _sectionLabel('Correct Answer'),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(value: true, label: Text('True')),
                ButtonSegment<bool>(value: false, label: Text('False')),
              ],
              selected: {_correctBool},
              onSelectionChanged: (s) => setState(() => _correctBool = s.first),
            ),
          ] else ...[
            _sectionLabel('Expected Answer'),
            const SizedBox(height: 8),
            TextField(
              controller: _answerCtrl,
              maxLines: 3,
              decoration: _inputDecoration('Explain the correct answer or rubric...'),
            ),
          ],
          const SizedBox(height: 18),
          _sectionLabel('Explanation (Optional)'),
          const SizedBox(height: 8),
          TextField(
            controller: _explanationCtrl,
            maxLines: 3,
            decoration: _inputDecoration('Explain why the correct answer is correct.'),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textTitle),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      );
}

Future<void> showAddQuestionDialog(
  BuildContext context, {
  int? moduleId,
  String? moduleName,
  int? materialId,
  String? materialName,
  int? topicId,
  String? topicName,
  List<QuestionAuthoringTarget> topicTargets = const [],
  List<ModuleItem> modules = const [],
  bool showAiHint = false,
  required ValueChanged<QuestionModel> onAdd,
}) {
  final size = MediaQuery.of(context).size;
  final width = size.width < 900 ? size.width * 0.96 : 980.0;
  final height = size.height * 0.92;

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, maxHeight: height),
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
