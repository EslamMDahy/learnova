import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/widgets/app_ui_components.dart';
import '../../../data/courses_models.dart';
import '../../../data/exam_templates_storage.dart';
import '../../../data/question_models.dart';
import '../../../data/question_vocabulary.dart';

class CourseExamTemplatesTab extends ConsumerStatefulWidget {
  final MyCourseItem course;

  const CourseExamTemplatesTab({super.key, required this.course});

  @override
  ConsumerState<CourseExamTemplatesTab> createState() => _CourseExamTemplatesTabState();
}

class _CourseExamTemplatesTabState extends ConsumerState<CourseExamTemplatesTab> {
  bool _loading = true;
  String? _error;
  List<ExamTemplateModel> _templates = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final templates = await ref.read(examTemplatesStorageProvider).load(widget.course.id);
      if (!mounted) return;
      setState(() {
        _templates = templates;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load exam templates.';
      });
    }
  }

  Future<void> _openEditor([ExamTemplateModel? template]) async {
    final saved = await showDialog<ExamTemplateModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ExamTemplateEditorDialog(
        courseId: widget.course.id,
        template: template,
      ),
    );
    if (saved == null) return;
    setState(() => _error = null);
    try {
      final templates = await ref.read(examTemplatesStorageProvider).upsert(widget.course.id, saved);
      if (!mounted) return;
      setState(() => _templates = templates);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not save exam template: $e');
    }
  }

  Future<void> _delete(ExamTemplateModel template) async {
    if (template.isCustom || template.isDefault) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete template'),
        content: Text('Delete "${template.name}" from this course?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _error = null);
    try {
      final templates = await ref.read(examTemplatesStorageProvider).delete(widget.course.id, template.id);
      if (!mounted) return;
      setState(() => _templates = templates);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not delete exam template: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.pageBg,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        children: [
          _TemplatesHeader(onCreate: () => _openEditor()),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: [BoxShadow(color: AppColors.shadowThin, blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _TemplatesError(message: _error!, onRetry: _load)
                        : _templates.isEmpty
                            ? _TemplatesEmpty(onCreate: () => _openEditor())
                            : _TemplatesList(
                                templates: _templates,
                                onEdit: _openEditor,
                                onDelete: _delete,
                              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplatesHeader extends StatelessWidget {
  final VoidCallback onCreate;

  const _TemplatesHeader({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF145CCB), Color(0xFF137FEC), Color(0xFF22C1F1)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.18), blurRadius: 28, offset: const Offset(0, 12))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: Text(
                    'Exam templates',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Assessment Templates',
                  style: TextStyle(fontSize: 30, height: 1.05, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.7),
                ),
                const SizedBox(height: 8),
                Text(
                  'Define reusable exam structures before selecting topics, outcomes, and questions.',
                  style: TextStyle(fontSize: 13.5, height: 1.55, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.84)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Template'),
          ),
        ],
      ),
    );
  }
}

class _TemplatesList extends StatelessWidget {
  final List<ExamTemplateModel> templates;
  final ValueChanged<ExamTemplateModel> onEdit;
  final ValueChanged<ExamTemplateModel> onDelete;

  const _TemplatesList({required this.templates, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          color: AppColors.surfaceBg,
          child: const Row(
            children: [
              Expanded(flex: 36, child: _HeaderCell('Template')),
              Expanded(flex: 18, child: _HeaderCell('Shape')),
              Expanded(flex: 24, child: _HeaderCell('Settings')),
              SizedBox(width: 96, child: _HeaderCell('Actions')),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.border),
        Expanded(
          child: ListView.separated(
            itemCount: templates.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final template = templates[index];
              return _TemplateRow(
                template: template,
                onEdit: () => onEdit(template),
                onDelete: () => onDelete(template),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.6),
    );
  }
}

class _TemplateRow extends StatefulWidget {
  final ExamTemplateModel template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TemplateRow({required this.template, required this.onEdit, required this.onDelete});

  @override
  State<_TemplateRow> createState() => _TemplateRowState();
}

class _TemplateRowState extends State<_TemplateRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        color: _hovered ? AppColors.hoverBg : AppColors.cardBg,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 36,
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.description_outlined, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textTitle, fontSize: 14, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(t.description.isEmpty ? 'No description' : t.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 18,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ..._distributionBadges(t),
                  if (t.preferredDifficulty != null) _MiniBadge(t.preferredDifficulty!.label),
                ],
              ),
            ),
            Expanded(
              flex: 24,
              child: Text(
                '${t.durationMinutes} min • ${t.maxAttempts} attempt${t.maxAttempts == 1 ? '' : 's'} • ${t.passingScore.toStringAsFixed(0)}% pass • ${t.publishAfterSave ? 'Publish' : 'Draft'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
            SizedBox(
              width: 96,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: t.isCustom ? 'Duplicate defaults by creating a new template' : 'Edit template',
                    onPressed: t.isCustom ? null : widget.onEdit,
                    icon: Icon(Icons.edit_outlined, size: 18, color: t.isCustom ? AppColors.textHint : AppColors.primary),
                  ),
                  IconButton(
                    tooltip: t.isCustom ? 'Custom cannot be deleted' : 'Delete template',
                    onPressed: t.isCustom || t.isDefault ? null : widget.onDelete,
                    icon: Icon(Icons.delete_outline_rounded, size: 18, color: t.isCustom || t.isDefault ? AppColors.textHint : AppColors.dangerText),
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

class _MiniBadge extends StatelessWidget {
  final String label;
  const _MiniBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: TextStyle(color: AppColors.textTitle, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _ExamTemplateEditorDialog extends StatefulWidget {
  final int courseId;
  final ExamTemplateModel? template;

  const _ExamTemplateEditorDialog({required this.courseId, this.template});

  @override
  State<_ExamTemplateEditorDialog> createState() => _ExamTemplateEditorDialogState();
}

class _ExamTemplateEditorDialogState extends State<_ExamTemplateEditorDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _attemptsCtrl;
  late final TextEditingController _passingCtrl;
  late final TextEditingController _instructionsCtrl;
  late String _examType;
  late bool _shuffleQuestions;
  late bool _shuffleAnswers;
  late bool _showResult;
  late bool _allowReview;
  late bool _publishAfterSave;
  late QuestionDifficulty? _preferredDifficulty;
  late final List<_TemplateSectionDraft> _sectionDrafts;
  String? _error;

  @override
  void initState() {
    super.initState();
    final template = widget.template ?? ExamTemplateModel.custom(widget.courseId).copyWith(
      id: 'new-${DateTime.now().microsecondsSinceEpoch}',
      name: '',
      description: '',
    );
    _nameCtrl = TextEditingController(text: template.name == 'Custom exam' ? '' : template.name);
    _descriptionCtrl = TextEditingController(text: template.description);
    _durationCtrl = TextEditingController(text: template.durationMinutes.toString());
    _attemptsCtrl = TextEditingController(text: template.maxAttempts.toString());
    _passingCtrl = TextEditingController(text: template.passingScore.toStringAsFixed(0));
    _instructionsCtrl = TextEditingController(text: template.instructions);
    _examType = template.examType;
    _shuffleQuestions = template.shuffleQuestions;
    _shuffleAnswers = template.shuffleAnswers;
    _showResult = template.showResultImmediately;
    _allowReview = template.allowReview;
    _publishAfterSave = template.publishAfterSave;
    _preferredDifficulty = template.preferredDifficulty;
    _sectionDrafts = _TemplateSectionDraft.fromTemplate(template);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _durationCtrl.dispose();
    _attemptsCtrl.dispose();
    _passingCtrl.dispose();
    _instructionsCtrl.dispose();
    for (final draft in _sectionDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 0;
    final attempts = int.tryParse(_attemptsCtrl.text.trim()) ?? 0;
    final passing = double.tryParse(_passingCtrl.text.trim()) ?? -1;
    final activeSections = <ExamTemplateSectionModel>[];
    final now = DateTime.now();

    for (final draft in _sectionDrafts) {
      final count = draft.questionCount;
      final points = draft.pointsPerQuestion;
      if (count < 0) {
        setState(() => _error = '${draft.label} count cannot be negative.');
        return;
      }
      if (count > 0 && points <= 0) {
        setState(() => _error = '${draft.label} points must be greater than zero.');
        return;
      }
      if (count > 0) {
        activeSections.add(draft.toModel(orderIndex: activeSections.length + 1, now: now));
      }
    }

    final qCount = activeSections.fold<int>(0, (sum, section) => sum + section.questionCount);
    if (name.isEmpty) {
      setState(() => _error = 'Template name is required.');
      return;
    }
    if (qCount <= 0) {
      setState(() => _error = 'Add at least one question in the distribution.');
      return;
    }
    if (duration <= 0) {
      setState(() => _error = 'Duration must be greater than zero.');
      return;
    }
    if (attempts <= 0) {
      setState(() => _error = 'Attempts must be greater than zero.');
      return;
    }
    if (passing < 0 || passing > 100) {
      setState(() => _error = 'Passing score must be between 0 and 100.');
      return;
    }
    final original = widget.template;
    Navigator.of(context).pop(ExamTemplateModel(
      id: original?.id ?? 'new-${now.microsecondsSinceEpoch}',
      courseId: widget.courseId,
      name: name,
      description: _descriptionCtrl.text.trim(),
      examType: _examType,
      questionCount: qCount,
      durationMinutes: duration,
      maxAttempts: attempts,
      passingScore: passing,
      shuffleQuestions: _shuffleQuestions,
      shuffleAnswers: _shuffleAnswers,
      showResultImmediately: _showResult,
      allowReview: _allowReview,
      publishAfterSave: _publishAfterSave,
      preferredDifficulty: _preferredDifficulty,
      instructions: _instructionsCtrl.text.trim(),
      createdAt: original?.createdAt ?? now,
      updatedAt: now,
      sections: activeSections,
    ),);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.template != null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 820),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Material(
            color: AppColors.cardBg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF145CCB), Color(0xFF137FEC), Color(0xFF22C1F1)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: const Icon(Icons.description_outlined, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isEditing ? 'Edit Template' : 'Create Template',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Define a reusable exam structure for this course.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.80),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 21),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_error != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: AppColors.dangerBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.dangerBorder),
                            ),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: AppColors.dangerText,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final twoCols = constraints.maxWidth >= 660;
                            final half = twoCols ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
                            final quarter = constraints.maxWidth >= 760 ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(width: half, child: _EditorTextField(label: 'Name', controller: _nameCtrl, hint: 'Quiz template')),
                                    _EditorChoice<String>(
                                      label: 'Exam type',
                                      width: half,
                                      value: _examType,
                                      options: const [
                                        _ChoiceItem(value: 'quiz', label: 'Quiz'),
                                        _ChoiceItem(value: 'midterm', label: 'Midterm'),
                                        _ChoiceItem(value: 'final', label: 'Final'),
                                        _ChoiceItem(value: 'practice', label: 'Practice'),
                                      ],
                                      onChanged: (value) => setState(() => _examType = value),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _EditorTextField(label: 'Description', controller: _descriptionCtrl, hint: 'What this template is for', maxLines: 2),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(width: quarter, child: _EditorTextField(label: 'Duration', controller: _durationCtrl, hint: '60', number: true, suffix: 'min')),
                                    SizedBox(width: quarter, child: _EditorTextField(label: 'Attempts', controller: _attemptsCtrl, hint: '1', number: true)),
                                    SizedBox(width: quarter, child: _EditorTextField(label: 'Passing', controller: _passingCtrl, hint: '60', number: true, suffix: '%')),
                                    _EditorChoice<QuestionDifficulty?>(
                                      label: 'Preferred difficulty',
                                      width: quarter,
                                      value: _preferredDifficulty,
                                      options: [
                                        const _ChoiceItem<QuestionDifficulty?>(value: null, label: 'Any difficulty'),
                                        ...QuestionDifficulty.values.map((item) => _ChoiceItem<QuestionDifficulty?>(value: item, label: item.label)),
                                      ],
                                      onChanged: (value) => setState(() => _preferredDifficulty = value),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _TemplateDistributionEditor(
                                  drafts: _sectionDrafts,
                                  totalQuestions: _sectionDrafts.fold<int>(0, (sum, draft) => sum + draft.questionCount),
                                  onChanged: () => setState(() => _error = null),
                                ),
                                const SizedBox(height: 14),
                                _EditorTextField(label: 'Default instructions', controller: _instructionsCtrl, hint: 'Student-facing rules and notes', maxLines: 3),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _EditorSwitch(title: 'Shuffle questions', value: _shuffleQuestions, onChanged: (v) => setState(() => _shuffleQuestions = v)),
                                    _EditorSwitch(title: 'Shuffle answers', value: _shuffleAnswers, onChanged: (v) => setState(() => _shuffleAnswers = v)),
                                    _EditorSwitch(title: 'Show result immediately', value: _showResult, onChanged: (v) => setState(() => _showResult = v)),
                                    _EditorSwitch(title: 'Allow review', value: _allowReview, onChanged: (v) => setState(() => _allowReview = v)),
                                    _EditorSwitch(title: 'Publish after save', value: _publishAfterSave, onChanged: (v) => setState(() => _publishAfterSave = v)),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.borderGray),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined, size: 17),
                        label: const Text('Save Template'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _TemplateDistributionEditor extends StatelessWidget {
  final List<_TemplateSectionDraft> drafts;
  final int totalQuestions;
  final VoidCallback onChanged;

  const _TemplateDistributionEditor({
    required this.drafts,
    required this.totalQuestions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question distribution',
                      style: TextStyle(color: AppColors.textTitle, fontSize: 13.5, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Set how many questions should be selected from each type.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              _MiniBadge('$totalQuestions Q total'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderGray),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(flex: 36, child: _DistributionHeader('Type')),
                    const SizedBox(width: 10),
                    SizedBox(width: 120, child: _DistributionHeader('Questions')),
                  ],
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < drafts.length; i++) ...[
                  _TemplateDistributionRow(draft: drafts[i], onChanged: onChanged),
                  if (i != drafts.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionHeader extends StatelessWidget {
  final String label;

  const _DistributionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.4),
    );
  }
}

class _TemplateDistributionRow extends StatelessWidget {
  final _TemplateSectionDraft draft;
  final VoidCallback onChanged;

  const _TemplateDistributionRow({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 36,
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderGray),
                ),
                child: Icon(draft.icon, size: 15, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  draft.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textTitle, fontSize: 12.5, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: _SmallDistributionField(controller: draft.countCtrl, hint: '0', onChanged: onChanged),
        ),
      ],
    );
  }
}

class _SmallDistributionField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;

  const _SmallDistributionField({required this.controller, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: (_) => onChanged(),
      style: TextStyle(color: AppColors.textTitle, fontSize: 12.5, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        filled: true,
        fillColor: AppColors.fieldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        hintStyle: TextStyle(color: AppColors.textHint, fontSize: 12, fontWeight: FontWeight.w600),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderGray)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.4)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderGray)),
      ),
    );
  }
}

class _TemplateSectionDraft {
  final int? id;
  final int? templateId;
  final String questionType;
  final String label;
  final IconData icon;
  final TextEditingController countCtrl;
  final TextEditingController pointsCtrl;

  _TemplateSectionDraft({
    this.id,
    this.templateId,
    required this.questionType,
    required this.label,
    required this.icon,
    required int questionCount,
    required double pointsPerQuestion,
  })  : countCtrl = TextEditingController(text: questionCount.toString()),
        pointsCtrl = TextEditingController(text: _formatPoints(pointsPerQuestion));

  int get questionCount => int.tryParse(countCtrl.text.trim()) ?? 0;
  double get pointsPerQuestion => double.tryParse(pointsCtrl.text.trim()) ?? 0;

  ExamTemplateSectionModel toModel({required int orderIndex, required DateTime now}) {
    final points = pointsPerQuestion > 0 ? pointsPerQuestion : 1.0;
    final count = questionCount;
    return ExamTemplateSectionModel(
      id: id,
      templateId: templateId,
      title: _sectionTitle(questionType),
      questionType: questionType,
      questionCount: count,
      pointsPerQuestion: points,
      sectionScore: count * points,
      orderIndex: orderIndex,
      createdAt: now,
      updatedAt: now,
    );
  }

  void dispose() {
    countCtrl.dispose();
    pointsCtrl.dispose();
  }

  static List<_TemplateSectionDraft> fromTemplate(ExamTemplateModel template) {
    final byType = <String, ExamTemplateSectionModel>{
      for (final section in template.sections) section.questionType: section,
    };
    if (byType.isEmpty) {
      for (final section in template.distributionSections) {
        byType[section.questionType] = section;
      }
    }

    return _supportedTemplateSectionTypes.map((spec) {
      final section = byType[spec.questionType];
      final fallbackCount = section == null && spec.questionType == 'multiple_choice' ? template.questionCount : 0;
      return _TemplateSectionDraft(
        id: section?.id,
        templateId: section?.templateId,
        questionType: spec.questionType,
        label: spec.label,
        icon: spec.icon,
        questionCount: section?.questionCount ?? fallbackCount,
        pointsPerQuestion: section?.pointsPerQuestion ?? 1,
      );
    }).toList();
  }
}

class _TemplateSectionSpec {
  final String questionType;
  final String label;
  final IconData icon;

  const _TemplateSectionSpec({required this.questionType, required this.label, required this.icon});
}

const _supportedTemplateSectionTypes = <_TemplateSectionSpec>[
  _TemplateSectionSpec(questionType: 'multiple_choice', label: 'Multiple Choice', icon: Icons.radio_button_checked_rounded),
  _TemplateSectionSpec(questionType: 'true_false', label: 'True / False', icon: Icons.rule_rounded),
  _TemplateSectionSpec(questionType: 'short_answer', label: 'Short Answer', icon: Icons.short_text_rounded),
  _TemplateSectionSpec(questionType: 'essay', label: 'Essay', icon: Icons.subject_rounded),
  _TemplateSectionSpec(questionType: 'multi_select', label: 'Multi-Select', icon: Icons.checklist_rounded),
];

List<Widget> _distributionBadges(ExamTemplateModel template) {
  final sections = template.distributionSections;
  final result = <Widget>[_MiniBadge('${template.questionCount} Q')];
  for (final section in sections.take(3)) {
    result.add(_MiniBadge('${section.questionCount} ${_shortTypeLabel(section.questionType)}'));
  }
  if (sections.length > 3) result.add(_MiniBadge('+${sections.length - 3}'));
  return result;
}

String _shortTypeLabel(String questionType) {
  switch (questionType) {
    case 'true_false':
      return 'TF';
    case 'short_answer':
      return 'SA';
    case 'essay':
      return 'Essay';
    case 'multi_select':
      return 'MS';
    default:
      return 'MCQ';
  }
}

String _sectionTitle(String questionType) {
  switch (questionType) {
    case 'true_false':
      return 'True / False Questions';
    case 'short_answer':
      return 'Short Answer Questions';
    case 'essay':
      return 'Essay Questions';
    case 'multi_select':
      return 'Multi-Select Questions';
    default:
      return 'Multiple Choice Questions';
  }
}

String _formatPoints(double value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

class _ChoiceItem<T> {
  final T value;
  final String label;

  const _ChoiceItem({required this.value, required this.label});
}

class _EditorChoice<T> extends StatelessWidget {
  final String label;
  final double width;
  final T value;
  final List<_ChoiceItem<T>> options;
  final ValueChanged<T> onChanged;

  const _EditorChoice({
    required this.label,
    required this.width,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = options.cast<_ChoiceItem<T>?>().firstWhere(
          (item) => item != null && item.value == value,
          orElse: () => null,
        );
    final selectedLabel = selected?.label ?? (options.isEmpty ? '' : options.first.label);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          FigmaUmDropdown40(
            width: width,
            value: selectedLabel,
            items: options.map((item) => item.label).toList(growable: false),
            onChanged: (selectedText) {
              final match = options.cast<_ChoiceItem<T>?>().firstWhere(
                    (item) => item != null && item.label == selectedText,
                    orElse: () => null,
                  );
              if (match != null) onChanged(match.value);
            },
          ),
        ],
      ),
    );
  }
}

class _EditorTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final bool number;
  final String? suffix;

  const _EditorTextField({required this.label, required this.controller, required this.hint, this.maxLines = 1, this.number = false, this.suffix});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          style: TextStyle(color: AppColors.textTitle, fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            suffixText: suffix,
            filled: true,
            fillColor: AppColors.fieldBg,
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: maxLines > 1 ? 12 : 11),
            hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13, fontWeight: FontWeight.w600),
            suffixStyle: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700),
            enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: AppColors.borderGray)),
            focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: AppColors.borderGray)),
          ),
        ),
      ],
    );
  }
}

class _EditorSwitch extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _EditorSwitch({required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 166,
      height: 44,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textTitle, fontSize: 11.5, height: 1.1, fontWeight: FontWeight.w800),
            ),
          ),
          Transform.scale(scale: 0.78, child: Switch(value: value, onChanged: onChanged)),
        ],
      ),
    );
  }
}

class _TemplatesError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _TemplatesError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.dangerText, size: 38),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _TemplatesEmpty extends StatelessWidget {
  final VoidCallback onCreate;
  const _TemplatesEmpty({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, color: AppColors.textHint, size: 42),
          const SizedBox(height: 12),
          Text('No templates yet', style: TextStyle(color: AppColors.textTitle, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Create one template and reuse it when building exams.', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add_rounded), label: const Text('New Template')),
        ],
      ),
    );
  }
}
