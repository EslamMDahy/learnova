import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/error_mapper.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../data/courses_models.dart';
import '../../../data/exam_models.dart';
import '../../../data/exam_templates_storage.dart';
import '../../../data/materials_models.dart';
import '../../../data/modules_materials_providers.dart';
import '../../../data/modules_models.dart';
import '../../../data/question_models.dart';
import '../../../data/question_vocabulary.dart';
import '../../../data/topics_models.dart';
import '../../controllers/course_details_controller.dart';
import '../../controllers/course_details_state.dart';

Future<bool?> showCreateExamFlowDialog({
  required BuildContext context,
  required MyCourseItem course,
  required List<QuestionModel> questions,
  Set<int> initialSelectedQuestionIds = const <int>{},
  ExamTemplateModel? initialTemplate,
  int? initialScopeModuleId,
  int? initialScopeMaterialId,
  int? initialScopeTopicId,
  int? initialScopeOutcomeId,
  Set<int> initialScopeTopicIds = const <int>{},
  Set<int> initialScopeOutcomeIds = const <int>{},
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
        initialSelectedQuestionIds: initialSelectedQuestionIds,
        initialTemplate: initialTemplate,
        initialScopeModuleId: initialScopeModuleId,
        initialScopeMaterialId: initialScopeMaterialId,
        initialScopeTopicId: initialScopeTopicId,
        initialScopeOutcomeId: initialScopeOutcomeId,
        initialScopeTopicIds: initialScopeTopicIds,
        initialScopeOutcomeIds: initialScopeOutcomeIds,
        onCancel: onCancel,
        onCreated: onCreated,
      ),
    ),
  );
}

class CreateExamFlow extends ConsumerStatefulWidget {
  final MyCourseItem course;
  final List<QuestionModel> questions;
  final Set<int> initialSelectedQuestionIds;
  final ExamTemplateModel? initialTemplate;
  final int? initialScopeModuleId;
  final int? initialScopeMaterialId;
  final int? initialScopeTopicId;
  final int? initialScopeOutcomeId;
  final Set<int> initialScopeTopicIds;
  final Set<int> initialScopeOutcomeIds;
  final VoidCallback? onCancel;
  final VoidCallback? onCreated;

  const CreateExamFlow({
    super.key,
    required this.course,
    required this.questions,
    this.initialSelectedQuestionIds = const <int>{},
    this.initialTemplate,
    this.initialScopeModuleId,
    this.initialScopeMaterialId,
    this.initialScopeTopicId,
    this.initialScopeOutcomeId,
    this.initialScopeTopicIds = const <int>{},
    this.initialScopeOutcomeIds = const <int>{},
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
  final _attemptsCtrl = TextEditingController(text: '1');
  final _passingScoreCtrl = TextEditingController(text: '60');

  int _step = 1;
  bool _templateSeeded = false;
  bool _saving = false;
  bool _publishAfterSave = false;
  bool _shuffleQuestions = true;
  bool _shuffleAnswers = false;
  bool _showResultImmediately = true;
  bool _allowReview = true;
  String _examType = 'quiz';
  late ExamTemplateModel _selectedTemplate;
  String? _error;

  int? _scopeModuleId;
  int? _scopeMaterialId;
  final Set<int> _scopeTopicIds = <int>{};
  final Set<int> _scopeOutcomeIds = <int>{};
  DateTime? _availableFrom;
  DateTime? _availableTo;

  final List<int> _selectedQuestionIds = <int>[];
  bool _treeRequested = false;

  @override
  void initState() {
    super.initState();
    _selectedTemplate = widget.initialTemplate ?? ExamTemplateModel.custom(widget.course.id);
    _scopeModuleId = widget.initialScopeModuleId;
    _scopeMaterialId = widget.initialScopeMaterialId;
    _scopeTopicIds.addAll(widget.initialScopeTopicIds);
    if (widget.initialScopeTopicId != null) _scopeTopicIds.add(widget.initialScopeTopicId!);
    _scopeOutcomeIds.addAll(widget.initialScopeOutcomeIds);
    if (widget.initialScopeOutcomeId != null) _scopeOutcomeIds.add(widget.initialScopeOutcomeId!);
    _titleCtrl.text = '${widget.course.title} ${_selectedTemplate.name}';
    _applyTemplateModel(_selectedTemplate, updateTitle: true);
    for (final id in widget.initialSelectedQuestionIds) {
      if (!_selectedQuestionIds.contains(id) && _questionById(id) != null) {
        _selectedQuestionIds.add(id);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCourseTree());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _instructionsCtrl.dispose();
    _durationCtrl.dispose();
    _attemptsCtrl.dispose();
    _passingScoreCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCourseTree() async {
    if (_treeRequested) return;
    _treeRequested = true;
    try {
      await ref
          .read(courseDetailsControllerProvider(widget.course.id).notifier)
          .loadModulesAndAllMaterials();
    } catch (_) {
      // Create exam can still work from question metadata if the course tree is unavailable.
    }
  }

  List<QuestionModel> get _savedQuestions => widget.questions.where((q) => q.remoteId != null).toList();

  QuestionModel? _questionById(int id) {
    for (final question in _savedQuestions) {
      if (question.remoteId == id) return question;
    }
    return null;
  }

  List<QuestionModel> _selectedQuestions() {
    final result = <QuestionModel>[];
    for (final id in _selectedQuestionIds) {
      final question = _questionById(id);
      if (question != null) result.add(question);
    }
    return result;
  }

  double get _totalPoints => _selectedQuestions().fold<double>(
        0,
        (sum, question) => sum + question.maxScore.toDouble(),
      );

  String? _backendExamSectionType(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return 'multiple_choice';
      case QuestionType.trueFalse:
        return 'true_false';
      case QuestionType.shortAnswer:
        return 'short_answer';
      case QuestionType.essay:
        return 'essay';
      case QuestionType.multiSelect:
        return 'multi_select';
      case QuestionType.fillInTheBlank:
      case QuestionType.numeric:
      case QuestionType.code:
        return null;
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

  void _cancelFlow() {
    if (_saving) return;
    widget.onCancel?.call();
  }

  List<_TopicTarget> _topicTargetsFromState(CourseDetailsState state) {
    final result = <_TopicTarget>[];
    for (final module in state.modules) {
      final materials = state.materials[module.id] ?? const <MaterialItem>[];
      final materialById = {for (final material in materials) material.id: material};
      final topics = state.topics[module.id] ?? const <TopicItem>[];
      for (final topic in topics) {
        final material = materialById[topic.materialId];
        if (material == null) continue;
        String? parentTitle;
        if (topic.parentTopicId != null) {
          for (final candidate in topics) {
            if (candidate.id == topic.parentTopicId) {
              parentTitle = candidate.title;
              break;
            }
          }
        }
        result.add(_TopicTarget(
          module: module,
          material: material,
          topic: topic,
          parentTopicTitle: parentTitle,
        ),);
      }
    }
    result.sort((a, b) {
      final moduleCmp = a.module.orderIndex.compareTo(b.module.orderIndex);
      if (moduleCmp != 0) return moduleCmp;
      final materialCmp = a.material.displayTitle.compareTo(b.material.displayTitle);
      if (materialCmp != 0) return materialCmp;
      return a.topic.orderIndex.compareTo(b.topic.orderIndex);
    });
    return result;
  }

  _TopicTarget? _targetForQuestion(List<_TopicTarget> targets, QuestionModel question) {
    final topicId = question.topicId;
    if (topicId == null) return null;
    for (final target in targets) {
      if (target.topic.id == topicId) return target;
    }
    return null;
  }

  List<QuestionModel> _scopeQuestions(List<_TopicTarget> targets) {
    return _savedQuestions.where((question) {
      final target = _targetForQuestion(targets, question);
      final moduleId = question.moduleId ?? target?.module.id;
      final materialId = question.materialId ?? target?.material.id;
      final topicId = question.topicId ?? target?.topic.id;

      if (_scopeModuleId != null && moduleId != _scopeModuleId) return false;
      if (_scopeMaterialId != null && materialId != _scopeMaterialId) return false;
      if (_scopeTopicIds.isNotEmpty && (topicId == null || !_scopeTopicIds.contains(topicId))) return false;
      if (_scopeOutcomeIds.isNotEmpty &&
          !question.learningOutcomes.any((outcome) => _scopeOutcomeIds.contains(outcome.id))) {
        return false;
      }
      return true;
    }).toList();
  }

  void _toggleQuestion(QuestionModel question, bool selected) {
    final id = question.remoteId;
    if (id == null) return;
    setState(() {
      if (selected) {
        if (!_selectedQuestionIds.contains(id)) _selectedQuestionIds.add(id);
      } else {
        _selectedQuestionIds.remove(id);
      }
    });
  }

  void _applyTemplateModel(ExamTemplateModel template, {bool updateTitle = false}) {
    _selectedTemplate = template;
    _examType = template.examType;
    _durationCtrl.text = template.durationMinutes.toString();
    _attemptsCtrl.text = template.maxAttempts.toString();
    _passingScoreCtrl.text = template.passingScore.toStringAsFixed(0);
    _shuffleQuestions = template.shuffleQuestions;
    _shuffleAnswers = template.shuffleAnswers;
    _showResultImmediately = template.showResultImmediately;
    _allowReview = template.allowReview;
    _publishAfterSave = template.publishAfterSave;
    if (_instructionsCtrl.text.trim().isEmpty && template.instructions.trim().isNotEmpty) {
      _instructionsCtrl.text = template.instructions.trim();
    }
    if (updateTitle && _titleCtrl.text.trim().isEmpty) {
      _titleCtrl.text = '${widget.course.title} ${template.name}';
    }
  }

  void _seedQuestionsFromTemplate(List<_TopicTarget> targets) {
    if (_templateSeeded) return;
    _templateSeeded = true;
    if (_selectedQuestionIds.isNotEmpty) return;

    final template = _selectedTemplate;
    final scoped = _scopeQuestions(targets).where((question) => question.remoteId != null).toList();
    scoped.sort((a, b) {
      final usageCmp = a.usageCount.compareTo(b.usageCount);
      if (usageCmp != 0) return usageCmp;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    final ids = template.sections.where((section) => section.questionCount > 0).isNotEmpty
        ? _seedDistributedQuestionIds(scoped, template)
        : _seedLegacyQuestionIds(scoped, template);

    if (ids.isEmpty) return;
    setState(() => _selectedQuestionIds.addAll(ids));
  }

  List<int> _seedDistributedQuestionIds(List<QuestionModel> scoped, ExamTemplateModel template) {
    final ids = <int>[];
    final used = <int>{};
    final activeSections = template.sections.where((section) => section.questionCount > 0).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    for (final section in activeSections) {
      final type = _questionTypeFromTemplateSection(section.questionType);
      if (type == null) continue;
      final candidates = scoped.where((question) {
        final id = question.remoteId;
        if (id == null || used.contains(id)) return false;
        if (question.type != type) return false;
        if (template.preferredDifficulty != null && question.difficulty != template.preferredDifficulty) return false;
        return true;
      }).toList();

      for (final question in candidates.take(section.questionCount)) {
        final id = question.remoteId;
        if (id == null || !used.add(id)) continue;
        ids.add(id);
      }
    }

    return ids;
  }

  List<int> _seedLegacyQuestionIds(List<QuestionModel> scoped, ExamTemplateModel template) {
    final preferred = scoped.where((question) {
      if (template.preferredType != null && question.type != template.preferredType) return false;
      if (template.preferredDifficulty != null && question.difficulty != template.preferredDifficulty) return false;
      return true;
    }).toList();

    final ordered = <QuestionModel>[...preferred];
    for (final question in scoped) {
      if (!ordered.any((item) => item.remoteId == question.remoteId)) ordered.add(question);
    }

    final ids = <int>[];
    for (final question in ordered.take(template.questionCount)) {
      final id = question.remoteId;
      if (id != null && !ids.contains(id)) ids.add(id);
    }
    return ids;
  }

  QuestionType? _questionTypeFromTemplateSection(String raw) {
    switch (raw.trim()) {
      case 'multiple_choice':
        return QuestionType.multipleChoice;
      case 'true_false':
        return QuestionType.trueFalse;
      case 'short_answer':
        return QuestionType.shortAnswer;
      case 'essay':
        return QuestionType.essay;
      case 'multi_select':
        return QuestionType.multiSelect;
      default:
        return null;
    }
  }

  String? _templateSelectionError() {
    final activeSections = _selectedTemplate.sections.where((section) => section.questionCount > 0).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    if (activeSections.isEmpty) return null;

    final selected = _selectedQuestions();
    final gaps = <String>[];
    for (final section in activeSections) {
      final type = _questionTypeFromTemplateSection(section.questionType);
      if (type == null) continue;
      final count = selected.where((question) => question.type == type).length;
      if (count < section.questionCount) {
        gaps.add('${_shortTemplateTypeLabel(section.questionType)} ${count}/${section.questionCount}');
      }
    }
    if (gaps.isEmpty) return null;
    return 'The selected question set does not satisfy the template distribution: ${gaps.join(' • ')}.';
  }

  Future<void> _next(List<_TopicTarget> targets) async {
    setState(() => _error = null);
    if (_step == 1) {
      if (_selectedQuestionIds.isEmpty) {
        setState(() => _error = 'Select at least one question.');
        return;
      }
      final templateError = _templateSelectionError();
      if (templateError != null) {
        setState(() => _error = templateError);
        return;
      }
      setState(() => _step = 2);
      return;
    }
    if (_step == 2) {
      if (_titleCtrl.text.trim().isEmpty) {
        setState(() => _error = 'Exam title is required.');
        return;
      }
      if (_availableFrom != null && _availableTo != null && !_availableTo!.isAfter(_availableFrom!)) {
        setState(() => _error = 'End date must be after start date.');
        return;
      }
      setState(() => _step = 3);
      return;
    }
    await _saveExam();
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

  Future<void> _saveExam() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final duration = int.tryParse(_durationCtrl.text.trim());
      final attempts = int.tryParse(_attemptsCtrl.text.trim());
      final passingScore = double.tryParse(_passingScoreCtrl.text.trim());
      final selectedQuestions = _selectedQuestions();
      final unsupportedQuestions = selectedQuestions
          .where((question) => _backendExamSectionType(question.type) == null)
          .toList();
      if (unsupportedQuestions.isNotEmpty) {
        throw FormatException(
          'The current exam backend accepts multiple-choice, multi-select, true/false, short-answer, and essay questions only. Remove unsupported questions before saving.',
        );
      }

      final groupedQuestionIds = <String, List<int>>{};
      for (final question in selectedQuestions) {
        final questionId = question.remoteId;
        final questionType = _backendExamSectionType(question.type);
        if (questionId == null || questionType == null) continue;
        groupedQuestionIds.putIfAbsent(questionType, () => <int>[]).add(questionId);
      }

      final api = ref.read(examsApiProvider);
      final exam = await api.createExam(
        courseId: widget.course.id,
        payload: ExamCreatePayload(
          title: _titleCtrl.text.trim(),
          description: _emptyToNull(_descriptionCtrl.text),
          instructions: _emptyToNull(_instructionsCtrl.text),
          examType: _examType,
          durationMinutes: duration != null && duration > 0 ? duration : null,
          maxAttempts: attempts != null && attempts > 0 ? attempts : 1,
          passingScore: passingScore != null && passingScore >= 0 ? passingScore : null,
          shuffleQuestions: _shuffleQuestions,
          shuffleOptions: _shuffleAnswers,
          availableFrom: _availableFrom,
          availableTo: _availableTo,
        ),
      );

      for (final entry in groupedQuestionIds.entries) {
        final section = await api.createSection(
          courseId: widget.course.id,
          examId: exam.id,
          payload: ExamSectionCreatePayload(
            title: _sectionTitle(entry.key),
            questionType: entry.key,
            timeLimitMinutes: duration != null && duration > 0 ? duration : null,
          ),
        );
        await api.addQuestions(
          courseId: widget.course.id,
          examId: exam.id,
          sectionId: section.id,
          questionIds: entry.value,
        );
      }

      if (_publishAfterSave) {
        await api.publishExam(courseId: widget.course.id, examId: exam.id);
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _ExamSavedDialog(
          title: _publishAfterSave ? 'Exam published' : 'Exam saved',
          message: _publishAfterSave
              ? 'The exam was created, questions were attached, and the exam was published successfully.'
              : 'The exam was created and questions were attached successfully.',
          examId: exam.id,
        ),
      );
      if (!mounted) return;
      widget.onCreated?.call();
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
    final courseState = ref.watch(courseDetailsControllerProvider(widget.course.id));
    final targets = _topicTargetsFromState(courseState);
    final scoped = _scopeQuestions(targets);
    final selected = _selectedQuestions();
    if (!_templateSeeded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _seedQuestionsFromTemplate(targets);
      });
    }

    return Container(
      color: AppColors.surfaceBg,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 22, 28, 14),
                    child: Column(
                      children: [
                        _Stepper(current: _step),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          _ErrorBanner(message: _error!),
                        ],
                        const SizedBox(height: 16),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 140),
                            child: KeyedSubtree(
                              key: ValueKey<int>(_step),
                              child: switch (_step) {
                                1 => _QuestionSelectionStep(
                                    targets: targets,
                                    questions: selected,
                                    template: _selectedTemplate,
                                    scopedCount: scoped.length,
                                    onRemove: (QuestionModel question) => _toggleQuestion(question, false),
                                    onReplace: (QuestionModel question) => _replaceQuestion(question, targets),
                                  ),
                                2 => _SettingsStep(
                                    titleCtrl: _titleCtrl,
                                    descriptionCtrl: _descriptionCtrl,
                                    instructionsCtrl: _instructionsCtrl,
                                    durationCtrl: _durationCtrl,
                                    attemptsCtrl: _attemptsCtrl,
                                    passingScoreCtrl: _passingScoreCtrl,
                                    examType: _examType,
                                    selectedTemplate: _selectedTemplate,
                                    availableFrom: _availableFrom,
                                    availableTo: _availableTo,
                                    shuffleQuestions: _shuffleQuestions,
                                    shuffleAnswers: _shuffleAnswers,
                                    showResultImmediately: _showResultImmediately,
                                    allowReview: _allowReview,
                                    publishAfterSave: _publishAfterSave,
                                    totalPoints: _totalPoints,
                                    onExamTypeChanged: (value) => setState(() => _examType = value),
                                    onStartChanged: (value) => setState(() => _availableFrom = value),
                                    onEndChanged: (value) => setState(() => _availableTo = value),
                                    onShuffleQuestionsChanged: (value) => setState(() => _shuffleQuestions = value),
                                    onShuffleAnswersChanged: (value) => setState(() => _shuffleAnswers = value),
                                    onShowResultChanged: (value) => setState(() => _showResultImmediately = value),
                                    onAllowReviewChanged: (value) => setState(() => _allowReview = value),
                                    onPublishChanged: (value) => setState(() => _publishAfterSave = value),
                                  ),
                                _ => _PreviewStep(
                                    targets: targets,
                                    questions: selected,
                                    totalPoints: _totalPoints,
                                    title: _titleCtrl.text.trim(),
                                    publishAfterSave: _publishAfterSave,
                                    showResultImmediately: _showResultImmediately,
                                    allowReview: _allowReview,
                                  ),
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _FlowFooter(
              step: _step,
              saving: _saving,
              publishAfterSave: _publishAfterSave,
              onBack: _back,
              onNext: () => _next(targets),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _replaceQuestion(QuestionModel original, List<_TopicTarget> targets) async {
    final replacement = await showDialog<QuestionModel>(
      context: context,
      builder: (_) => _ReplaceQuestionDialog(
        original: original,
        candidates: _replacementCandidates(original, targets, relaxed: false),
        relaxedCandidates: _replacementCandidates(original, targets, relaxed: true),
      ),
    );
    final newId = replacement?.remoteId;
    final oldId = original.remoteId;
    if (newId == null || oldId == null || !mounted) return;
    setState(() {
      final index = _selectedQuestionIds.indexOf(oldId);
      if (index == -1) return;
      _selectedQuestionIds[index] = newId;
      final seen = <int>{};
      _selectedQuestionIds.removeWhere((id) => !seen.add(id));
    });
  }

  List<QuestionModel> _replacementCandidates(
    QuestionModel original,
    List<_TopicTarget> targets, {
    required bool relaxed,
  }) {
    final selected = _selectedQuestionIds.toSet();
    final originalId = original.remoteId;
    final originalLoIds = original.learningOutcomes.map((lo) => lo.id).toSet();
    return _scopeQuestions(targets).where((candidate) {
      final id = candidate.remoteId;
      if (id == null || id == originalId || selected.contains(id)) return false;
      if (!relaxed) {
        if (candidate.type != original.type) return false;
        if (candidate.difficulty != original.difficulty) return false;
        final sameTopic = candidate.topicId != null && candidate.topicId == original.topicId;
        final sharesLo = originalLoIds.isNotEmpty &&
            candidate.learningOutcomes.any((lo) => originalLoIds.contains(lo.id));
        return sameTopic || sharesLo;
      }
      if (candidate.type == original.type) return true;
      final sameTopic = candidate.topicId != null && candidate.topicId == original.topicId;
      final sharesLo = originalLoIds.isNotEmpty &&
          candidate.learningOutcomes.any((lo) => originalLoIds.contains(lo.id));
      return sameTopic || sharesLo;
    }).toList();
  }
}

class _TopicTarget {
  final ModuleItem module;
  final MaterialItem material;
  final TopicItem topic;
  final String? parentTopicTitle;

  const _TopicTarget({
    required this.module,
    required this.material,
    required this.topic,
    this.parentTopicTitle,
  });

  String get topicLabel => parentTopicTitle == null ? topic.title : '$parentTopicTitle / ${topic.title}';
}

class _Stepper extends StatelessWidget {
  final int current;
  const _Stepper({required this.current});

  @override
  Widget build(BuildContext context) {
    const steps = [
      (1, 'Questions', 'Build the set'),
      (2, 'Settings', 'Configure exam'),
      (3, 'Preview', 'Final review'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.shadowThin, blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(
              child: _ProgressStep(
                index: steps[i].$1,
                label: steps[i].$2,
                caption: steps[i].$3,
                current: current,
              ),
            ),
            if (i != steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 28),
                  decoration: BoxDecoration(
                    color: current > steps[i].$1 ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  final int index;
  final String label;
  final String caption;
  final int current;

  const _ProgressStep({required this.index, required this.label, required this.caption, required this.current});

  @override
  Widget build(BuildContext context) {
    final active = current == index;
    final done = current > index;
    final tone = done || active ? AppColors.primary : AppColors.textMuted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: done || active ? AppColors.primary : AppColors.surfaceBg,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: done || active ? AppColors.primary : AppColors.border, width: 1.2),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : Text(
                    '$index',
                    style: TextStyle(
                      color: active ? Colors.white : AppColors.textMuted,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: tone, fontWeight: FontWeight.w900, fontSize: 12.5)),
        const SizedBox(height: 2),
        Text(caption, style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 11)),
      ],
    );
  }
}

class _ScopeStep extends StatelessWidget {
  final CourseDetailsState courseState;
  final List<_TopicTarget> targets;
  final List<QuestionModel> questions;
  final List<QuestionModel> scopedQuestions;
  final int? moduleId;
  final int? materialId;
  final int? topicId;
  final int? outcomeId;
  final ValueChanged<int?> onModuleChanged;
  final ValueChanged<int?> onMaterialChanged;
  final ValueChanged<int?> onTopicChanged;
  final ValueChanged<int?> onOutcomeChanged;
  final VoidCallback onClear;

  const _ScopeStep({
    required this.courseState,
    required this.targets,
    required this.questions,
    required this.scopedQuestions,
    required this.moduleId,
    required this.materialId,
    required this.topicId,
    required this.outcomeId,
    required this.onModuleChanged,
    required this.onMaterialChanged,
    required this.onTopicChanged,
    required this.onOutcomeChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final materialOptions = _materialOptions(targets, moduleId);
    final topicOptions = _topicOptions(targets, moduleId, materialId);
    final outcomeOptions = _outcomeOptions(questions);
    final modules = courseState.modules;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            icon: Icons.filter_alt_outlined,
            title: 'Exam scope',
            subtitle: 'Choose the content area first. The next step only shows matching question-bank items.',
            trailing: TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Clear scope'),
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoCols = constraints.maxWidth > 820;
              final fields = [
                _SelectField<int?>(
                  label: 'Module',
                  value: moduleId,
                  hint: 'All modules',
                  items: [
                    const DropdownMenuItem<int?>(child: Text('All modules')),
                    ...modules.map((module) => DropdownMenuItem<int?>(value: module.id, child: Text(module.title))),
                  ],
                  onChanged: onModuleChanged,
                ),
                _SelectField<int?>(
                  label: 'Material',
                  value: materialId,
                  hint: 'All materials',
                  items: [
                    const DropdownMenuItem<int?>(child: Text('All materials')),
                    ...materialOptions.map((material) => DropdownMenuItem<int?>(value: material.id, child: Text(material.displayTitle))),
                  ],
                  onChanged: onMaterialChanged,
                ),
                _SelectField<int?>(
                  label: 'Topic / Subtopic',
                  value: topicId,
                  hint: 'All topics',
                  items: [
                    const DropdownMenuItem<int?>(child: Text('All topics / subtopics')),
                    ...topicOptions.map((target) => DropdownMenuItem<int?>(value: target.topic.id, child: Text(target.topicLabel))),
                  ],
                  onChanged: onTopicChanged,
                ),
                _SelectField<int?>(
                  label: 'Learning Outcome',
                  value: outcomeId,
                  hint: 'All LOs',
                  items: [
                    const DropdownMenuItem<int?>(child: Text('All learning outcomes')),
                    ...outcomeOptions.map((outcome) => DropdownMenuItem<int?>(value: outcome.id, child: Text(outcome.title))),
                  ],
                  onChanged: onOutcomeChanged,
                ),
              ];

              if (!twoCols) {
                return Column(
                  children: fields.map((field) => Padding(padding: const EdgeInsets.only(bottom: 14), child: field)).toList(),
                );
              }
              return Column(
                children: [
                  Row(children: [Expanded(child: fields[0]), const SizedBox(width: 14), Expanded(child: fields[1])]),
                  const SizedBox(height: 14),
                  Row(children: [Expanded(child: fields[2]), const SizedBox(width: 14), Expanded(child: fields[3])]),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _ScopeMetric(label: 'Saved questions', value: '${questions.length}', icon: Icons.library_books_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _ScopeMetric(label: 'Matching scope', value: '${scopedQuestions.length}', icon: Icons.fact_check_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _ScopeMetric(label: 'Auto-gradable', value: '${scopedQuestions.where((q) => q.autoGradable).length}', icon: Icons.bolt_outlined)),
            ],
          ),
          const SizedBox(height: 18),
          _MiniQuestionPreview(questions: scopedQuestions.take(5).toList()),
        ],
      ),
    );
  }
}

class _SettingsStep extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController descriptionCtrl;
  final TextEditingController instructionsCtrl;
  final TextEditingController durationCtrl;
  final TextEditingController attemptsCtrl;
  final TextEditingController passingScoreCtrl;
  final String examType;
  final ExamTemplateModel selectedTemplate;
  final DateTime? availableFrom;
  final DateTime? availableTo;
  final bool shuffleQuestions;
  final bool shuffleAnswers;
  final bool showResultImmediately;
  final bool allowReview;
  final bool publishAfterSave;
  final double totalPoints;
  final ValueChanged<String> onExamTypeChanged;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;
  final ValueChanged<bool> onShuffleQuestionsChanged;
  final ValueChanged<bool> onShuffleAnswersChanged;
  final ValueChanged<bool> onShowResultChanged;
  final ValueChanged<bool> onAllowReviewChanged;
  final ValueChanged<bool> onPublishChanged;

  const _SettingsStep({
    required this.titleCtrl,
    required this.descriptionCtrl,
    required this.instructionsCtrl,
    required this.durationCtrl,
    required this.attemptsCtrl,
    required this.passingScoreCtrl,
    required this.examType,
    required this.selectedTemplate,
    required this.availableFrom,
    required this.availableTo,
    required this.shuffleQuestions,
    required this.shuffleAnswers,
    required this.showResultImmediately,
    required this.allowReview,
    required this.publishAfterSave,
    required this.totalPoints,
    required this.onExamTypeChanged,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onShuffleQuestionsChanged,
    required this.onShuffleAnswersChanged,
    required this.onShowResultChanged,
    required this.onAllowReviewChanged,
    required this.onPublishChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 980;
          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelTitle(
                icon: Icons.tune_rounded,
                title: 'Exam settings',
                subtitle: 'Core fields are sent to the current backend. Review/result preferences are kept in the flow UI until backend fields exist.',
              ),
              const SizedBox(height: 18),
              _TextInput(label: 'Title', controller: titleCtrl, hint: 'Midterm Exam'),
              const SizedBox(height: 14),
              _TextInput(label: 'Description', controller: descriptionCtrl, hint: 'Short student-facing description', maxLines: 3),
              const SizedBox(height: 14),
              _TextInput(label: 'Instructions', controller: instructionsCtrl, hint: 'Rules, allowed materials, grading notes...', maxLines: 5),
            ],
          );

          final right = Column(
            children: [
              _TemplateAppliedCard(template: selectedTemplate),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _SelectField<String>(
                      label: 'Exam type',
                      value: examType,
                      hint: 'Quiz',
                      items: const [
                        DropdownMenuItem(value: 'quiz', child: Text('Quiz')),
                        DropdownMenuItem(value: 'midterm', child: Text('Midterm')),
                        DropdownMenuItem(value: 'final', child: Text('Final')),
                        DropdownMenuItem(value: 'practice', child: Text('Practice')),
                      ],
                      onChanged: (value) => onExamTypeChanged(value ?? 'quiz'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _TextInput(label: 'Duration', controller: durationCtrl, hint: '60', suffix: 'min', number: true)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _TextInput(label: 'Attempts', controller: attemptsCtrl, hint: '1', number: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _TextInput(label: 'Passing score', controller: passingScoreCtrl, hint: '60', suffix: '%', number: true)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _DateField(label: 'Start date', value: availableFrom, onChanged: onStartChanged)),
                  const SizedBox(width: 12),
                  Expanded(child: _DateField(label: 'End date', value: availableTo, onChanged: onEndChanged)),
                ],
              ),
              const SizedBox(height: 18),
              _SwitchTile(title: 'Shuffle questions', subtitle: 'Randomize question order per attempt.', value: shuffleQuestions, onChanged: onShuffleQuestionsChanged),
              _SwitchTile(title: 'Shuffle answers', subtitle: 'Randomize options where supported.', value: shuffleAnswers, onChanged: onShuffleAnswersChanged),
              _SwitchTile(title: 'Show result immediately', subtitle: 'UI preference; backend field not available yet.', value: showResultImmediately, onChanged: onShowResultChanged),
              _SwitchTile(title: 'Allow review', subtitle: 'UI preference; backend field not available yet.', value: allowReview, onChanged: onAllowReviewChanged),
              const SizedBox(height: 12),
              _PublishSelector(value: publishAfterSave, onChanged: onPublishChanged),
              const SizedBox(height: 12),
              _ScopeMetric(label: 'Current total points', value: _points(totalPoints), icon: Icons.scoreboard_outlined),
            ],
          );

          final content = !wide
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [left, const SizedBox(height: 22), right],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: left),
                    const SizedBox(width: 26),
                    Expanded(flex: 9, child: right),
                  ],
                );

          return Scrollbar(
            child: SingleChildScrollView(
              child: content,
            ),
          );
        },
      ),
    );
  }
}


class _TemplateAppliedCard extends StatelessWidget {
  final ExamTemplateModel template;

  const _TemplateAppliedCard({required this.template});

  @override
  Widget build(BuildContext context) {
    final distribution = template.sections.where((section) => section.questionCount > 0).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final chips = <String>[
      '${template.questionCount} questions',
      '${template.durationMinutes} min',
      '${template.maxAttempts} attempt${template.maxAttempts == 1 ? '' : 's'}',
      '${template.passingScore.toStringAsFixed(0)}% pass',
      if (distribution.isNotEmpty) ...distribution.map((section) => '${section.questionCount} ${_shortTemplateTypeLabel(section.questionType)}'),
      if (distribution.isEmpty && template.preferredType != null) template.preferredType!.label,
      if (template.preferredDifficulty != null) template.preferredDifficulty!.label,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  template.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w900, fontSize: 13.5),
                ),
              ),
            ],
          ),
          if (template.description.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              template.description.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: chips.map((chip) => _TinyPill(label: chip)).toList(),
          ),
        ],
      ),
    );
  }
}


String _shortTemplateTypeLabel(String questionType) {
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

class _QuestionSelectionStep extends StatelessWidget {
  final List<_TopicTarget> targets;
  final List<QuestionModel> questions;
  final ExamTemplateModel template;
  final int scopedCount;
  final ValueChanged<QuestionModel> onRemove;
  final ValueChanged<QuestionModel> onReplace;

  const _QuestionSelectionStep({
    required this.targets,
    required this.questions,
    required this.template,
    required this.scopedCount,
    required this.onRemove,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <QuestionType, List<QuestionModel>>{};
    for (final type in QuestionType.values) {
      final items = questions.where((question) => question.type == type).toList();
      if (items.isNotEmpty) grouped[type] = items;
    }

    return _Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Row(
              children: [
                Expanded(
                  child: _PanelTitle(
                    icon: Icons.playlist_add_check_rounded,
                    title: 'Question set',
                    subtitle:
                        '${template.name} template • ${questions.length} selected from $scopedCount scoped questions. Replace or remove questions before settings.',
                  ),
                ),
                const SizedBox(width: 18),
                _QuestionSetSummary(label: 'Target', value: '${template.questionCount}'),
                const SizedBox(width: 10),
                _QuestionSetSummary(label: 'Selected', value: '${questions.length}'),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          Expanded(
            child: questions.isEmpty
                ? const _EmptyState(
                    title: 'No questions selected',
                    message: 'The chosen scope has no saved questions. Go back and pick another scope.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                    children: [
                      for (final entry in grouped.entries) ...[
                        _QuestionTypeSection(
                          type: entry.key,
                          questions: entry.value,
                          targets: targets,
                          onRemove: onRemove,
                          onReplace: onReplace,
                        ),
                        const SizedBox(height: 18),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _QuestionSetSummary extends StatelessWidget {
  final String label;
  final String value;

  const _QuestionSetSummary({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: AppColors.textTitle, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _QuestionTypeSection extends StatelessWidget {
  final QuestionType type;
  final List<QuestionModel> questions;
  final List<_TopicTarget> targets;
  final ValueChanged<QuestionModel> onRemove;
  final ValueChanged<QuestionModel> onReplace;

  const _QuestionTypeSection({
    required this.type,
    required this.questions,
    required this.targets,
    required this.onRemove,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Text(type.label, style: TextStyle(color: AppColors.textTitle, fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                _TinyPill(label: '${questions.length}'),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          for (var i = 0; i < questions.length; i++) ...[
            _QuestionSetRow(
              index: i + 1,
              question: questions[i],
              target: _targetForQuestionStatic(targets, questions[i]),
              onRemove: () => onRemove(questions[i]),
              onReplace: () => onReplace(questions[i]),
            ),
            if (i != questions.length - 1) Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _QuestionSetRow extends StatelessWidget {
  final int index;
  final QuestionModel question;
  final _TopicTarget? target;
  final VoidCallback onRemove;
  final VoidCallback onReplace;

  const _QuestionSetRow({
    required this.index,
    required this.question,
    required this.target,
    required this.onRemove,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _IndexBadge(index: index, selected: true),
          const SizedBox(width: 12),
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.text.replaceAll('\n', ' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w900, fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                Text(
                  _questionMetaWithoutType(question),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 3,
            child: Text(
              _contextLabel(question, target),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          _TinyPill(label: '${question.maxScore} pt'),
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: onReplace,
            icon: const Icon(Icons.swap_horiz_rounded, size: 15),
            label: const Text('Replace'),
          ),
          const SizedBox(width: 2),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove',
            icon: Icon(Icons.close_rounded, color: AppColors.dangerText, size: 19),
          ),
        ],
      ),
    );
  }
}

class _PreviewStep extends StatelessWidget {
  final List<_TopicTarget> targets;
  final List<QuestionModel> questions;
  final double totalPoints;
  final String title;
  final bool publishAfterSave;
  final bool showResultImmediately;
  final bool allowReview;
  const _PreviewStep({
    required this.targets,
    required this.questions,
    required this.totalPoints,
    required this.title,
    required this.publishAfterSave,
    required this.showResultImmediately,
    required this.allowReview,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <QuestionType, List<QuestionModel>>{};
    for (final type in QuestionType.values) {
      final items = questions.where((question) => question.type == type).toList();
      if (items.isNotEmpty) grouped[type] = items;
    }

    int startIndexFor(QuestionType type) {
      var total = 0;
      for (final entry in grouped.entries) {
        if (entry.key == type) return total;
        total += entry.value.length;
      }
      return 0;
    }

    return _Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: _PanelTitle(
              icon: Icons.preview_outlined,
              title: 'Preview before save',
              subtitle: '$title • ${questions.length} questions • ${_points(totalPoints)} points',
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          Expanded(
            child: questions.isEmpty
                ? const _EmptyState(title: 'No selected questions', message: 'Go back and select at least one question.')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    children: [
                      for (final entry in grouped.entries) ...[
                        _PreviewQuestionTypeSection(
                          type: entry.key,
                          questions: entry.value,
                          targets: targets,
                          startIndex: startIndexFor(entry.key),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
          ),
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                _TinyPill(label: showResultImmediately ? 'Result immediately' : 'Result delayed'),
                const SizedBox(width: 8),
                _TinyPill(label: allowReview ? 'Review allowed' : 'Review disabled'),
                const Spacer(),
                Text(publishAfterSave ? 'Ready to publish' : 'Ready to save', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowFooter extends StatelessWidget {
  final int step;
  final bool saving;
  final bool publishAfterSave;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _FlowFooter({
    required this.step,
    required this.saving,
    required this.publishAfterSave,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cta = step == 3 ? (publishAfterSave ? 'Save & Publish' : 'Save Exam') : 'Continue';
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              children: [
                _FooterActionButton(
                  label: step == 1 ? 'Back to Question Bank' : 'Back',
                  icon: step == 1 ? Icons.close_rounded : Icons.arrow_back_rounded,
                  onPressed: saving ? null : onBack,
                  primary: false,
                ),
                const Spacer(),
                _FooterActionButton(
                  label: saving ? 'Saving...' : cta,
                  icon: step == 3 ? Icons.save_rounded : Icons.arrow_forward_rounded,
                  onPressed: saving ? null : onNext,
                  primary: true,
                  loading: saving,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool loading;

  const _FooterActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.primary,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        else
          Icon(icon, size: 16),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    const size = Size(0, 44);
    if (primary) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(minimumSize: size, padding: const EdgeInsets.symmetric(horizontal: 22), shape: shape),
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(minimumSize: size, padding: const EdgeInsets.symmetric(horizontal: 22), shape: shape),
      child: child,
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Panel({required this.child, this.padding = const EdgeInsets.all(22)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.shadowThin, blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }
}

class _PanelTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _PanelTitle({required this.icon, required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: AppColors.primary, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textTitle)),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class _SelectField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool compact;

  const _SelectField({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final dropdown = DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      hint: items.isNotEmpty ? items.first.child : null,
      items: items,
      onChanged: onChanged,
      decoration: _input(hint).copyWith(
        contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: compact ? 11 : 14),
      ),
      style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w800, fontSize: 13),
    );
    if (label.isEmpty) return dropdown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        dropdown,
      ],
    );
  }
}

class _TextInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final String? suffix;
  final int maxLines;
  final bool number;
  final bool compact;

  const _TextInput({
    required this.label,
    required this.controller,
    required this.hint,
    this.suffix,
    this.maxLines = 1,
    this.number = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: _input(hint).copyWith(
        suffixText: suffix,
        contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: compact ? 11 : 14),
      ),
      style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w700, fontSize: 13),
    );
    if (label.isEmpty) return field;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_Label(label), field]);
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _SearchBox({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: _input(hint).copyWith(
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      ),
      style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w700, fontSize: 13),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  const _DateField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final now = DateTime.now();
            final date = await showDatePicker(
              context: context,
              initialDate: value ?? now,
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 5),
            );
            if (date == null || !context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: value == null ? TimeOfDay.now() : TimeOfDay.fromDateTime(value!),
            );
            if (time == null) return;
            onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
          },
          child: InputDecorator(
            decoration: _input('Select date'),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value == null ? 'Not set' : _formatDateTime(value!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: value == null ? AppColors.textMuted : AppColors.textTitle, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                if (value != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onChanged(null),
                    icon: Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                  )
                else
                  Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w900, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 11.5)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PublishSelector extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PublishSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ChoiceCard(title: 'Save exam', subtitle: 'Stored in quizzes, hidden until published', selected: !value, onTap: () => onChanged(false))),
        const SizedBox(width: 10),
        Expanded(child: _ChoiceCard(title: 'Publish after save', subtitle: 'Creates snapshots and opens exam', selected: value, onTap: () => onChanged(true))),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceCard({required this.title, required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surfaceBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? AppColors.primary : AppColors.textMuted, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w900, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 10.8)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _ScopeMetric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textTitle)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniQuestionPreview extends StatelessWidget {
  final List<QuestionModel> questions;
  const _MiniQuestionPreview({required this.questions});

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) return const _EmptyState(title: 'No matching questions', message: 'This scope has no saved questions yet.');
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < questions.length; i++) ...[
            _MiniQuestionRow(question: questions[i]),
            if (i != questions.length - 1) Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _MiniQuestionRow extends StatelessWidget {
  final QuestionModel question;
  const _MiniQuestionRow({required this.question});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(question.text.replaceAll('\n', ' '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          _TinyPill(label: question.typeLabel),
          const SizedBox(width: 6),
          _TinyPill(label: question.difficultyLabel),
        ],
      ),
    );
  }
}

class _ExamQuestionRow extends StatelessWidget {
  final int index;
  final QuestionModel question;
  final _TopicTarget? target;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback? onReplace;

  const _ExamQuestionRow({
    required this.index,
    required this.question,
    required this.target,
    required this.selected,
    required this.onSelected,
    this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onSelected(!selected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: selected ? AppColors.selectedBg : AppColors.cardBg,
        child: Row(
          children: [
            Checkbox(value: selected, onChanged: (value) => onSelected(value ?? false)),
            const SizedBox(width: 8),
            _IndexBadge(index: index + 1, selected: selected),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(question.text.replaceAll('\n', ' '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w900, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  Text(_questionMeta(question), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Text(_contextLabel(question, target), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            const SizedBox(width: 10),
            _TinyPill(label: '${question.maxScore} pt'),
            if (onReplace != null) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onReplace,
                icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                label: const Text('Replace'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class _PreviewQuestionTypeSection extends StatelessWidget {
  final QuestionType type;
  final List<QuestionModel> questions;
  final List<_TopicTarget> targets;
  final int startIndex;

  const _PreviewQuestionTypeSection({
    required this.type,
    required this.questions,
    required this.targets,
    required this.startIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 11),
            child: Row(
              children: [
                Text(type.label, style: TextStyle(color: AppColors.textTitle, fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                _TinyPill(label: '${questions.length}'),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          for (var i = 0; i < questions.length; i++) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: _PreviewQuestionCard(
                index: startIndex + i,
                question: questions[i],
                target: _targetForQuestionStatic(targets, questions[i]),
              ),
            ),
            if (i != questions.length - 1) Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _PreviewQuestionCard extends StatelessWidget {
  final int index;
  final QuestionModel question;
  final _TopicTarget? target;

  const _PreviewQuestionCard({required this.index, required this.question, required this.target});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IndexBadge(index: index + 1, selected: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(question.text, style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w900, fontSize: 15, height: 1.32)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TinyPill(label: question.typeLabel),
                        _TinyPill(label: question.difficultyLabel),
                        _TinyPill(label: '${question.maxScore} point${question.maxScore == 1 ? '' : 's'}'),
                        _TinyPill(label: _sourceLabel(question.source)),
                        _TinyPill(label: _contextLabel(question, target)),
                        if (question.learningOutcomes.isNotEmpty)
                          _TinyPill(label: 'LO: ${question.learningOutcomes.map((lo) => lo.title).join(', ')}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AnswerPreview(question: question),
          if ((question.explanation ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Explanation', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
            const SizedBox(height: 4),
            Text(question.explanation!, style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w600, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _AnswerPreview extends StatelessWidget {
  final QuestionModel question;
  const _AnswerPreview({required this.question});

  @override
  Widget build(BuildContext context) {
    if (question.options.isEmpty) {
      return _AnswerBox(label: 'Correct answer', value: question.expectedAnswer ?? question.sampleAnswer ?? '-');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Answers', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: question.options.map((option) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: option.isCorrect ? AppColors.successBg : AppColors.surfaceBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: option.isCorrect ? AppColors.successText.withOpacity(0.28) : AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(option.isCorrect ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 15, color: option.isCorrect ? AppColors.successText : AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(option.text, style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w800, fontSize: 12)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AnswerBox extends StatelessWidget {
  final String label;
  final String value;
  const _AnswerBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surfaceBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w800)),
      ],),
    );
  }
}

class _ReplaceQuestionDialog extends StatefulWidget {
  final QuestionModel original;
  final List<QuestionModel> candidates;
  final List<QuestionModel> relaxedCandidates;

  const _ReplaceQuestionDialog({required this.original, required this.candidates, required this.relaxedCandidates});

  @override
  State<_ReplaceQuestionDialog> createState() => _ReplaceQuestionDialogState();
}

class _ReplaceQuestionDialogState extends State<_ReplaceQuestionDialog> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final questions = _expanded ? widget.relaxedCandidates : widget.candidates;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: _PanelTitle(
                icon: Icons.swap_horiz_rounded,
                title: 'Replace question',
                subtitle: _expanded
                    ? 'Expanded alternatives from the same scope.'
                    : 'Strict alternatives match type, difficulty, and topic or LO where possible.',
                trailing: TextButton.icon(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.filter_alt_rounded : Icons.open_in_full_rounded, size: 16),
                  label: Text(_expanded ? 'Strict match' : 'Expand filter'),
                ),
              ),
            ),
            Divider(height: 1, color: AppColors.border),
            Expanded(
              child: questions.isEmpty
                  ? const _EmptyState(title: 'No alternatives found', message: 'Expand the filter or go back to the selection step.')
                  : ListView.separated(
                      itemCount: questions.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final question = questions[index];
                        return ListTile(
                          onTap: () => Navigator.of(context).pop(question),
                          title: Text(question.text.replaceAll('\n', ' '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text(_questionMeta(question), maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.arrow_forward_rounded),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamSavedDialog extends StatelessWidget {
  final String title;
  final String message;
  final int examId;
  const _ExamSavedDialog({required this.title, required this.message, required this.examId});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      icon: Icon(Icons.check_circle_rounded, color: AppColors.successText, size: 36),
      title: Text(title),
      content: Text('$message\n\nExam ID: $examId'),
      actions: [
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ],
    );
  }
}

class _IndexBadge extends StatelessWidget {
  final int index;
  final bool selected;
  const _IndexBadge({required this.index, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$index', style: TextStyle(color: selected ? Colors.white : AppColors.primary, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class _TinyPill extends StatelessWidget {
  final String label;
  const _TinyPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(text, style: TextStyle(color: AppColors.textTitle, fontSize: 12.5, fontWeight: FontWeight.w900)),
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
        border: Border.all(color: AppColors.dangerText.withOpacity(0.25)),
      ),
      child: Text(message, style: TextStyle(color: AppColors.dangerText, fontWeight: FontWeight.w800)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;
  const _EmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 38, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

InputDecoration _input(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.surfaceBg,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
  );
}

List<MaterialItem> _materialOptions(List<_TopicTarget> targets, int? moduleId) {
  final seen = <int>{};
  final result = <MaterialItem>[];
  for (final target in targets) {
    if (moduleId != null && target.module.id != moduleId) continue;
    if (seen.add(target.material.id)) result.add(target.material);
  }
  result.sort((a, b) => a.displayTitle.compareTo(b.displayTitle));
  return result;
}

List<_TopicTarget> _topicOptions(List<_TopicTarget> targets, int? moduleId, int? materialId) {
  return targets.where((target) {
    if (moduleId != null && target.module.id != moduleId) return false;
    if (materialId != null && target.material.id != materialId) return false;
    return true;
  }).toList();
}

List<QuestionLearningOutcomeRef> _outcomeOptions(List<QuestionModel> questions) {
  final byId = <int, QuestionLearningOutcomeRef>{};
  for (final question in questions) {
    for (final outcome in question.learningOutcomes) {
      byId[outcome.id] = outcome;
    }
  }
  final result = byId.values.toList()..sort((a, b) => a.title.compareTo(b.title));
  return result;
}

_TopicTarget? _targetForQuestionStatic(List<_TopicTarget> targets, QuestionModel question) {
  final topicId = question.topicId;
  if (topicId == null) return null;
  for (final target in targets) {
    if (target.topic.id == topicId) return target;
  }
  return null;
}

String _contextLabel(QuestionModel question, _TopicTarget? target) {
  final topic = question.topicName ?? target?.topicLabel;
  final material = question.materialName ?? target?.material.displayTitle;
  final module = question.moduleName ?? target?.module.title;
  final parts = [topic, material, module].whereType<String>().where((item) => item.trim().isNotEmpty).toList();
  return parts.isEmpty ? 'General' : parts.take(2).join(' • ');
}

String _questionMeta(QuestionModel question) {
  final lo = question.learningOutcomes.isEmpty
      ? 'No LO'
      : 'LO: ${question.learningOutcomes.map((item) => item.title).take(1).join(', ')}';
  return '${question.typeLabel} • ${question.difficultyLabel} • ${_sourceLabel(question.source)} • $lo';
}

String _questionMetaWithoutType(QuestionModel question) {
  final lo = question.learningOutcomes.isEmpty
      ? 'No LO'
      : 'LO: ${question.learningOutcomes.map((item) => item.title).take(1).join(', ')}';
  return '${question.difficultyLabel} • ${_sourceLabel(question.source)} • $lo';
}

String _sourceLabel(QuestionSource source) {
  switch (source) {
    case QuestionSource.aiGenerated:
      return 'AI';
    case QuestionSource.imported:
      return 'Imported';
    case QuestionSource.manual:
      return 'Manual';
  }
}

String _points(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}

String _formatDateTime(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$month-$day $hour:$minute';
}
