import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/error_mapper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../data/courses_models.dart';
import '../../../data/exam_models.dart';
import '../../../data/modules_materials_providers.dart';
import '../../../data/question_models.dart';
import '../../../data/question_vocabulary.dart';

Future<bool?> showCreateExamFlowDialog({
  required BuildContext context,
  required MyCourseItem course,
  required List<QuestionModel> questions,
  VoidCallback? onCancel,
  VoidCallback? onCreated,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog.fullscreen(
      child: CreateExamFlow(
        course: course,
        questions: questions,
        onCancel: onCancel,
        onCreated: onCreated,
      ),
    ),
  );
}

class CreateExamFlow extends ConsumerStatefulWidget {
  final MyCourseItem course;
  final List<QuestionModel> questions;
  final VoidCallback? onCancel;
  final VoidCallback? onCreated;

  const CreateExamFlow({
    super.key,
    required this.course,
    required this.questions,
    this.onCancel,
    this.onCreated,
  });

  @override
  ConsumerState<CreateExamFlow> createState() => _CreateExamFlowState();
}

class _CreateExamFlowState extends ConsumerState<CreateExamFlow> {
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '60');
  final _searchCtrl = TextEditingController();

  int _step = 1;
  int _maxAttempts = 1;
  bool _shuffleQuestions = true;
  bool _shuffleOptions = false;
  bool _saving = false;
  String? _error;
  String _difficultyFilter = 'all';
  String _typeFilter = 'all';
  final Set<int> _selectedQuestionIds = <int>{};

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _instructionsCtrl.dispose();
    _durationCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<QuestionModel> get _savedQuestions {
    return widget.questions.where((q) => q.remoteId != null).toList();
  }

  List<QuestionModel> get _filteredQuestions {
    final search = _searchCtrl.text.trim().toLowerCase();
    return _savedQuestions.where((q) {
      if (search.isNotEmpty) {
        final matchText = q.text.toLowerCase().contains(search);
        final matchTopic = (q.topicName ?? '').toLowerCase().contains(search);
        final matchModule = (q.moduleName ?? '').toLowerCase().contains(search);
        if (!matchText && !matchTopic && !matchModule) return false;
      }
      if (_difficultyFilter != 'all' && q.difficulty.backendValue != _difficultyFilter) {
        return false;
      }
      if (_typeFilter != 'all' && q.type.backendValue != _typeFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  int get _selectedCount => _selectedQuestionIds.length;

  void _cancelFlow() {
    if (_saving) return;
    widget.onCancel?.call();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(false);
    }
  }

  void _finishFlow() {
    widget.onCreated?.call();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _next() async {
    setState(() => _error = null);
    if (_step == 1) {
      if (_titleCtrl.text.trim().isEmpty) {
        setState(() => _error = 'Exam title is required.');
        return;
      }
      setState(() => _step = 2);
      return;
    }
    if (_step == 2) {
      if (_selectedQuestionIds.isEmpty) {
        setState(() => _error = 'Select at least one saved question.');
        return;
      }
      setState(() => _step = 3);
      return;
    }
    await _createExam();
  }

  void _back() {
    if (_saving) return;
    if (_step == 1) {
      _cancelFlow();
      return;
    }
    setState(() {
      _step -= 1;
      _error = null;
    });
  }

  Future<void> _createExam() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final duration = int.tryParse(_durationCtrl.text.trim());
      final exam = await ref.read(examsApiProvider).createExam(
            courseId: widget.course.id,
            payload: ExamCreatePayload(
              title: _titleCtrl.text.trim(),
              description: _emptyToNull(_descriptionCtrl.text),
              instructions: _emptyToNull(_instructionsCtrl.text),
              examType: 'quiz',
              durationMinutes: duration != null && duration > 0 ? duration : null,
              maxAttempts: _maxAttempts,
              shuffleQuestions: _shuffleQuestions,
              shuffleOptions: _shuffleOptions,
            ),
          );

      await ref.read(examsApiProvider).addQuestions(
            courseId: widget.course.id,
            examId: exam.id,
            questionIds: _selectedQuestionIds.toList(),
          );

      if (!mounted) return;
      _finishFlow();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = mapApiFailure(e).message;
      });
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredQuestions;
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 38, 28, 44),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleBlock(),
                  const SizedBox(height: 24),
                  _buildStepper(),
                  const SizedBox(height: 30),
                  if (_error != null) ...[
                    _ErrorBanner(message: _error!),
                    const SizedBox(height: 18),
                  ],
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 140),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: KeyedSubtree(
                      key: ValueKey<int>(_step),
                      child: switch (_step) {
                        1 => _buildBasicDetails(),
                        2 => _buildQuestionSelection(filtered),
                        _ => _buildSettings(),
                      },
                    ),
                  ),
                  const SizedBox(height: 26),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _saving ? null : _cancelFlow,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
          ),
          const SizedBox(width: 8),
          const Text(
            'Create Exam',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          Text(
            widget.course.title,
            style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBlock() {
    final subtitle = switch (_step) {
      1 => 'Basic Details',
      2 => 'Add Questions',
      _ => 'Settings',
    };
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create New Exam',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text('Step $_step: $subtitle', style: const TextStyle(color: AppColors.textMuted)),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _saving ? null : _cancelFlow,
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('Save Draft'),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _saving ? null : _createExam,
          icon: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.rocket_launch_outlined, size: 16),
          label: Text(_saving ? 'Publishing...' : 'Publish Quiz'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildStepper() {
    return Row(
      children: [
        _StepChip(index: 1, label: 'Basic Details', active: _step == 1, done: _step > 1),
        _StepLine(active: _step > 1),
        _StepChip(index: 2, label: 'Add Questions', active: _step == 2, done: _step > 2),
        _StepLine(active: _step > 2),
        _StepChip(index: 3, label: 'Settings', active: _step == 3, done: false),
      ],
    );
  }

  Widget _buildBasicDetails() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('Quiz Title *'),
          TextField(
            controller: _titleCtrl,
            decoration: _input('e.g., Midterm Exam - ${widget.course.title}'),
          ),
          const SizedBox(height: 20),
          _Label('Description'),
          TextField(
            controller: _descriptionCtrl,
            maxLines: 3,
            decoration: _input('Short description visible to students...'),
          ),
          const SizedBox(height: 20),
          _Label('Instructions'),
          TextField(
            controller: _instructionsCtrl,
            maxLines: 5,
            decoration: _input('Enter detailed instructions here...'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('Exam Category'),
                    DropdownButtonFormField<String>(
                      value: 'quiz',
                      decoration: _input('Quiz'),
                      items: const [DropdownMenuItem(value: 'quiz', child: Text('Quiz'))],
                      onChanged: null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('Available Question Bank'),
                    TextField(
                      enabled: false,
                      controller: TextEditingController(text: '${_savedQuestions.length} saved questions'),
                      decoration: _input('Saved questions'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionSelection(List<QuestionModel> filtered) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _Card(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: _input('Search questions by keyword, topic, or module').copyWith(
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _difficultyFilter,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Any Difficulty')),
                        DropdownMenuItem(value: 'easy', child: Text('Easy')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'hard', child: Text('Hard')),
                      ],
                      onChanged: (value) => setState(() => _difficultyFilter = value ?? 'all'),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _typeFilter,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Types')),
                        DropdownMenuItem(value: 'multiple_choice', child: Text('Multiple Choice')),
                        DropdownMenuItem(value: 'multi_select', child: Text('Multi Select')),
                        DropdownMenuItem(value: 'true_false', child: Text('True / False')),
                        DropdownMenuItem(value: 'short_answer', child: Text('Short Answer')),
                        DropdownMenuItem(value: 'essay', child: Text('Essay')),
                      ],
                      onChanged: (value) => setState(() => _typeFilter = value ?? 'all'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_savedQuestions.isEmpty)
                const _EmptyExamQuestions()
              else
                ...filtered.map((q) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SelectableQuestionCard(
                        question: q,
                        selected: _selectedQuestionIds.contains(q.remoteId),
                        onChanged: (selected) {
                          final id = q.remoteId;
                          if (id == null) return;
                          setState(() {
                            if (selected) {
                              _selectedQuestionIds.add(id);
                            } else {
                              _selectedQuestionIds.remove(id);
                            }
                          });
                        },
                      ),
                    )),
            ],
          ),
        ),
        const SizedBox(width: 24),
        SizedBox(width: 320, child: _buildSummaryCard()),
      ],
    );
  }

  Widget _buildSettings() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(icon: Icons.timer_outlined, title: 'Timing & Attempts'),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Label('Time Limit'),
                              TextField(
                                controller: _durationCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _input('60').copyWith(suffixText: 'Minutes'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Label('Allowed Attempts'),
                              DropdownButtonFormField<int>(
                                value: _maxAttempts,
                                decoration: _input('Attempts'),
                                items: const [
                                  DropdownMenuItem(value: 1, child: Text('1 attempt')),
                                  DropdownMenuItem(value: 2, child: Text('2 attempts')),
                                  DropdownMenuItem(value: 3, child: Text('3 attempts')),
                                  DropdownMenuItem(value: 5, child: Text('5 attempts')),
                                ],
                                onChanged: (value) => setState(() => _maxAttempts = value ?? 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(icon: Icons.security_outlined, title: 'Display & Security'),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: _shuffleQuestions,
                      onChanged: (value) => setState(() => _shuffleQuestions = value),
                      title: const Text('Shuffle Questions'),
                      subtitle: const Text('Randomize question order for each attempt.'),
                    ),
                    SwitchListTile(
                      value: _shuffleOptions,
                      onChanged: (value) => setState(() => _shuffleOptions = value),
                      title: const Text('Shuffle Options'),
                      subtitle: const Text('Randomize answer options for objective questions.'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        SizedBox(width: 320, child: _buildSummaryCard()),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final selected = _savedQuestions.where((q) => _selectedQuestionIds.contains(q.remoteId)).toList();
    final totalPoints = selected.fold<int>(0, (sum, q) => sum + q.maxScore);
    final difficulty = _summaryDifficulty(selected);
    return _Card(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quiz Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          _SummaryRow('Selected Questions', '$_selectedCount'),
          const Divider(height: 24),
          _SummaryRow('Total Points', '$totalPoints'),
          const Divider(height: 24),
          _SummaryRow('Difficulty', difficulty),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'This exam is created from saved question-bank items. Only database-saved questions can be attached.',
              style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _summaryDifficulty(List<QuestionModel> selected) {
    if (selected.isEmpty) return '-';
    final hard = selected.where((q) => q.difficulty == QuestionDifficulty.hard).length;
    final medium = selected.where((q) => q.difficulty == QuestionDifficulty.medium).length;
    if (hard >= medium && hard > 0) return 'Hard';
    if (medium > 0) return 'Medium';
    return 'Easy';
  }

  Widget _buildFooter() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _saving ? null : _back,
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: Text(_step == 1 ? 'Back to Question Bank' : 'Back'),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: _saving ? null : _next,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          ),
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_step == 3 ? 'Finish & Create Exam' : 'Next'),
        ),
      ],
    );
  }
}

class _SelectableQuestionCard extends StatelessWidget {
  final QuestionModel question;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _SelectableQuestionCard({
    required this.question,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: selected, onChanged: (value) => onChanged(value ?? false)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(question.text, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textTitle)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Pill(question.typeLabel),
                      _Pill(question.difficultyLabel),
                      _Pill(question.topicName ?? 'Topic #${question.topicId ?? '-'}'),
                    ],
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

class _StepChip extends StatelessWidget {
  final int index;
  final String label;
  final bool active;
  final bool done;

  const _StepChip({required this.index, required this.label, required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    final color = done ? const Color(0xFF16A34A) : active ? AppColors.primary : AppColors.textMuted;
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: color,
          child: Icon(done ? Icons.check : null, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Text('$index. $label', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool active;
  const _StepLine({required this.active});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        height: 1,
        color: active ? AppColors.primary : AppColors.border,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(24)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
    );
  }
}

InputDecoration _input(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dangerText.withValues(alpha: 0.25)),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.dangerText, fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyExamQuestions extends StatelessWidget {
  const _EmptyExamQuestions();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Column(
        children: [
          Icon(Icons.quiz_outlined, size: 36, color: AppColors.textMuted),
          SizedBox(height: 10),
          Text('No saved questions yet', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          SizedBox(height: 6),
          Text(
            'Create exam uses the database question bank. Save questions first from the course content flow.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
