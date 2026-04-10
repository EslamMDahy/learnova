import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../data/question_models.dart';
import '../../data/modules_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AddQuestionSheet — matches Image 3 (full-page, not bottom sheet style)
// ─────────────────────────────────────────────────────────────────────────────

class AddQuestionSheet extends StatefulWidget {
  final bool isDialog;
  final int? moduleId;
  final String? moduleName;
  final int? materialId;
  final String? materialName;
  final String? topicName;
  final List<ModuleItem> modules;
  final bool showAiHint;
  final ValueChanged<QuestionModel> onAdd;

  const AddQuestionSheet({
    super.key,
    this.moduleId,
    this.moduleName,
    this.materialId,
    this.materialName,
    this.topicName,
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

  final _questionCtrl    = TextEditingController();
  final _explanationCtrl = TextEditingController();

  // MC
  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  int _correctIdx = 0;

  // T/F
  bool _correctBool = true;

  // Short answer / Essay
  final _answerCtrl = TextEditingController();

  // Context
  int? _selectedModuleId;
  String? _error;

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
  }

  @override
  void dispose() {
    _tab.dispose();
    _questionCtrl.dispose();
    _explanationCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    _answerCtrl.dispose();
    super.dispose();
  }

  void _submit({bool addAnother = false}) {
    final text = _questionCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Question text is required.');
      return;
    }

    List<QuestionOption> options = [];
    String? correctOptionId;
    bool? correctBool;
    String? sampleAnswer;

    if (_type == QuestionType.multipleChoice) {
      final nonEmpty =
          _optionCtrls.where((c) => c.text.trim().isNotEmpty).toList();
      if (nonEmpty.length < 2) {
        setState(() => _error = 'Add at least 2 answer options.');
        return;
      }
      options = nonEmpty
          .map((c) => QuestionOption(
              id: 'opt_${nonEmpty.indexOf(c)}', text: c.text.trim(),),)
          .toList();
      correctOptionId = _correctIdx < options.length
          ? options[_correctIdx].id
          : options[0].id;
    } else if (_type == QuestionType.trueFalse) {
      correctBool = _correctBool;
    } else {
      sampleAnswer = _answerCtrl.text.trim();
    }

    final q = QuestionModel(
      id: 'q_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      type: _type,
      difficulty: _diff,
      options: options,
      correctOptionId: correctOptionId,
      correctBool: correctBool,
      sampleAnswer: sampleAnswer,
      explanation: _explanationCtrl.text.trim().isEmpty
          ? null
          : _explanationCtrl.text.trim(),
      moduleId: _selectedModuleId ?? widget.moduleId,
      moduleName: widget.moduleName,
      materialId: widget.materialId,
      materialName: widget.materialName,
      topicName: widget.topicName,
      createdAt: DateTime.now(),
    );

    widget.onAdd(q);

    if (addAnother) {
      // Reset form
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
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F8),
        borderRadius: BorderRadius.circular(widget.isDialog ? 18 : 20),
      ),
      child: Column(children: [
        if (!widget.isDialog)
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

        // White header card
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          margin: EdgeInsets.fromLTRB(0, widget.isDialog ? 0 : 10, 0, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Title row
            Row(children: [
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Add New Question',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textTitle,),),
                  SizedBox(height: 2),
                  Text('Create a new assessment item for your students.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textMuted,),),
                ],),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.textMuted, size: 20,),
                padding: EdgeInsets.zero,
              ),
            ],),
            const SizedBox(height: 12),

            // Type tabs (matching Image 3)
            TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              dividerColor: AppColors.border,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  fontFamily: 'Inter',),
              unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                  fontFamily: 'Inter',),
              tabs: const [
                Tab(text: 'Multiple Choice'),
                Tab(text: 'True / False'),
                Tab(text: 'Problem'),
                Tab(text: 'Short Answer'),
              ],
            ),
          ],),
        ),

        // Body
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Question Text card
              _FieldCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    const Text('Question Text',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTitle,),),
                    const Spacer(),
                    // "Generate with AI" button (Image 3)
                    GestureDetector(
                      onTap: _generateWithAI,
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.auto_awesome_rounded,
                            size: 13, color: AppColors.primary,),
                        SizedBox(width: 4),
                        Text('Generate with AI',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,),),
                      ],),
                    ),
                  ],),
                  const SizedBox(height: 8),

                  // Formatting toolbar (matching Image 3)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6,),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(8),),
                      border: Border(
                        top: BorderSide(color: AppColors.border),
                        left: BorderSide(color: AppColors.border),
                        right: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: const Row(children: [
                      _ToolbarBtn('B', bold: true),
                      _ToolbarBtn('I', italic: true),
                      _ToolbarBtn('U', underline: true),
                      _ToolbarDivider(),
                      _ToolbarIconBtn(Icons.format_list_bulleted_rounded),
                      _ToolbarIconBtn(Icons.image_outlined),
                      _ToolbarIconBtn(Icons.code_rounded),
                    ],),
                  ),

                  // Text input
                  TextField(
                    controller: _questionCtrl,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: const InputDecoration(
                      hintText:
                          "Enter your question here... e.g., 'What is the primary function of the mitochondria?'",
                      hintStyle: TextStyle(
                          fontSize: 13, color: AppColors.textHint,),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(8),),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(8),),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(8),),
                        borderSide: BorderSide(
                            color: AppColors.primary, width: 1.5,),
                      ),
                    ),
                  ),
                ],),
              ),
              const SizedBox(height: 12),

              // Answer section card
              _FieldCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  if (_type == QuestionType.multipleChoice)
                    _buildMCSection(),
                  if (_type == QuestionType.trueFalse) _buildTFSection(),
                  if (_type == QuestionType.shortAnswer ||
                      _type == QuestionType.essay)
                    _buildOpenSection(),
                ],),
              ),
              const SizedBox(height: 12),

              // Module context
              if (widget.moduleId == null && widget.modules.isNotEmpty)
                _FieldCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Attach to Module (optional)',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTitle,),),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int?>(
                      value: _selectedModuleId,
                      decoration: const InputDecoration(
                          hintText: 'Select a module',),
                      items: [
                        const DropdownMenuItem<int?>(
                            child: Text('No module'),),
                        ...widget.modules.map((m) =>
                            DropdownMenuItem<int?>(
                                value: m.id,
                                child: Text(m.title,
                                    overflow:
                                        TextOverflow.ellipsis,),),),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedModuleId = v),
                    ),
                  ],),
                ),

              if (widget.moduleId == null && widget.modules.isNotEmpty)
                const SizedBox(height: 12),

              // Explanation card (matching Image 3)
              _FieldCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Explanation (Optional)',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTitle,),),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _explanationCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: const InputDecoration(
                      hintText:
                          'Explain why the correct answer is correct...',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(children: [
                    Icon(Icons.info_outline_rounded,
                        size: 13, color: AppColors.textHint,),
                    SizedBox(width: 5),
                    Text(
                        'This will be shown to students after they submit their answer.',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textHint,),),
                  ],),
                ],),
              ),

              // Error
              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.dangerBorder),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        size: 14, color: AppColors.dangerText,),
                    const SizedBox(width: 8),
                    Text(_error!,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.dangerText,),),
                  ],),
                ),
              ],

              const SizedBox(height: 80), // space for bottom bar
            ],),
          ),
        ),

        // Bottom action bar (matching Image 3)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            // Save Draft
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.save_outlined, size: 15),
              label: const Text('Save Draft'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12,),
              ),
            ),
            const Spacer(),
            // Add Another
            OutlinedButton(
              onPressed: () => _submit(addAnother: true),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12,),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                side: BorderSide.none,
              ),
              child: const Text('Add Another'),
            ),
            const SizedBox(width: 10),
            // Add
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12,),
              ),
              child: const Text('Add'),
            ),
          ],),
        ),
      ],),
    );
  }

  // ── MC Section ─────────────────────────────────────────────────────────────
  Widget _buildMCSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Answer Options',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textTitle,),),
        const SizedBox(width: 10),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('Select the correct answer',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,),),
        ),
      ],),
      const SizedBox(height: 12),
      ...List.generate(_optionCtrls.length, (i) {
        final label = String.fromCharCode(65 + i); // A, B, C...
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('Option $label',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,),),
            const SizedBox(height: 4),
            Row(children: [
              GestureDetector(
                onTap: () => setState(() => _correctIdx = i),
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _correctIdx == i
                          ? AppColors.primary
                          : AppColors.border,
                      width: _correctIdx == i ? 6 : 1.5,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _optionCtrls[i],
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(
                    hintText: 'Enter answer option',
                  ),
                ),
              ),
            ],),
          ],),
        );
      }),
      if (_optionCtrls.length < 6)
        GestureDetector(
          onTap: () =>
              setState(() => _optionCtrls.add(TextEditingController())),
          child: Row(children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.primary, width: 1.5,),
              ),
              child: const Icon(Icons.add,
                  size: 12, color: AppColors.primary,),
            ),
            const SizedBox(width: 8),
            const Text('Add another option',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,),),
          ],),
        ),
    ],);
  }

  // ── T/F Section ─────────────────────────────────────────────────────────────
  Widget _buildTFSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Correct Answer',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textTitle,),),
      const SizedBox(height: 12),
      Row(children: [
        _TFOptionBtn(
          label: 'True',
          selected: _correctBool,
          onTap: () => setState(() => _correctBool = true),
        ),
        const SizedBox(width: 12),
        _TFOptionBtn(
          label: 'False',
          selected: !_correctBool,
          onTap: () => setState(() => _correctBool = false),
        ),
      ],),
    ],);
  }

  // ── Open Section ─────────────────────────────────────────────────────────────
  Widget _buildOpenSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Sample Answer (Optional)',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textTitle,),),
      const SizedBox(height: 8),
      TextField(
        controller: _answerCtrl,
        maxLines: 4,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: _type == QuestionType.shortAnswer
              ? 'Model short answer...'
              : 'Model essay structure or key points...',
        ),
      ),
    ],);
  }

  void _generateWithAI() {
    // In a real app this would call the AI endpoint
    // For now just pre-fill with a placeholder
    if (_questionCtrl.text.trim().isEmpty) {
      setState(() {
        _questionCtrl.text =
            'What is the primary function of mitochondria in a cell?';
        if (_type == QuestionType.multipleChoice &&
            _optionCtrls.isNotEmpty) {
          _optionCtrls[0].text = 'Energy production (ATP synthesis)';
          if (_optionCtrls.length > 1) {
            _optionCtrls[1].text = 'Protein synthesis';
          }
          if (_optionCtrls.length > 2) {
            _optionCtrls[2].text = 'DNA replication';
          }
          _correctIdx = 0;
        }
      });
    }
  }
}

// ── Micro widgets ─────────────────────────────────────────────────────────────

class _FieldCard extends StatelessWidget {
  final Widget child;
  const _FieldCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}

class _ToolbarBtn extends StatelessWidget {
  final String label;
  final bool bold;
  final bool italic;
  final bool underline;
  const _ToolbarBtn(this.label,
      {this.bold = false, this.italic = false, this.underline = false,});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 2),
        child: SizedBox(
          width: 26,
          height: 26,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    bold ? FontWeight.w900 : FontWeight.w500,
                fontStyle:
                    italic ? FontStyle.italic : FontStyle.normal,
                decoration: underline
                    ? TextDecoration.underline
                    : TextDecoration.none,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
      );
}

class _ToolbarIconBtn extends StatelessWidget {
  final IconData icon;
  const _ToolbarIconBtn(this.icon);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 2),
        child: SizedBox(
          width: 26,
          height: 26,
          child: Icon(icon, size: 14, color: AppColors.textMuted),
        ),
      );
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 16,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: AppColors.border,
      );
}

class _TFOptionBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TFOptionBtn(
      {required this.label,
      required this.selected,
      required this.onTap,});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFEFF6FF)
                : Colors.white,
            border: Border.all(
                color: selected
                    ? AppColors.primary
                    : AppColors.border,
                width: selected ? 1.5 : 1,),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.primary
                    : AppColors.textMuted,
              ),
            ),
          ),
        ),
      );
}


Future<void> showAddQuestionDialog(
  BuildContext context, {
  int? moduleId,
  String? moduleName,
  int? materialId,
  String? materialName,
  String? topicName,
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
            topicName: topicName,
            modules: modules,
            showAiHint: showAiHint,
            onAdd: onAdd,
          ),
        ),
      ),
    ),
  );
}
