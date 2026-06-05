import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/error_mapper.dart';
import '../../../../../shared/widgets/app_ui_components.dart';
import '../../../data/courses_models.dart';
import '../../../data/exam_templates_storage.dart';
import '../../../data/learning_outcomes_models.dart';
import '../../../data/materials_models.dart';
import '../../../data/modules_materials_providers.dart';
import '../../../data/modules_models.dart';
import '../../../data/question_models.dart';
import '../../../data/question_vocabulary.dart';
import '../../../data/questions_api.dart';
import '../../../data/topics_models.dart';
import '../../controllers/course_details_controller.dart';
import '../../controllers/course_details_state.dart';
import '../course_outcomes_panel.dart';
import 'create_exam_flow.dart';

class CourseQuestionBankTab extends ConsumerStatefulWidget {
  final MyCourseItem course;

  const CourseQuestionBankTab({super.key, required this.course});

  @override
  ConsumerState<CourseQuestionBankTab> createState() => _CourseQuestionBankTabState();
}

class _CourseQuestionBankTabState extends ConsumerState<CourseQuestionBankTab> {
  final TextEditingController _searchController = TextEditingController();

  String _search = '';
  QuestionType? _filterType;
  QuestionDifficulty? _filterDiff;
  QuestionSource? _filterSource;
  bool? _filterUsed;
  int? _filterModuleId;
  int? _filterMaterialId;
  int? _filterTopicId;
  int? _filterOutcomeId;
  String? _selectedQuestionId;
  _ExamStartConfig? _examStartConfig;

  bool _loading = true;
  bool _creatingExam = false;
  bool _treeRequested = false;
  String? _error;
  List<QuestionModel> _questions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadQuestions();
      _loadCourseTree();
      ensureCourseLearningOutcomesLoaded(ref, widget.course.id);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(questionsApiProvider);
      final resp = await api.getCourseQuestions(courseId: widget.course.id);
      final enriched = await Future.wait(
        resp.questions.map((question) async {
          final id = question.remoteId;
          if (id == null) return question;
          try {
            return await api.getQuestion(
              courseId: widget.course.id,
              questionId: id,
            );
          } catch (_) {
            return question;
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        _questions = enriched;
        _loading = false;
        if (_selectedQuestionId != null &&
            !_questions.any((question) => question.id == _selectedQuestionId)) {
          _selectedQuestionId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mapApiFailure(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _loadCourseTree() async {
    if (_treeRequested) return;
    _treeRequested = true;
    try {
      await ref
          .read(courseDetailsControllerProvider(widget.course.id).notifier)
          .loadModulesAndAllMaterials();
    } catch (_) {
      // The question list can still work without the full authoring tree.
    }
  }

  void _onSearchChanged(String value) {
    if (value == _search) return;
    setState(() => _search = value);
  }

  Future<void> _editQuestion(
    QuestionModel question,
    List<_TopicTarget> topicTargets,
  ) async {
    final updated = await showDialog<QuestionModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditQuestionDialog(
        courseId: widget.course.id,
        question: question,
        topicTargets: topicTargets,
      ),
    );

    if (updated == null || !mounted) return;

    setState(() {
      _questions = _questions.map((item) {
        if (item.id == question.id || item.remoteId == question.remoteId) return updated;
        return item;
      }).toList();
      _selectedQuestionId = updated.id;
    });
  }

  void _openQuestionReview(
    QuestionModel question,
    List<_TopicTarget> topicTargets,
  ) {
    if (!mounted) return;
    setState(() => _selectedQuestionId = question.id);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _QuestionReviewDialog(
        question: question,
        topicTargets: topicTargets,
      ),
    );
  }

  void _showDeleteUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Delete is not available in the current backend API contract.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courseState = ref.watch(courseDetailsControllerProvider(widget.course.id));
    final topicTargets = _topicTargetsFromState(courseState);
    final filtered = _applyFilters(_questions, topicTargets);
    final selectedQuestionId = _selectedQuestion(filtered)?.id;

    if (_creatingExam) {
      final config = _examStartConfig;
      return CreateExamFlow(
        course: widget.course,
        questions: _questions,
        initialTemplate: config?.template,
        initialScopeModuleId: config?.moduleId,
        initialScopeMaterialId: config?.materialId,
        initialScopeTopicIds: config?.topicIds ?? const <int>{},
        initialScopeOutcomeIds: config?.outcomeIds ?? const <int>{},
        onCancel: () => setState(() {
          _creatingExam = false;
          _examStartConfig = null;
        }),
        onCreated: () async {
          await _loadQuestions();
          if (!mounted) return;
          setState(() {
            _creatingExam = false;
            _examStartConfig = null;
          });
        },
      );
    }

    return Container(
      color: AppColors.pageBg,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        children: [
          _QuestionBankHeader(
            loading: _loading,
            canCreateExam: _questions.isNotEmpty,
            onRefresh: _loadQuestions,
            onCreateExam: _openCreateExamStart,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _QuestionBankWorkspace(
              loading: _loading,
              error: _error == null ? null : _friendlyError(_error!),
              questions: filtered,
              allQuestionsCount: _questions.length,
              selectedQuestionId: selectedQuestionId,
              searchController: _searchController,
              filterModuleId: _filterModuleId,
              filterDiff: _filterDiff,
              filterType: _filterType,
              filterSource: _filterSource,
              filterUsed: _filterUsed,
              filterMaterialId: _filterMaterialId,
              filterTopicId: _filterTopicId,
              filterOutcomeId: _filterOutcomeId,
              modules: courseState.modules,
              topicTargets: topicTargets,
              allQuestions: _questions,
              onSearchChanged: _onSearchChanged,
              onSelectQuestion: (question) => _openQuestionReview(question, topicTargets),
              onModuleChanged: (value) => setState(() {
                _filterModuleId = value;
                if (value == null) {
                  _filterMaterialId = null;
                  _filterTopicId = null;
                } else if (_filterMaterialId != null &&
                    !_materialBelongsToModule(topicTargets, _filterMaterialId!, value)) {
                  _filterMaterialId = null;
                  _filterTopicId = null;
                }
              }),
              onMaterialChanged: (value) => setState(() {
                _filterMaterialId = value;
                if (value == null) {
                  _filterTopicId = null;
                } else if (_filterTopicId != null &&
                    !_topicBelongsToMaterial(topicTargets, _filterTopicId!, value)) {
                  _filterTopicId = null;
                }
              }),
              onTopicChanged: (value) => setState(() => _filterTopicId = value),
              onOutcomeChanged: (value) => setState(() => _filterOutcomeId = value),
              onSourceChanged: (value) => setState(() => _filterSource = value),
              onUsageChanged: (value) => setState(() => _filterUsed = value),
              onDifficultyChanged: (value) => setState(() => _filterDiff = value),
              onTypeChanged: (value) => setState(() => _filterType = value),
              onClearFilters: _clearFilters,
              onRetry: _loadQuestions,
              onEditQuestion: _editQuestion,
              onDeleteUnavailable: _showDeleteUnavailable,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateExamStart() async {
    if (_questions.isEmpty) return;
    await _loadCourseTree();
    await ensureCourseLearningOutcomesLoaded(ref, widget.course.id);
    List<ExamTemplateModel> templates;
    try {
      templates = await ref.read(examTemplatesStorageProvider).load(widget.course.id);
    } catch (_) {
      templates = [ExamTemplateModel.custom(widget.course.id)];
    }
    final outcomes = ref.read(courseLOProvider(widget.course.id));
    final latestState = ref.read(courseDetailsControllerProvider(widget.course.id));
    final latestTopicTargets = _topicTargetsFromState(latestState);
    if (!mounted) return;
    final config = await showDialog<_ExamStartConfig>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateExamStartDialog(
        course: widget.course,
        templates: templates,
        modules: latestState.modules,
        topicTargets: latestTopicTargets,
        outcomes: outcomes,
        questions: _questions,
      ),
    );
    if (config == null || !mounted) return;
    setState(() {
      _examStartConfig = config;
      _creatingExam = true;
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _search = '';
      _filterType = null;
      _filterDiff = null;
      _filterSource = null;
      _filterUsed = null;
      _filterModuleId = null;
      _filterMaterialId = null;
      _filterTopicId = null;
      _filterOutcomeId = null;
    });
  }

  QuestionModel? _selectedQuestion(List<QuestionModel> filtered) {
    if (filtered.isEmpty) return null;
    final id = _selectedQuestionId;
    if (id != null) {
      for (final question in filtered) {
        if (question.id == id) return question;
      }
    }
    return filtered.first;
  }

  List<QuestionModel> _applyFilters(List<QuestionModel> input, List<_TopicTarget> topicTargets) {
    return input.where((q) {
      final s = _search.trim().toLowerCase();
      if (s.isNotEmpty) {
        final matchesText = q.text.toLowerCase().contains(s);
        final matchesTopic = (q.topicName ?? '').toLowerCase().contains(s);
        final matchesModule = (q.moduleName ?? '').toLowerCase().contains(s);
        final matchesMaterial = (q.materialName ?? '').toLowerCase().contains(s);
        final matchesOutcome = q.learningOutcomes.any(
          (outcome) => outcome.title.toLowerCase().contains(s),
        );
        final matchesTags = q.tags.any((tag) => tag.toLowerCase().contains(s));
        final matchesType = q.typeLabel.toLowerCase().contains(s);
        final matchesDifficulty = q.difficultyLabel.toLowerCase().contains(s);
        final matchesSource = _sourceLabel(q.source).toLowerCase().contains(s);
        if (!matchesText &&
            !matchesTopic &&
            !matchesModule &&
            !matchesMaterial &&
            !matchesOutcome &&
            !matchesTags &&
            !matchesType &&
            !matchesDifficulty &&
            !matchesSource) {
          return false;
        }
      }
      final target = _targetForQuestion(topicTargets, q);
      if (_filterType != null && q.type != _filterType) return false;
      if (_filterDiff != null && q.difficulty != _filterDiff) return false;
      if (_filterSource != null && q.source != _filterSource) return false;
      if (_filterUsed != null && (q.usageCount > 0) != _filterUsed) return false;
      if (_filterModuleId != null && (q.moduleId ?? target?.module.id) != _filterModuleId) return false;
      if (_filterMaterialId != null && (q.materialId ?? target?.material.id) != _filterMaterialId) return false;
      if (_filterTopicId != null && (q.topicId ?? target?.topic.id) != _filterTopicId) return false;
      if (_filterOutcomeId != null && !q.learningOutcomes.any((outcome) => outcome.id == _filterOutcomeId)) {
        return false;
      }
      return true;
    }).toList();
  }

  List<_TopicTarget> _topicTargetsFromState(CourseDetailsState courseState) {
    final result = <_TopicTarget>[];
    for (final module in courseState.modules) {
      final materials = courseState.materials[module.id] ?? const <MaterialItem>[];
      final materialsById = {for (final material in materials) material.id: material};
      final topics = courseState.topics[module.id] ?? const <TopicItem>[];
      for (final topic in topics) {
        final material = materialsById[topic.materialId];
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

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('session expired') || lower.contains('login again')) {
      return 'Your session expired while loading questions. Please log in again.';
    }
    return raw.trim().isNotEmpty ? raw : 'Could not load saved questions right now.';
  }
}


enum _ExamScopeMode { topics, outcomes }

class _ExamStartConfig {
  final ExamTemplateModel template;
  final int? moduleId;
  final int? materialId;
  final Set<int> topicIds;
  final Set<int> outcomeIds;

  const _ExamStartConfig({
    required this.template,
    this.moduleId,
    this.materialId,
    this.topicIds = const <int>{},
    this.outcomeIds = const <int>{},
  });
}

class _CreateExamStartDialog extends StatefulWidget {
  final MyCourseItem course;
  final List<ExamTemplateModel> templates;
  final List<ModuleItem> modules;
  final List<_TopicTarget> topicTargets;
  final List<LearningOutcome> outcomes;
  final List<QuestionModel> questions;

  const _CreateExamStartDialog({
    required this.course,
    required this.templates,
    required this.modules,
    required this.topicTargets,
    required this.outcomes,
    required this.questions,
  });

  @override
  State<_CreateExamStartDialog> createState() => _CreateExamStartDialogState();
}

class _CreateExamStartDialogState extends State<_CreateExamStartDialog> {
  late ExamTemplateModel _template;
  int? _moduleId;
  int? _materialId;
  final Set<int> _topicIds = <int>{};
  final Set<int> _outcomeIds = <int>{};
  _ExamScopeMode _scopeMode = _ExamScopeMode.topics;
  String? _error;

  @override
  void initState() {
    super.initState();
    _template = widget.templates.firstWhere(
      (item) => !item.isCustom,
      orElse: () => widget.templates.isNotEmpty
          ? widget.templates.first
          : ExamTemplateModel.custom(widget.course.id),
    );
  }

  bool get _hasRequiredScope {
    return _scopeMode == _ExamScopeMode.topics ? _topicIds.isNotEmpty : _outcomeIds.isNotEmpty;
  }

  String get _scopeRequiredMessage {
    return _scopeMode == _ExamScopeMode.topics
        ? 'Select at least one topic or subtopic before building the question set.'
        : 'Select at least one learning outcome before building the question set.';
  }

  List<QuestionModel> _matchingQuestions() {
    if (!_hasRequiredScope) return const <QuestionModel>[];

    return widget.questions.where((question) {
      if (question.remoteId == null) return false;
      final target = _targetForQuestion(widget.topicTargets, question);
      final moduleId = question.moduleId ?? target?.module.id;
      final materialId = question.materialId ?? target?.material.id;
      final topicId = question.topicId ?? target?.topic.id;

      if (_moduleId != null && moduleId != _moduleId) return false;
      if (_materialId != null && materialId != _materialId) return false;

      if (_scopeMode == _ExamScopeMode.topics) {
        if (topicId == null || !_topicIds.contains(topicId)) return false;
      }

      if (_scopeMode == _ExamScopeMode.outcomes) {
        if (!question.learningOutcomes.any((outcome) => _outcomeIds.contains(outcome.id))) {
          return false;
        }
      }

      return true;
    }).toList();
  }


  List<QuestionModel> _eligibleQuestionsForTemplate(List<QuestionModel> matching) {
    final difficulty = _template.preferredDifficulty;
    if (difficulty == null) return matching;
    return matching.where((question) => question.difficulty == difficulty).toList();
  }

  List<_TemplateRequirementGap> _templateRequirementGaps(List<QuestionModel> matching) {
    final activeSections = _template.sections.where((section) => section.questionCount > 0).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    if (activeSections.isEmpty) {
      final available = _eligibleQuestionsForTemplate(matching).length;
      return available >= _template.questionCount
          ? const <_TemplateRequirementGap>[]
          : [
              _TemplateRequirementGap(
                label: 'Total questions',
                requiredCount: _template.questionCount,
                availableCount: available,
              ),
            ];
    }

    final eligible = _eligibleQuestionsForTemplate(matching);
    final gaps = <_TemplateRequirementGap>[];
    for (final section in activeSections) {
      final type = parseQuestionType(section.questionType);
      final available = eligible.where((question) => question.type == type).length;
      if (available < section.questionCount) {
        gaps.add(_TemplateRequirementGap(
          label: _templateQuestionTypeLabel(section.questionType),
          requiredCount: section.questionCount,
          availableCount: available,
        ));
      }
    }
    return gaps;
  }

  String _gapsMessage(List<_TemplateRequirementGap> gaps) {
    return 'Not enough questions for this template distribution: ${gaps.map((gap) => '${gap.label} requires ${gap.requiredCount}, found ${gap.availableCount}').join('; ')}.';
  }

  void _continue() {
    if (!_hasRequiredScope) {
      setState(() => _error = _scopeRequiredMessage);
      return;
    }

    final matching = _matchingQuestions();
    if (matching.isEmpty) {
      setState(() => _error = 'No saved questions match the selected scope. Choose a different topic/subtopic or learning outcome.');
      return;
    }
    final gaps = _templateRequirementGaps(matching);
    if (gaps.isNotEmpty) {
      setState(() => _error = _gapsMessage(gaps));
      return;
    }
    Navigator.of(context).pop(_ExamStartConfig(
      template: _template,
      moduleId: _moduleId,
      materialId: _materialId,
      topicIds: _scopeMode == _ExamScopeMode.topics ? Set<int>.from(_topicIds) : const <int>{},
      outcomeIds: _scopeMode == _ExamScopeMode.outcomes ? Set<int>.from(_outcomeIds) : const <int>{},
    ),);
  }

  @override
  Widget build(BuildContext context) {
    final materialOptions = _materialFilterOptions(widget.topicTargets, _moduleId);
    final visibleTargets = widget.topicTargets.where((target) {
      if (_moduleId != null && target.module.id != _moduleId) return false;
      if (_materialId != null && target.material.id != _materialId) return false;
      return true;
    }).toList();
    final outcomeOptions = _learningOutcomeSetupOptions(widget.questions, widget.outcomes);
    final matching = _matchingQuestions();
    final eligibleMatching = _eligibleQuestionsForTemplate(matching);
    final requirementGaps = _templateRequirementGaps(matching);
    final templateItems = widget.templates.isNotEmpty ? widget.templates : <ExamTemplateModel>[_template];

    final templateValue = _template.name;
    final templateLabels = templateItems.map((item) => item.name).toList();
    final moduleValue = _selectedModuleLabel(widget.modules, _moduleId);
    final moduleItems = <String>['All modules', ...widget.modules.map(_moduleLabel)];
    final materialValue = _selectedMaterialFilterLabel(materialOptions, _materialId);
    final materialItems = <String>['All materials', ...materialOptions.map((option) => option.label)];

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 780),
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
                        child: const Icon(Icons.playlist_add_check_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Create Exam Setup',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose a template, then pick either topics/subtopics or learning outcomes.',
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
                            final fieldWidth = twoCols ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
                            final fields = <Widget>[
                              _SetupDropdownField(
                                label: 'Template',
                                width: fieldWidth,
                                value: templateValue,
                                items: templateLabels,
                                onChanged: (value) {
                                  final selected = templateItems.cast<ExamTemplateModel?>().firstWhere(
                                        (item) => item != null && item.name == value,
                                        orElse: () => null,
                                      );
                                  if (selected == null) return;
                                  setState(() {
                                    _template = selected;
                                    _error = null;
                                  });
                                },
                              ),
                              _SetupDropdownField(
                                label: 'Module',
                                width: fieldWidth,
                                value: moduleValue,
                                items: moduleItems,
                                onChanged: (value) {
                                  final module = widget.modules.cast<ModuleItem?>().firstWhere(
                                        (item) => item != null && _moduleLabel(item) == value,
                                        orElse: () => null,
                                      );
                                  setState(() {
                                    _moduleId = module?.id;
                                    _materialId = null;
                                    _topicIds.clear();
                                    _error = null;
                                  });
                                },
                              ),
                              _SetupDropdownField(
                                label: 'Material',
                                width: fieldWidth,
                                value: materialValue,
                                items: materialItems,
                                onChanged: (value) {
                                  final option = materialOptions.cast<_FilterOption?>().firstWhere(
                                        (item) => item != null && item.label == value,
                                        orElse: () => null,
                                      );
                                  setState(() {
                                    _materialId = option?.id;
                                    _topicIds.clear();
                                    _error = null;
                                  });
                                },
                              ),
                            ];

                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: fields,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _ScopeModeSelector(
                          mode: _scopeMode,
                          selectedTopicCount: _topicIds.length,
                          selectedOutcomeCount: _outcomeIds.length,
                          onChanged: (mode) {
                            if (mode == _scopeMode) return;
                            setState(() {
                              _scopeMode = mode;
                              if (mode == _ExamScopeMode.topics) {
                                _outcomeIds.clear();
                              } else {
                                _topicIds.clear();
                              }
                              _error = null;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        if (_scopeMode == _ExamScopeMode.topics)
                          _SetupTopicTreePicker(
                            targets: visibleTargets,
                            selectedTopicIds: _topicIds,
                            onChanged: (ids) {
                              setState(() {
                                _topicIds
                                  ..clear()
                                  ..addAll(ids);
                                _error = null;
                              });
                            },
                          )
                        else
                          _SetupOutcomePicker(
                            outcomes: outcomeOptions,
                            selectedOutcomeIds: _outcomeIds,
                            onChanged: (ids) {
                              setState(() {
                                _outcomeIds
                                  ..clear()
                                  ..addAll(ids);
                                _error = null;
                              });
                            },
                          ),
                        const SizedBox(height: 14),
                        _SetupInlineSummary(
                          matchingCount: eligibleMatching.length,
                          targetCount: _template.questionCount,
                          durationMinutes: _template.durationMinutes,
                          publishAfterSave: _template.publishAfterSave,
                        ),
                        const SizedBox(height: 10),
                        _TemplateDistributionStatus(
                          template: _template,
                          gaps: requirementGaps,
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
                        onPressed: _hasRequiredScope && matching.isNotEmpty ? _continue : null,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                        label: const Text('Build Question Set'),
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


class _TemplateRequirementGap {
  final String label;
  final int requiredCount;
  final int availableCount;

  const _TemplateRequirementGap({
    required this.label,
    required this.requiredCount,
    required this.availableCount,
  });
}

class _TemplateDistributionStatus extends StatelessWidget {
  final ExamTemplateModel template;
  final List<_TemplateRequirementGap> gaps;

  const _TemplateDistributionStatus({required this.template, required this.gaps});

  @override
  Widget build(BuildContext context) {
    final distribution = _templateDistributionText(template);
    if (distribution.isEmpty) {
      return Text(
        'Template uses total question count only.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w700),
      );
    }
    final ok = gaps.isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ok ? AppColors.successBg : AppColors.dangerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ok ? AppColors.successText.withOpacity(0.24) : AppColors.dangerBorder),
      ),
      child: Text(
        ok ? 'Distribution ready: $distribution' : 'Distribution shortage: ${gaps.map((gap) => '${gap.label} ${gap.availableCount}/${gap.requiredCount}').join(' • ')}',
        style: TextStyle(
          color: ok ? AppColors.successText : AppColors.dangerText,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _templateDistributionText(ExamTemplateModel template) {
  final sections = template.sections.where((section) => section.questionCount > 0).toList()
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  if (sections.isEmpty) return '';
  return sections.map((section) => '${section.questionCount} ${_shortTemplateQuestionTypeLabel(section.questionType)}').join(' / ');
}

String _templateQuestionTypeLabel(String questionType) {
  switch (questionType) {
    case 'true_false':
      return 'True / False';
    case 'short_answer':
      return 'Short Answer';
    case 'essay':
      return 'Essay';
    case 'multi_select':
      return 'Multi-Select';
    default:
      return 'Multiple Choice';
  }
}

String _shortTemplateQuestionTypeLabel(String questionType) {
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

class _SetupDropdownField extends StatelessWidget {
  final String label;
  final double width;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _SetupDropdownField({
    required this.label,
    required this.width,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          FigmaUmDropdown40(
            width: width,
            value: value,
            items: items,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ScopeModeSelector extends StatelessWidget {
  final _ExamScopeMode mode;
  final int selectedTopicCount;
  final int selectedOutcomeCount;
  final ValueChanged<_ExamScopeMode> onChanged;

  const _ScopeModeSelector({
    required this.mode,
    required this.selectedTopicCount,
    required this.selectedOutcomeCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.headerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ScopeModeOption(
              title: 'Topics / Subtopics',
              subtitle: selectedTopicCount == 0 ? 'Required' : '$selectedTopicCount selected',
              selected: mode == _ExamScopeMode.topics,
              onTap: () => onChanged(_ExamScopeMode.topics),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ScopeModeOption(
              title: 'Learning Outcomes',
              subtitle: selectedOutcomeCount == 0 ? 'Required' : '$selectedOutcomeCount selected',
              selected: mode == _ExamScopeMode.outcomes,
              onTap: () => onChanged(_ExamScopeMode.outcomes),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeModeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ScopeModeOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: selected ? AppColors.borderGray : Colors.transparent),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
              : const [],
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? AppColors.primary : AppColors.textMuted,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? AppColors.textTitle : AppColors.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.8,
                      fontWeight: FontWeight.w700,
                    ),
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

class _SetupTopicTreePicker extends StatelessWidget {
  final List<_TopicTarget> targets;
  final Set<int> selectedTopicIds;
  final ValueChanged<Set<int>> onChanged;

  const _SetupTopicTreePicker({
    required this.targets,
    required this.selectedTopicIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final visibleIds = targets.map((target) => target.topic.id).toSet();
    final visibleSelectedIds = selectedTopicIds.intersection(visibleIds);
    final groups = <String, List<_TopicTarget>>{};
    final groupLabels = <String, String>{};
    for (final target in targets) {
      final key = '${target.module.id}:${target.material.id}';
      groups.putIfAbsent(key, () => <_TopicTarget>[]).add(target);
      groupLabels[key] = '${target.module.title} • ${target.material.displayTitle}';
    }

    return _SetupPickerFrame(
      title: 'Select topics / subtopics',
      subtitle: visibleSelectedIds.isEmpty
          ? 'Required. Pick one or more topics/subtopics.'
          : '${visibleSelectedIds.length} selected',
      onSelectAll: visibleIds.isEmpty ? null : () => onChanged(visibleIds),
      onClear: visibleSelectedIds.isEmpty ? null : () => onChanged(<int>{}),
      child: targets.isEmpty
          ? const _SetupPickerEmpty(message: 'No topics found for the selected module/material.')
          : SizedBox(
              height: 292,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: groups.entries.map((entry) {
                    final items = entry.value;
                    final byId = {for (final target in items) target.topic.id: target};
                    final childrenByParent = <int, List<_TopicTarget>>{};
                    final roots = <_TopicTarget>[];

                    for (final target in items) {
                      final parentId = target.topic.parentTopicId;
                      if (parentId != null && byId.containsKey(parentId)) {
                        childrenByParent.putIfAbsent(parentId, () => <_TopicTarget>[]).add(target);
                      } else {
                        roots.add(target);
                      }
                    }

                    roots.sort((a, b) => a.topic.orderIndex.compareTo(b.topic.orderIndex));
                    for (final children in childrenByParent.values) {
                      children.sort((a, b) => a.topic.orderIndex.compareTo(b.topic.orderIndex));
                    }

                    Set<int> branchIds(_TopicTarget target) {
                      final result = <int>{target.topic.id};
                      void collect(int parentId) {
                        for (final child in childrenByParent[parentId] ?? const <_TopicTarget>[]) {
                          result.add(child.topic.id);
                          collect(child.topic.id);
                        }
                      }
                      collect(target.topic.id);
                      return result;
                    }

                    void toggleBranch(_TopicTarget target) {
                      final ids = branchIds(target);
                      final next = Set<int>.from(selectedTopicIds)..removeWhere((id) => !visibleIds.contains(id));
                      final allSelected = ids.every(next.contains);
                      if (allSelected) {
                        next.removeAll(ids);
                      } else {
                        next.addAll(ids);
                      }
                      onChanged(next);
                    }

                    Widget buildNode(_TopicTarget target, int depth) {
                      final ids = branchIds(target);
                      final selectedCount = ids.where(selectedTopicIds.contains).length;
                      final checked = selectedCount == 0
                          ? false
                          : selectedCount == ids.length
                              ? true
                              : null;
                      final children = childrenByParent[target.topic.id] ?? const <_TopicTarget>[];
                      final hasChildren = children.isNotEmpty;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(7),
                            onTap: () => toggleBranch(target),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(6 + (depth * 22), 3, 6, 3),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: Checkbox(
                                      value: checked,
                                      tristate: true,
                                      onChanged: (_) => toggleBranch(target),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  if (depth > 0) ...[
                                    Icon(Icons.subdirectory_arrow_right_rounded, size: 15, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                  ] else if (hasChildren) ...[
                                    Icon(Icons.account_tree_outlined, size: 15, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          target.topic.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppColors.textTitle,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (hasChildren)
                                          Text(
                                            '${children.length} subtopic${children.length == 1 ? '' : 's'}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 10.7,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ...children.map((child) => buildNode(child, depth + 1)),
                        ],
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 5),
                            child: Text(
                              groupLabels[entry.key] ?? 'Material',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          ...roots.map((target) => buildNode(target, 0)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }
}

class _SetupOutcomePicker extends StatelessWidget {
  final List<_FilterOption> outcomes;
  final Set<int> selectedOutcomeIds;
  final ValueChanged<Set<int>> onChanged;

  const _SetupOutcomePicker({
    required this.outcomes,
    required this.selectedOutcomeIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final allIds = outcomes.map((outcome) => outcome.id).toSet();
    return _SetupPickerFrame(
      title: 'Select learning outcomes',
      subtitle: selectedOutcomeIds.isEmpty ? 'Required. Pick one or more learning outcomes.' : '${selectedOutcomeIds.length} selected',
      onSelectAll: allIds.isEmpty ? null : () => onChanged(allIds),
      onClear: selectedOutcomeIds.isEmpty ? null : () => onChanged(<int>{}),
      child: outcomes.isEmpty
          ? const _SetupPickerEmpty(message: 'No learning outcomes found for this course yet.')
          : SizedBox(
              height: 276,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: outcomes.map((outcome) {
                    final selected = selectedOutcomeIds.contains(outcome.id);
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        final next = Set<int>.from(selectedOutcomeIds);
                        selected ? next.remove(outcome.id) : next.add(outcome.id);
                        onChanged(next);
                      },
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 210, maxWidth: 340),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primarySoft : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: selected ? AppColors.primary.withOpacity(0.38) : AppColors.borderGray),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 16,
                              color: selected ? AppColors.primary : AppColors.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                outcome.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textTitle,
                                  fontSize: 12.2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }
}

class _SetupPickerFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClear;

  const _SetupPickerFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.onSelectAll,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.textTitle,
                        fontSize: 12.7,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onSelectAll,
                child: const Text('Select all'),
              ),
              TextButton(
                onPressed: onClear,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SetupPickerEmpty extends StatelessWidget {
  final String message;

  const _SetupPickerEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.headerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SetupInlineSummary extends StatelessWidget {
  final int matchingCount;
  final int targetCount;
  final int durationMinutes;
  final bool publishAfterSave;

  const _SetupInlineSummary({
    required this.matchingCount,
    required this.targetCount,
    required this.durationMinutes,
    required this.publishAfterSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.headerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          Expanded(child: _SetupSummaryText(label: 'Matching', value: '$matchingCount')),
          _SetupSummaryDivider(),
          Expanded(child: _SetupSummaryText(label: 'Target', value: '$targetCount')),
          _SetupSummaryDivider(),
          Expanded(child: _SetupSummaryText(label: 'Duration', value: '$durationMinutes min')),
          _SetupSummaryDivider(),
          Expanded(child: _SetupSummaryText(label: 'Mode', value: publishAfterSave ? 'Publish' : 'Draft')),
        ],
      ),
    );
  }
}

class _SetupSummaryText extends StatelessWidget {
  final String label;
  final String value;

  const _SetupSummaryText({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textTitle,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SetupSummaryDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: AppColors.borderGray,
    );
  }
}

class _StartTemplateDigest extends StatelessWidget {
  final ExamTemplateModel template;

  const _StartTemplateDigest({required this.template});

  @override
  Widget build(BuildContext context) {
    final mode = template.publishAfterSave ? 'Publish after save' : 'Save as draft';
    final distribution = _templateDistributionText(template);
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.description_outlined, color: AppColors.primary, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${template.questionCount} questions • ${template.durationMinutes} min${distribution.isEmpty ? '' : ' • $distribution'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.input.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '${template.maxAttempts} attempt${template.maxAttempts == 1 ? '' : 's'} • ${template.passingScore.toStringAsFixed(0)}% pass • $mode',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.mutedSmall.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StartMatchSummary extends StatelessWidget {
  final int matchingCount;
  final int targetCount;
  final bool publishAfterSave;

  const _StartMatchSummary({
    required this.matchingCount,
    required this.targetCount,
    required this.publishAfterSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          _StartMiniStat(label: 'Matching', value: '$matchingCount'),
          _StartDivider(),
          _StartMiniStat(label: 'Target', value: '$targetCount'),
          _StartDivider(),
          _StartMiniStat(label: 'Mode', value: publishAfterSave ? 'Publish' : 'Draft'),
        ],
      ),
    );
  }
}

class _StartMiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _StartMiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: AppText.mutedSmall.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: AppText.input.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: AppColors.borderGray,
    );
  }
}

class _StartSelect<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _StartSelect({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppText.label),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          menuMaxHeight: 320,
          hint: items.isNotEmpty ? items.first.child : null,
          items: items,
          onChanged: onChanged,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.muted, size: 22),
          style: AppText.input.copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.fieldBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            hintStyle: AppText.hint,
            enabledBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: AppColors.borderGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: AppColors.dangerText),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: AppColors.dangerText, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _StartSummaryCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _StartSummaryCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.description_outlined, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w900, fontSize: 13)),
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StartMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StartMetric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 9),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w800))),
          Text(value, style: TextStyle(color: AppColors.textTitle, fontSize: 17, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _StartPreview extends StatelessWidget {
  final List<QuestionModel> questions;

  const _StartPreview({required this.questions});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Matching question sample'.toUpperCase(), style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
          const SizedBox(height: 10),
          if (questions.isEmpty)
            Text('No question sample available.', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700))
          else
            ...questions.map((question) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 15, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          question.text.replaceAll('\n', ' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textTitle, fontSize: 12.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),),
        ],
      ),
    );
  }
}

class _QuestionBankHeader extends StatelessWidget {
  final bool loading;
  final bool canCreateExam;
  final VoidCallback onRefresh;
  final VoidCallback onCreateExam;

  const _QuestionBankHeader({
    required this.loading,
    required this.canCreateExam,
    required this.onRefresh,
    required this.onCreateExam,
  });

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
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: loading ? null : onRefresh,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white.withOpacity(0.5),
                  side: BorderSide(color: Colors.white.withOpacity(0.35)),
                  backgroundColor: Colors.white.withOpacity(0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
              FilledButton.icon(
                onPressed: canCreateExam ? onCreateExam : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  disabledBackgroundColor: Colors.white.withOpacity(0.45),
                  disabledForegroundColor: AppColors.primary.withOpacity(0.45),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                label: const Text('Create Exam'),
              ),
            ],
          );

          final copy = Column(
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
                  'Question bank',
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
                'Assessment Library',
                style: TextStyle(
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Search, inspect, edit, and assemble saved questions without leaving the course workspace.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.84),
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: 18),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  actions,
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}


class _QuestionBankWorkspace extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<QuestionModel> questions;
  final int allQuestionsCount;
  final String? selectedQuestionId;
  final TextEditingController searchController;
  final int? filterModuleId;
  final int? filterMaterialId;
  final int? filterTopicId;
  final int? filterOutcomeId;
  final QuestionDifficulty? filterDiff;
  final QuestionType? filterType;
  final QuestionSource? filterSource;
  final bool? filterUsed;
  final List<ModuleItem> modules;
  final List<_TopicTarget> topicTargets;
  final List<QuestionModel> allQuestions;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<QuestionModel> onSelectQuestion;
  final ValueChanged<int?> onModuleChanged;
  final ValueChanged<int?> onMaterialChanged;
  final ValueChanged<int?> onTopicChanged;
  final ValueChanged<int?> onOutcomeChanged;
  final ValueChanged<QuestionDifficulty?> onDifficultyChanged;
  final ValueChanged<QuestionType?> onTypeChanged;
  final ValueChanged<QuestionSource?> onSourceChanged;
  final ValueChanged<bool?> onUsageChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onRetry;
  final void Function(QuestionModel question, List<_TopicTarget> topicTargets) onEditQuestion;
  final VoidCallback onDeleteUnavailable;

  const _QuestionBankWorkspace({
    required this.loading,
    required this.error,
    required this.questions,
    required this.allQuestionsCount,
    required this.selectedQuestionId,
    required this.searchController,
    required this.filterModuleId,
    required this.filterMaterialId,
    required this.filterTopicId,
    required this.filterOutcomeId,
    required this.filterDiff,
    required this.filterType,
    required this.filterSource,
    required this.filterUsed,
    required this.modules,
    required this.topicTargets,
    required this.allQuestions,
    required this.onSearchChanged,
    required this.onSelectQuestion,
    required this.onModuleChanged,
    required this.onMaterialChanged,
    required this.onTopicChanged,
    required this.onOutcomeChanged,
    required this.onDifficultyChanged,
    required this.onTypeChanged,
    required this.onSourceChanged,
    required this.onUsageChanged,
    required this.onClearFilters,
    required this.onRetry,
    required this.onEditQuestion,
    required this.onDeleteUnavailable,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilters = searchController.text.trim().isNotEmpty ||
        filterModuleId != null ||
        filterMaterialId != null ||
        filterTopicId != null ||
        filterOutcomeId != null ||
        filterDiff != null ||
        filterType != null ||
        filterSource != null ||
        filterUsed != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowThin,
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            _QuestionBankToolbar(
              searchController: searchController,
              filterModuleId: filterModuleId,
              filterDiff: filterDiff,
              filterType: filterType,
              filterSource: filterSource,
              filterUsed: filterUsed,
              filterMaterialId: filterMaterialId,
              filterTopicId: filterTopicId,
              filterOutcomeId: filterOutcomeId,
              modules: modules,
              topicTargets: topicTargets,
              allQuestions: allQuestions,
              hasFilters: hasFilters,
              resultCount: questions.length,
              totalCount: allQuestionsCount,
              onSearchChanged: onSearchChanged,
              onModuleChanged: onModuleChanged,
              onMaterialChanged: onMaterialChanged,
              onTopicChanged: onTopicChanged,
              onOutcomeChanged: onOutcomeChanged,
              onDifficultyChanged: onDifficultyChanged,
              onTypeChanged: onTypeChanged,
              onSourceChanged: onSourceChanged,
              onUsageChanged: onUsageChanged,
              onClearFilters: onClearFilters,
            ),
            Divider(height: 1, color: AppColors.border),
            Expanded(
              child: loading
                  ? const _QuestionBankSkeleton()
                  : error != null
                      ? _QuestionBankError(message: error!, onRetry: onRetry)
                      : questions.isEmpty
                          ? _QuestionBankEmpty(hasQuestions: allQuestionsCount > 0)
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                return _QuestionRows(
                                  questions: questions,
                                  selectedQuestionId: selectedQuestionId,
                                  onSelectQuestion: onSelectQuestion,
                                  onEditQuestion: (question) => onEditQuestion(question, topicTargets),
                                  onDeleteUnavailable: onDeleteUnavailable,
                                  compact: constraints.maxWidth < 900,
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

class _QuestionBankToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final int? filterModuleId;
  final int? filterMaterialId;
  final int? filterTopicId;
  final int? filterOutcomeId;
  final QuestionDifficulty? filterDiff;
  final QuestionType? filterType;
  final QuestionSource? filterSource;
  final bool? filterUsed;
  final List<ModuleItem> modules;
  final List<_TopicTarget> topicTargets;
  final List<QuestionModel> allQuestions;
  final bool hasFilters;
  final int resultCount;
  final int totalCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onModuleChanged;
  final ValueChanged<int?> onMaterialChanged;
  final ValueChanged<int?> onTopicChanged;
  final ValueChanged<int?> onOutcomeChanged;
  final ValueChanged<QuestionDifficulty?> onDifficultyChanged;
  final ValueChanged<QuestionType?> onTypeChanged;
  final ValueChanged<QuestionSource?> onSourceChanged;
  final ValueChanged<bool?> onUsageChanged;
  final VoidCallback onClearFilters;

  const _QuestionBankToolbar({
    required this.searchController,
    required this.filterModuleId,
    required this.filterMaterialId,
    required this.filterTopicId,
    required this.filterOutcomeId,
    required this.filterDiff,
    required this.filterType,
    required this.filterSource,
    required this.filterUsed,
    required this.modules,
    required this.topicTargets,
    required this.allQuestions,
    required this.hasFilters,
    required this.resultCount,
    required this.totalCount,
    required this.onSearchChanged,
    required this.onModuleChanged,
    required this.onMaterialChanged,
    required this.onTopicChanged,
    required this.onOutcomeChanged,
    required this.onDifficultyChanged,
    required this.onTypeChanged,
    required this.onSourceChanged,
    required this.onUsageChanged,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final moduleValue = _selectedModuleLabel(modules, filterModuleId);
    final moduleItems = <String>['All modules', ...modules.map(_moduleLabel)];

    final materialOptions = _materialFilterOptions(topicTargets, filterModuleId);
    final materialValue = _selectedMaterialFilterLabel(materialOptions, filterMaterialId);
    final materialItems = <String>['All materials', ...materialOptions.map((option) => option.label)];

    final topicOptions = _topicFilterOptions(
      topicTargets,
      moduleId: filterModuleId,
      materialId: filterMaterialId,
    );
    final topicValue = _selectedTopicFilterLabel(topicOptions, filterTopicId);
    final topicItems = <String>['All topics / subtopics', ...topicOptions.map((option) => option.label)];

    final outcomeOptions = _learningOutcomeFilterOptions(allQuestions);
    final outcomeValue = _selectedOutcomeFilterLabel(outcomeOptions, filterOutcomeId);
    final outcomeItems = <String>['All LOs', ...outcomeOptions.map((option) => option.label)];

    final diffValue = filterDiff?.label ?? 'Any difficulty';
    final typeValue = filterType?.label ?? 'All types';
    final sourceValue = filterSource == null ? 'Any source' : _sourceLabel(filterSource!);
    final usageValue = filterUsed == null ? 'Used / unused' : (filterUsed! ? 'Used in exams' : 'Unused');

    return Container(
      color: AppColors.cardBg,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 1180;
              final search = FigmaUmSearch40(
                controller: searchController,
                hint: 'Search questions, topics, modules, materials, LOs, source, or tags...',
                onChanged: onSearchChanged,
              );

              final moduleDrop = FigmaUmDropdown40(
                width: narrow ? 210 : 180,
                value: moduleValue,
                items: moduleItems,
                onChanged: (value) {
                  if (value == 'All modules') {
                    onModuleChanged(null);
                    return;
                  }
                  final module = modules.cast<ModuleItem?>().firstWhere(
                        (m) => m != null && _moduleLabel(m) == value,
                        orElse: () => null,
                      );
                  onModuleChanged(module?.id);
                },
              );

              final materialDrop = FigmaUmDropdown40(
                width: narrow ? 230 : 210,
                value: materialValue,
                items: materialItems,
                onChanged: (value) {
                  if (value == 'All materials') {
                    onMaterialChanged(null);
                    return;
                  }
                  final option = materialOptions.cast<_FilterOption?>().firstWhere(
                        (item) => item != null && item.label == value,
                        orElse: () => null,
                      );
                  onMaterialChanged(option?.id);
                },
              );

              final topicDrop = FigmaUmDropdown40(
                width: narrow ? 260 : 230,
                value: topicValue,
                items: topicItems,
                onChanged: (value) {
                  if (value == 'All topics / subtopics') {
                    onTopicChanged(null);
                    return;
                  }
                  final option = topicOptions.cast<_FilterOption?>().firstWhere(
                        (item) => item != null && item.label == value,
                        orElse: () => null,
                      );
                  onTopicChanged(option?.id);
                },
              );

              final outcomeDrop = FigmaUmDropdown40(
                width: narrow ? 230 : 190,
                value: outcomeValue,
                items: outcomeItems,
                onChanged: (value) {
                  if (value == 'All LOs') {
                    onOutcomeChanged(null);
                    return;
                  }
                  final option = outcomeOptions.cast<_FilterOption?>().firstWhere(
                        (item) => item != null && item.label == value,
                        orElse: () => null,
                      );
                  onOutcomeChanged(option?.id);
                },
              );

              final diffDrop = FigmaUmDropdown40(
                width: narrow ? 170 : 152,
                value: diffValue,
                items: const ['Any difficulty', 'Easy', 'Medium', 'Hard'],
                onChanged: (value) => onDifficultyChanged(_difficultyFromLabel(value)),
              );

              final typeDrop = FigmaUmDropdown40(
                width: narrow ? 190 : 166,
                value: typeValue,
                items: const [
                  'All types',
                  'Multiple Choice',
                  'True / False',
                  'Short Answer',
                  'Essay',
                  'Multi-Select',
                  'Fill in the Blank',
                  'Numeric',
                  'Code',
                ],
                onChanged: (value) => onTypeChanged(_typeFromLabel(value)),
              );

              final sourceDrop = FigmaUmDropdown40(
                width: narrow ? 170 : 150,
                value: sourceValue,
                items: const ['Any source', 'Manual', 'AI', 'Imported'],
                onChanged: (value) => onSourceChanged(_sourceFromLabel(value)),
              );

              final usageDrop = FigmaUmDropdown40(
                width: narrow ? 170 : 154,
                value: usageValue,
                items: const ['Used / unused', 'Used in exams', 'Unused'],
                onChanged: (value) => onUsageChanged(_usageFromLabel(value)),
              );

              final countLabel = Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.headerBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$resultCount of $totalCount questions',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );

              return Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: narrow ? 12 : 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderGray),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: search),
                        if (!narrow) ...[
                          const SizedBox(width: 12),
                          countLabel,
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        moduleDrop,
                        materialDrop,
                        topicDrop,
                        outcomeDrop,
                        typeDrop,
                        diffDrop,
                        sourceDrop,
                        usageDrop,
                        if (narrow) countLabel,
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          if (hasFilters) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (searchController.text.trim().isNotEmpty)
                  _ActiveChip(label: 'Search: ${searchController.text.trim()}', onDeleted: () {
                    searchController.clear();
                    onSearchChanged('');
                  },),
                if (filterModuleId != null)
                  _ActiveChip(label: moduleValue, onDeleted: () => onModuleChanged(null)),
                if (filterMaterialId != null)
                  _ActiveChip(label: materialValue, onDeleted: () => onMaterialChanged(null)),
                if (filterTopicId != null)
                  _ActiveChip(label: topicValue, onDeleted: () => onTopicChanged(null)),
                if (filterOutcomeId != null)
                  _ActiveChip(label: outcomeValue, onDeleted: () => onOutcomeChanged(null)),
                if (filterType != null)
                  _ActiveChip(label: filterType!.label, onDeleted: () => onTypeChanged(null)),
                if (filterDiff != null)
                  _ActiveChip(label: filterDiff!.label, onDeleted: () => onDifficultyChanged(null)),
                if (filterSource != null)
                  _ActiveChip(label: _sourceLabel(filterSource!), onDeleted: () => onSourceChanged(null)),
                if (filterUsed != null)
                  _ActiveChip(label: filterUsed! ? 'Used in exams' : 'Unused', onDeleted: () => onUsageChanged(null)),
                TextButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Clear all'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onDeleted;

  const _ActiveChip({required this.label, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close_rounded, size: 16),
      backgroundColor: AppColors.headerBg,
      side: BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _QuestionRows extends StatelessWidget {
  final List<QuestionModel> questions;
  final String? selectedQuestionId;
  final ValueChanged<QuestionModel> onSelectQuestion;
  final ValueChanged<QuestionModel> onEditQuestion;
  final VoidCallback onDeleteUnavailable;
  final bool compact;

  const _QuestionRows({
    required this.questions,
    required this.selectedQuestionId,
    required this.onSelectQuestion,
    required this.onEditQuestion,
    required this.onDeleteUnavailable,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!compact) const _QuestionTableHeader(),
        Expanded(
          child: ListView.builder(
            primary: false,
            padding: EdgeInsets.zero,
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final question = questions[index];
              return _QuestionRow(
                index: index,
                question: question,
                selected: selectedQuestionId == question.id,
                isLast: index == questions.length - 1,
                compact: compact,
                onTap: () => onSelectQuestion(question),
                onEdit: () => onEditQuestion(question),
                onDeleteUnavailable: onDeleteUnavailable,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QuestionTableHeader extends StatelessWidget {
  const _QuestionTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 58, child: _HeaderCell('Question')),
          SizedBox(width: 22),
          Expanded(flex: 28, child: _HeaderCell('Context')),
          SizedBox(width: 18),
          SizedBox(width: 96, child: _HeaderCell('Actions')),
        ],
      ),
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
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppColors.textMuted,
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _QuestionRow extends StatefulWidget {
  final int index;
  final QuestionModel question;
  final bool selected;
  final bool isLast;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDeleteUnavailable;

  const _QuestionRow({
    required this.index,
    required this.question,
    required this.selected,
    required this.isLast,
    required this.compact,
    required this.onTap,
    required this.onEdit,
    required this.onDeleteUnavailable,
  });

  @override
  State<_QuestionRow> createState() => _QuestionRowState();
}

class _QuestionRowState extends State<_QuestionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final selected = widget.selected;
    final bg = selected
        ? AppColors.selectedBg
        : _hovered
            ? AppColors.hoverBg
            : AppColors.cardBg;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: bg,
        child: InkWell(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: widget.compact ? 10 : 11,
            ),
            decoration: BoxDecoration(
              border: widget.isLast ? null : Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: widget.compact ? _buildCompact(q, selected) : _buildWide(q, selected),
          ),
        ),
      ),
    );
  }

  Widget _buildWide(QuestionModel q, bool selected) {
    return Row(
      children: [
        Expanded(
          flex: 58,
          child: Row(
            children: [
              _QuestionNumber(index: widget.index, selected: selected),
              const SizedBox(width: 10),
              Expanded(child: _QuestionTextBlock(question: q)),
            ],
          ),
        ),
        const SizedBox(width: 22),
        Expanded(flex: 28, child: _ContextBlock(question: q)),
        const SizedBox(width: 18),
        SizedBox(
          width: 96,
          child: _RowActions(
            onEdit: widget.onEdit,
            onDeleteUnavailable: widget.onDeleteUnavailable,
          ),
        ),
      ],
    );
  }

  Widget _buildCompact(QuestionModel q, bool selected) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QuestionNumber(index: widget.index, selected: selected),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _QuestionTextBlock(question: q)),
                  _RowActions(
                    onEdit: widget.onEdit,
                    onDeleteUnavailable: widget.onDeleteUnavailable,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class _RowActions extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDeleteUnavailable;

  const _RowActions({required this.onEdit, required this.onDeleteUnavailable});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Edit question',
          child: IconButton(
            visualDensity: VisualDensity.compact,
            splashRadius: 18,
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
          ),
        ),
        Tooltip(
          message: 'Delete is not available in the current backend API',
          child: IconButton(
            visualDensity: VisualDensity.compact,
            splashRadius: 18,
            onPressed: onDeleteUnavailable,
            icon: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.dangerText),
          ),
        ),
      ],
    );
  }
}

class _QuestionNumber extends StatelessWidget {
  final int index;
  final bool selected;

  const _QuestionNumber({required this.index, required this.selected});

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
      child: Text(
        '${index + 1}',
        style: TextStyle(
          color: selected ? Colors.white : AppColors.primary,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _QuestionTextBlock extends StatelessWidget {
  final QuestionModel question;

  const _QuestionTextBlock({required this.question});

  @override
  Widget build(BuildContext context) {
    final outcome = question.learningOutcomes.isEmpty
        ? 'No linked LO'
        : "LO: ${question.learningOutcomes.map((item) => item.title).take(1).join(' • ')}";
    final meta = [
      outcome,
      _sourceLabel(question.source),
      _approvalLabel(question.approvalStatus),
      _usageLabel(question.usageCount),
      'Updated ${_shortDate(question.updatedAt)}',
    ].join(' • ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          question.text.replaceAll('\n', ' '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textTitle,
            fontSize: 13.4,
            height: 1.25,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ContextBlock extends StatelessWidget {
  final QuestionModel question;

  const _ContextBlock({required this.question});

  @override
  Widget build(BuildContext context) {
    final primary = _contextLabel(question);
    final secondary = question.moduleName ?? question.materialName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          primary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textTitle,
            fontSize: 12.3,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (secondary != null && secondary.trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            secondary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _QuestionReviewDialog extends StatelessWidget {
  final QuestionModel question;
  final List<_TopicTarget> topicTargets;

  const _QuestionReviewDialog({
    required this.question,
    required this.topicTargets,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 42),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: size.height * 0.72,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Material(
            color: AppColors.surfaceBg,
            child: _QuestionInspector(
              question: question,
              topicTargets: topicTargets,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionInspector extends StatelessWidget {
  final QuestionModel? question;
  final List<_TopicTarget> topicTargets;
  final VoidCallback? onClose;

  const _QuestionInspector({
    required this.question,
    required this.topicTargets,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;
    if (q == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        color: AppColors.surfaceBg,
        child: Center(
          child: Text(
            'Select a question to inspect its answer, context, and learning outcomes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, height: 1.5, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    final target = _targetForQuestion(topicTargets, q);

    return Container(
      color: AppColors.surfaceBg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceBg,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.fact_check_outlined, color: AppColors.primary, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question Review',
                        style: TextStyle(
                          color: AppColors.textTitle,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'ID ${q.remoteId ?? q.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (onClose != null) ...[
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: onClose,
                    icon: Icon(Icons.close_rounded, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.text,
                    style: TextStyle(
                      color: AppColors.textTitle,
                      fontSize: 17,
                      height: 1.42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TypeBadge(label: q.typeLabel),
                      _DifficultyBadge(diff: q.difficulty),
                      _SourceBadge(source: q.source),
                      _TinyMeta(
                        icon: Icons.verified_outlined,
                        label: _approvalLabel(q.approvalStatus),
                      ),
                      _TinyMeta(
                        icon: Icons.assignment_turned_in_outlined,
                        label: _usageLabel(q.usageCount),
                      ),
                      _TinyMeta(
                        icon: q.autoGradable ? Icons.bolt_rounded : Icons.rate_review_outlined,
                        label: q.autoGradable ? 'Auto-gradable' : 'Manual review',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _InspectorSection(
                    title: 'Answer',
                    child: _AnswerPreview(question: q),
                  ),
                  const SizedBox(height: 14),
                  _InspectorSection(
                    title: 'Context & usage',
                    child: Column(
                      children: [
                        _InspectorKv(label: 'Module', value: q.moduleName ?? target?.module.title ?? 'Not assigned'),
                        _InspectorKv(label: 'Material', value: q.materialName ?? target?.material.displayTitle ?? 'Not assigned'),
                        _InspectorKv(label: target?.parentTopicTitle == null ? 'Topic' : 'Parent', value: target?.parentTopicTitle ?? q.topicName ?? target?.topic.title ?? 'Not assigned'),
                        if (target?.parentTopicTitle != null)
                          _InspectorKv(label: 'Subtopic', value: q.topicName ?? target!.topic.title),
                        _InspectorKv(label: 'LO coverage', value: '${q.learningOutcomes.length} outcome${q.learningOutcomes.length == 1 ? '' : 's'}'),
                        _InspectorKv(label: 'Source', value: _sourceLabel(q.source)),
                        _InspectorKv(label: 'Usage', value: _usageLabel(q.usageCount)),
                        _InspectorKv(label: 'Status', value: _approvalLabel(q.approvalStatus)),
                        _InspectorKv(label: 'Updated', value: _shortDate(q.updatedAt)),
                        _InspectorKv(label: 'Score', value: '${q.maxScore} point${q.maxScore == 1 ? '' : 's'}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _InspectorSection(
                    title: 'Learning outcomes',
                    child: q.learningOutcomes.isEmpty
                        ? const _MutedBox('No learning outcome is linked to this question.')
                        : Column(
                            children: q.learningOutcomes
                                .map((outcome) => _OutcomeLine(title: outcome.title))
                                .toList(),
                          ),
                  ),
                  if (q.explanation != null && q.explanation!.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _InspectorSection(
                      title: 'Explanation',
                      child: _MutedBox(q.explanation!),
                    ),
                  ],
                  if (q.tags.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _InspectorSection(
                      title: 'Tags',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: q.tags.map((tag) => _TagChip(tag)).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectorSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _InspectorSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.65,
            ),
          ),
          const SizedBox(height: 10),
          child,
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
    if (question.options.isNotEmpty) {
      return Column(
        children: question.options.map((option) {
          final correct = option.isCorrect || question.correctOptionId == option.id;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: correct ? AppColors.successBg : AppColors.surfaceBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: correct ? AppColors.greenBorder : AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  correct ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 17,
                  color: correct ? AppColors.successText : AppColors.textHint,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    option.text,
                    style: TextStyle(
                      color: correct ? AppColors.successText : AppColors.textTitle,
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    final answer = _answerText(question);
    return _MutedBox(answer.isEmpty ? 'No answer stored for this question.' : answer);
  }
}

class _InspectorKv extends StatelessWidget {
  final String label;
  final String value;

  const _InspectorKv({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textTitle,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutcomeLine extends StatelessWidget {
  final String title;

  const _OutcomeLine({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.track_changes_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: AppColors.textTitle, fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _MutedBox extends StatelessWidget {
  final String text;

  const _MutedBox(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12.5,
          height: 1.45,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EditQuestionDialog extends ConsumerStatefulWidget {
  final int courseId;
  final QuestionModel question;
  final List<_TopicTarget> topicTargets;

  const _EditQuestionDialog({
    required this.courseId,
    required this.question,
    required this.topicTargets,
  });

  @override
  ConsumerState<_EditQuestionDialog> createState() => _EditQuestionDialogState();
}

class _EditQuestionDialogState extends ConsumerState<_EditQuestionDialog> {
  late final TextEditingController _questionController;
  late final TextEditingController _explanationController;
  late final TextEditingController _answerController;
  late final TextEditingController _tagsController;
  late QuestionDifficulty _difficulty;
  late int? _topicId;
  late List<_EditableOption> _options;
  late bool? _boolAnswer;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _questionController = TextEditingController(text: q.text);
    _explanationController = TextEditingController(text: q.explanation ?? '');
    _answerController = TextEditingController(text: _initialAnswerText(q));
    _tagsController = TextEditingController(text: q.tags.join(', '));
    _difficulty = q.difficulty;
    _topicId = q.topicId ?? (widget.topicTargets.isNotEmpty ? widget.topicTargets.first.topic.id : null);
    _boolAnswer = q.correctBool;
    _options = _initialOptions(q);
  }

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    _answerController.dispose();
    _tagsController.dispose();
    for (final option in _options) {
      option.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final qid = widget.question.remoteId ?? int.tryParse(widget.question.id);
    if (qid == null || qid <= 0) {
      setState(() => _error = 'This question does not have a backend id.');
      return;
    }

    final validation = _validate();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final payload = _buildPayload();
      await ref.read(questionsApiProvider).updateQuestion(
            courseId: widget.courseId,
            questionId: qid,
            payload: payload,
          );
      final hydrated = await ref.read(questionsApiProvider).getQuestion(
            courseId: widget.courseId,
            questionId: qid,
          );
      if (!mounted) return;
      Navigator.of(context).pop(hydrated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = mapApiFailure(e).message;
      });
    }
  }

  String? _validate() {
    if (_questionController.text.trim().isEmpty) return 'Question text is required.';
    if (_topicId == null || _topicId! <= 0) return 'A topic is required.';
    final type = widget.question.type;
    if (!_backendEditableType(type)) {
      return '${type.label} is not editable with the current backend question contract.';
    }
    if (type == QuestionType.multipleChoice || type == QuestionType.multiSelect) {
      final cleanOptions = _options.where((option) => option.controller.text.trim().isNotEmpty).toList();
      if (cleanOptions.length < 2) return 'At least two non-empty options are required.';
      if (!cleanOptions.any((option) => option.correct)) return 'Select at least one correct option.';
      if (type == QuestionType.multipleChoice && cleanOptions.where((option) => option.correct).length != 1) {
        return 'Multiple choice needs exactly one correct option.';
      }
    }
    if (type == QuestionType.trueFalse && _boolAnswer == null) return 'Select True or False.';
    if (type == QuestionType.shortAnswer && _answerController.text.trim().isEmpty) {
      return 'Expected answer is required for short answer questions.';
    }
    return null;
  }

  UpdateQuestionPayload _buildPayload() {
    final type = widget.question.type;
    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();

    if (type == QuestionType.multipleChoice || type == QuestionType.multiSelect) {
      final cleanOptions = _options.where((option) => option.controller.text.trim().isNotEmpty).toList();
      final optionIds = List.generate(cleanOptions.length, (index) => String.fromCharCode(65 + index));
      final createOptions = List.generate(cleanOptions.length, (index) {
        return CreateQuestionOption(id: optionIds[index], text: cleanOptions[index].controller.text.trim());
      });
      final correctIds = <String>[];
      for (var i = 0; i < cleanOptions.length; i++) {
        if (cleanOptions[i].correct) correctIds.add(optionIds[i]);
      }
      return UpdateQuestionPayload(
        topicId: _topicId,
        questionText: _questionController.text.trim(),
        difficulty: _difficulty.backendValue,
        explanation: _explanationController.text.trim(),
        options: createOptions,
        expectedAnswer: type == QuestionType.multiSelect ? correctIds : correctIds.first,
        tags: tags,
      );
    }

    if (type == QuestionType.trueFalse) {
      return UpdateQuestionPayload(
        topicId: _topicId,
        questionText: _questionController.text.trim(),
        difficulty: _difficulty.backendValue,
        explanation: _explanationController.text.trim(),
        expectedAnswer: (_boolAnswer ?? false).toString(),
        tags: tags,
      );
    }

    return UpdateQuestionPayload(
      topicId: _topicId,
      questionText: _questionController.text.trim(),
      difficulty: _difficulty.backendValue,
      explanation: _explanationController.text.trim(),
      expectedAnswer: _answerController.text.trim(),
      tags: tags,
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final editable = _backendEditableType(q.type);
    final size = MediaQuery.of(context).size;
    final compact = size.width < 900;
    final width = compact ? size.width * 0.94 : 860.0;
    final height = size.height < 760 ? size.height * 0.94 : size.height * 0.86;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 32,
        vertical: compact ? 18 : 36,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width,
            maxHeight: height.clamp(640.0, 820.0).toDouble(),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Question',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textTitle,
                                height: 1.22,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              editable
                                  ? 'Update this saved assessment item using the same authoring workspace.'
                                  : '${q.typeLabel} cannot be updated by the current backend question contract.',
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
                        onTap: _saving ? null : () => Navigator.of(context).pop(),
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
                        children: [
                          _LockedQuestionTypeTabs(type: q.type),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_error != null) ...[
                                    _EditErrorBanner(message: _error!),
                                    const SizedBox(height: 16),
                                  ],
                                  _buildMetaSection(q, editable),
                                  const SizedBox(height: 18),
                                  _buildQuestionTextSection(q, editable),
                                  const SizedBox(height: 18),
                                  _buildAnswerSection(q, editable),
                                  const SizedBox(height: 18),
                                  _buildExplanationSection(editable),
                                  const SizedBox(height: 18),
                                  _buildTagsSection(editable),
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
                    children: [
                      const _TinyMeta(icon: Icons.lock_outline_rounded, label: 'Type locked'),
                      const Spacer(),
                      TextButton(
                        onPressed: _saving ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _saving || !editable ? null : _save,
                        style: _editPrimaryButtonStyle(),
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(_saving ? 'Saving...' : 'Save Changes'),
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

  Widget _buildMetaSection(QuestionModel q, bool editable) {
    Widget topicField() => _TopicSelectorField(
          value: _topicId,
          targets: widget.topicTargets,
          fallbackTopicName: q.topicName,
          enabled: !_saving && editable,
          onChanged: (value) => setState(() => _topicId = value),
        );

    Widget difficultyField() => AppModernDropdown<QuestionDifficulty>(
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
          onChanged: (value) {
            if (_saving || !editable || value == null) return;
            setState(() => _difficulty = value);
          },
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: [
              topicField(),
              const SizedBox(height: 16),
              difficultyField(),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 2, child: topicField()),
            const SizedBox(width: 16),
            Expanded(child: difficultyField()),
          ],
        );
      },
    );
  }


  Widget _buildQuestionTextSection(QuestionModel q, bool editable) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _EditSectionLabel('Question Text')),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                q.typeLabel,
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
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
            children: [
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBg,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    const _EditToolbarButton(label: 'B'),
                    const SizedBox(width: 4),
                    const _EditToolbarButton(label: 'I', italic: true),
                    const SizedBox(width: 4),
                    const _EditToolbarButton(label: 'U', underlined: true),
                    const SizedBox(width: 8),
                    Icon(Icons.format_list_bulleted_rounded, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 10),
                    Icon(Icons.image_outlined, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 10),
                    Icon(Icons.code_rounded, size: 16, color: AppColors.textMuted),
                    const Spacer(),
                    if (_topicId != null)
                      Flexible(
                        child: Text(
                          _topicPickerLabel(widget.topicTargets, _topicId) ?? q.topicName ?? 'Selected topic',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              TextField(
                controller: _questionController,
                enabled: !_saving && editable,
                minLines: 5,
                maxLines: 5,
                decoration: _editInputDecoration(
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

  Widget _buildAnswerSection(QuestionModel q, bool editable) {
    if (q.type == QuestionType.multipleChoice || q.type == QuestionType.multiSelect) {
      return _buildMultipleChoiceSection(q.type, editable);
    }
    if (q.type == QuestionType.trueFalse) {
      return _buildTrueFalseSection(editable);
    }
    return _buildWrittenAnswerSection(q.type, editable);
  }

  Widget _buildMultipleChoiceSection(QuestionType type, bool editable) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _EditSectionLabel('Answer Options'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                type == QuestionType.multiSelect ? 'Select all correct answers' : 'Select the correct answer',
                style: TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w500),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: !_saving && editable && _options.length < 8
                  ? () {
                      setState(() {
                        _options.add(_EditableOption(controller: TextEditingController(), correct: false));
                      });
                    }
                  : null,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
              label: const Text('Add another option'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List<Widget>.generate(_options.length, (index) {
          final option = _options[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 26),
                  child: type == QuestionType.multiSelect
                      ? Checkbox(
                          value: option.correct,
                          onChanged: !_saving && editable
                              ? (value) {
                                  setState(() => option.correct = value ?? false);
                                }
                              : null,
                        )
                      : InkWell(
                          onTap: !_saving && editable
                              ? () {
                                  setState(() {
                                    for (var i = 0; i < _options.length; i++) {
                                      _options[i].correct = i == index;
                                    }
                                  });
                                }
                              : null,
                          borderRadius: BorderRadius.circular(100),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: option.correct ? AppColors.primary : AppColors.borderSoft,
                                width: option.correct ? 5 : 1.5,
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
                    children: [
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
                        controller: option.controller,
                        enabled: !_saving && editable,
                        decoration: _editInputDecoration(index == 0 ? 'Powerhouse of the cell' : 'Enter answer option'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: IconButton(
                    onPressed: !_saving && editable && _options.length > 2
                        ? () {
                            final removed = _options.removeAt(index);
                            removed.controller.dispose();
                            setState(() {});
                          }
                        : null,
                    icon: const Icon(Icons.delete_outline_rounded, size: 19),
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTrueFalseSection(bool editable) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EditSectionLabel('Correct Answer'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _EditBooleanAnswerCard(
                label: 'True',
                selected: _boolAnswer ?? false,
                enabled: !_saving && editable,
                onTap: () => setState(() => _boolAnswer = true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _EditBooleanAnswerCard(
                label: 'False',
                selected: _boolAnswer == false,
                enabled: !_saving && editable,
                onTap: () => setState(() => _boolAnswer = false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWrittenAnswerSection(QuestionType type, bool editable) {
    final hint = type == QuestionType.essay
        ? 'Enter the expected problem-solving answer or rubric.'
        : 'Enter the expected short answer.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EditSectionLabel('Expected Answer'),
        const SizedBox(height: 10),
        TextField(
          controller: _answerController,
          enabled: !_saving && editable,
          maxLines: 4,
          decoration: _editInputDecoration(hint),
        ),
      ],
    );
  }

  Widget _buildExplanationSection(bool editable) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EditSectionLabel('Explanation (Optional)'),
        const SizedBox(height: 10),
        TextField(
          controller: _explanationController,
          enabled: !_saving && editable,
          maxLines: 3,
          decoration: _editInputDecoration('Explain why the correct answer is correct...'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'This will be shown to students after they submit their answer.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTagsSection(bool editable) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EditSectionLabel('Tags (Optional)'),
        const SizedBox(height: 10),
        TextField(
          controller: _tagsController,
          enabled: !_saving && editable,
          decoration: _editInputDecoration('Tags, comma separated'),
        ),
      ],
    );
  }

  ButtonStyle _editPrimaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    );
  }

  InputDecoration _editInputDecoration(String hint) {
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

class _LockedQuestionTypeTabs extends StatelessWidget {
  final QuestionType type;

  const _LockedQuestionTypeTabs({required this.type});

  static const _types = <QuestionType>[
    QuestionType.multipleChoice,
    QuestionType.multiSelect,
    QuestionType.trueFalse,
    QuestionType.shortAnswer,
    QuestionType.essay,
  ];

  @override
  Widget build(BuildContext context) {
    final displayedTypes = _types.contains(type) ? _types : <QuestionType>[..._types, type];
    return Container(
      height: 62,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderGray)),
      ),
      child: Row(
        children: displayedTypes.map((item) {
          final selected = item == type;
          return Expanded(
            child: Container(
              height: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected ? AppColors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EditErrorBanner extends StatelessWidget {
  final String message;

  const _EditErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dangerBorder),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: AppColors.dangerText,
          fontSize: 12.5,
          height: 1.45,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EditSectionLabel extends StatelessWidget {
  final String text;

  const _EditSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
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

class _EditToolbarButton extends StatelessWidget {
  final String label;
  final bool italic;
  final bool underlined;

  const _EditToolbarButton({
    required this.label,
    this.italic = false,
    this.underlined = false,
  });

  @override
  Widget build(BuildContext context) {
    var style = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: AppColors.textMuted,
    );
    if (italic) style = style.copyWith(fontStyle: FontStyle.italic);
    if (underlined) style = style.copyWith(decoration: TextDecoration.underline);
    return Text(label, style: style);
  }
}

class _EditBooleanAnswerCard extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _EditBooleanAnswerCard({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: selected ? AppColors.infoBg : AppColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          children: [
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

class _TopicSelectorField extends StatelessWidget {
  final int? value;
  final List<_TopicTarget> targets;
  final String? fallbackTopicName;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  const _TopicSelectorField({
    required this.value,
    required this.targets,
    required this.fallbackTopicName,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final label = _topicPickerLabel(targets, value) ?? fallbackTopicName ?? 'No topic selected';
    Future<void> openPicker() async {
      if (!enabled || targets.isEmpty) return;
      final selected = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.30),
        builder: (_) => _TopicPickerDialog(
          selectedTopicId: value,
          targets: targets,
        ),
      );
      if (selected != null) onChanged(selected);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Topic',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.textGray,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: targets.isEmpty ? null : openPicker,
          child: Container(
            height: 44,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: targets.isEmpty ? AppColors.surfaceBg : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: targets.isEmpty ? AppColors.border : AppColors.primary.withOpacity(0.45)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_tree_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: targets.isEmpty ? AppColors.textMuted : AppColors.textGray,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.unfold_more_rounded, color: AppColors.textMuted, size: 19),
              ],
            ),
          ),
        ),
      ],
    );
  }

}

class _TopicPickerDialog extends StatefulWidget {
  final int? selectedTopicId;
  final List<_TopicTarget> targets;

  const _TopicPickerDialog({required this.selectedTopicId, required this.targets});

  @override
  State<_TopicPickerDialog> createState() => _TopicPickerDialogState();
}

class _TopicPickerDialogState extends State<_TopicPickerDialog> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = widget.targets.where((target) {
      if (query.isEmpty) return true;
      return <String>[
        target.topic.title,
        target.parentTopicTitle ?? '',
        target.material.displayTitle,
        target.module.title,
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
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 14, 16),
                child: Row(
                  children: [
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
                        children: [
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
                    controller: _search,
                    onChanged: (value) => setState(() => _query = value),
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

  List<Widget> _buildGroupedTargetRows(BuildContext context, List<_TopicTarget> targets) {
    final rows = <Widget>[];
    String? currentModule;
    String? currentMaterial;

    for (final target in targets) {
      if (target.module.title != currentModule) {
        currentModule = target.module.title;
        rows.add(_groupHeader(Icons.school_outlined, currentModule));
        currentMaterial = null;
      }
      if (target.material.displayTitle != currentMaterial) {
        currentMaterial = target.material.displayTitle;
        rows.add(_groupHeader(Icons.description_outlined, currentMaterial, indent: 14));
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(left: 28, top: 6),
          child: _treeOption(
            context,
            selected: widget.selectedTopicId == target.topic.id,
            icon: target.parentTopicTitle == null ? Icons.topic_outlined : Icons.subdirectory_arrow_right_rounded,
            title: target.parentTopicTitle == null ? target.topic.title : '${target.parentTopicTitle} / ${target.topic.title}',
            subtitle: '${target.module.title} • ${target.material.displayTitle} • ${target.parentTopicTitle == null ? 'Topic' : 'Subtopic'}',
            onTap: () => Navigator.of(context).pop(target.topic.id),
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
        children: [
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
          children: [
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
                children: [
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

class _TopicPickerRow extends StatelessWidget {
  final _TopicTarget target;
  final bool selected;
  final VoidCallback onTap;

  const _TopicPickerRow({required this.target, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.headerBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                selected ? Icons.check_rounded : Icons.topic_outlined,
                color: selected ? Colors.white : AppColors.textMuted,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(target.topic.title, style: TextStyle(color: AppColors.textTitle, fontSize: 13.2, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    '${target.module.title} → ${target.material.displayTitle}${target.parentTopicTitle == null ? '' : ' → ${target.parentTopicTitle}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w700),
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

class _EditOptionsPanel extends StatelessWidget {
  final QuestionType type;
  final List<_EditableOption> options;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _EditOptionsPanel({
    required this.type,
    required this.options,
    required this.enabled,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Answer options', style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w900)),
              ),
              TextButton.icon(
                onPressed: enabled && options.length < 8 ? onAdd : null,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add option'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(options.length, (index) {
            final option = options[index];
            final label = String.fromCharCode(65 + index);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  if (type == QuestionType.multiSelect)
                    Checkbox(
                      value: option.correct,
                      onChanged: enabled
                          ? (value) {
                              option.correct = value ?? false;
                              onChanged();
                            }
                          : null,
                    )
                  else
                    Radio<int>(
                      value: index,
                      groupValue: options.indexWhere((item) => item.correct),
                      onChanged: enabled
                          ? (value) {
                              if (value == null) return;
                              for (var i = 0; i < options.length; i++) {
                                options[i].correct = i == value;
                              }
                              onChanged();
                            }
                          : null,
                    ),
                  SizedBox(
                    width: 28,
                    child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: option.controller,
                      enabled: enabled,
                      onChanged: (_) => onChanged(),
                      decoration: _editDecoration('Option ${index + 1}'),
                    ),
                  ),
                  IconButton(
                    onPressed: enabled && options.length > 2 ? () => onRemove(index) : null,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            );
          }),
          Text(
            type == QuestionType.multiSelect
                ? 'Select every correct option.'
                : 'Select exactly one correct option.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TrueFalseEditor extends StatelessWidget {
  final bool? value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _TrueFalseEditor({required this.value, required this.enabled, required this.onChanged});

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
          Expanded(
            child: Text('Correct answer', style: TextStyle(color: AppColors.textTitle, fontWeight: FontWeight.w900)),
          ),
          ChoiceChip(
            selected: value ?? false,
            label: const Text('True'),
            onSelected: enabled ? (_) => onChanged(true) : null,
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            selected: value == false,
            label: const Text('False'),
            onSelected: enabled ? (_) => onChanged(false) : null,
          ),
        ],
      ),
    );
  }
}

class _EditableOption {
  final TextEditingController controller;
  bool correct;

  _EditableOption({required this.controller, required this.correct});
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
}

class _TypeBadge extends StatelessWidget {
  final String label;

  const _TypeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return _Badge(
      label: label,
      background: AppColors.badgeBlueBg,
      foreground: AppColors.badgeBlueFg,
      border: AppColors.badgeBlueBorder,
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final QuestionDifficulty diff;

  const _DifficultyBadge({required this.diff});

  @override
  Widget build(BuildContext context) {
    switch (diff) {
      case QuestionDifficulty.easy:
        return _Badge(
          label: 'Easy',
          background: AppColors.successBg,
          foreground: AppColors.successText,
          border: AppColors.greenBorder,
        );
      case QuestionDifficulty.medium:
        return _Badge(
          label: 'Medium',
          background: AppColors.warningSoftBg,
          foreground: AppColors.warningText,
          border: AppColors.warningBorder,
        );
      case QuestionDifficulty.hard:
        return _Badge(
          label: 'Hard',
          background: AppColors.dangerBg,
          foreground: AppColors.dangerText,
          border: AppColors.dangerBorder,
        );
    }
  }
}

class _SourceBadge extends StatelessWidget {
  final QuestionSource source;

  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    switch (source) {
      case QuestionSource.aiGenerated:
        return _Badge(
          label: 'AI generated',
          background: AppColors.purpleBg,
          foreground: AppColors.purpleText,
          border: AppColors.purpleBorder,
        );
      case QuestionSource.imported:
        return _Badge(
          label: 'Imported',
          background: AppColors.badgeIndigoBg,
          foreground: AppColors.badgeIndigoFg,
          border: AppColors.badgeIndigoBorder,
        );
      case QuestionSource.manual:
        return _Badge(
          label: 'Manual',
          background: AppColors.surfaceBg,
          foreground: AppColors.textMuted,
          border: AppColors.border,
        );
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final Color border;

  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: foreground, fontSize: 10.8, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _TinyMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TinyMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textHint),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.2, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _QuestionBankSkeleton extends StatelessWidget {
  const _QuestionBankSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: List.generate(
          7,
          (index) => Container(
            margin: EdgeInsets.only(bottom: index == 6 ? 0 : 10),
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.surfaceBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionBankEmpty extends StatelessWidget {
  final bool hasQuestions;

  const _QuestionBankEmpty({required this.hasQuestions});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.quiz_outlined, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              hasQuestions ? 'No questions match the current filters' : 'No saved questions yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTitle, fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                hasQuestions
                    ? 'Adjust the search term, module, difficulty, or type to reveal more questions.'
                    : 'Questions will appear here after they are saved from the material generation workspace or manual authoring flow.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionBankError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _QuestionBankError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 42, color: AppColors.dangerText),
            const SizedBox(height: 14),
            Text(
              'Could not load question bank',
              style: TextStyle(color: AppColors.textTitle, fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _editDecoration(String label) => InputDecoration(
      labelText: label,
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.3),
      ),
    );


class _FilterOption {
  final int id;
  final String label;

  const _FilterOption({required this.id, required this.label});
}

_TopicTarget? _targetForQuestion(List<_TopicTarget> targets, QuestionModel question) {
  final topicId = question.topicId;
  if (topicId == null) return null;
  for (final target in targets) {
    if (target.topic.id == topicId) return target;
  }
  return null;
}

bool _materialBelongsToModule(List<_TopicTarget> targets, int materialId, int moduleId) {
  for (final target in targets) {
    if (target.material.id == materialId && target.module.id == moduleId) return true;
  }
  return false;
}

bool _topicBelongsToMaterial(List<_TopicTarget> targets, int topicId, int materialId) {
  for (final target in targets) {
    if (target.topic.id == topicId && target.material.id == materialId) return true;
  }
  return false;
}

List<_FilterOption> _materialFilterOptions(List<_TopicTarget> targets, int? moduleId) {
  final seen = <int>{};
  final result = <_FilterOption>[];
  for (final target in targets) {
    if (moduleId != null && target.module.id != moduleId) continue;
    if (!seen.add(target.material.id)) continue;
    final label = '${target.module.title} / ${target.material.displayTitle}';
    result.add(_FilterOption(id: target.material.id, label: label));
  }
  result.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return result;
}

List<_FilterOption> _topicFilterOptions(
  List<_TopicTarget> targets, {
  int? moduleId,
  int? materialId,
}) {
  final seen = <int>{};
  final result = <_FilterOption>[];
  for (final target in targets) {
    if (moduleId != null && target.module.id != moduleId) continue;
    if (materialId != null && target.material.id != materialId) continue;
    if (!seen.add(target.topic.id)) continue;
    final topicLabel = target.parentTopicTitle == null
        ? target.topic.title
        : '${target.parentTopicTitle} / ${target.topic.title}';
    result.add(_FilterOption(
      id: target.topic.id,
      label: '${target.material.displayTitle} / $topicLabel',
    ),);
  }
  result.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return result;
}

List<_FilterOption> _learningOutcomeFilterOptions(List<QuestionModel> questions) {
  final seen = <int>{};
  final result = <_FilterOption>[];
  for (final question in questions) {
    for (final outcome in question.learningOutcomes) {
      if (!seen.add(outcome.id)) continue;
      result.add(_FilterOption(id: outcome.id, label: outcome.title));
    }
  }
  result.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return result;
}

List<_FilterOption> _learningOutcomeSetupOptions(
  List<QuestionModel> questions,
  List<LearningOutcome> courseOutcomes,
) {
  final byId = <int, String>{};
  for (final outcome in courseOutcomes) {
    final title = outcome.title.trim();
    byId[outcome.id] = title.isEmpty ? 'LO ${outcome.id}' : title;
  }
  for (final question in questions) {
    for (final outcome in question.learningOutcomes) {
      final title = outcome.title.trim();
      byId.putIfAbsent(outcome.id, () => title.isEmpty ? 'LO ${outcome.id}' : title);
    }
  }
  final result = byId.entries
      .map((entry) => _FilterOption(id: entry.key, label: entry.value))
      .toList()
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return result;
}

String _selectedMaterialFilterLabel(List<_FilterOption> options, int? id) {
  if (id == null) return 'All materials';
  for (final option in options) {
    if (option.id == id) return option.label;
  }
  return 'All materials';
}

String _selectedTopicFilterLabel(List<_FilterOption> options, int? id) {
  if (id == null) return 'All topics / subtopics';
  for (final option in options) {
    if (option.id == id) return option.label;
  }
  return 'All topics / subtopics';
}

String _selectedOutcomeFilterLabel(List<_FilterOption> options, int? id) {
  if (id == null) return 'All LOs';
  for (final option in options) {
    if (option.id == id) return option.label;
  }
  return 'All LOs';
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

QuestionSource? _sourceFromLabel(String label) {
  switch (label) {
    case 'AI':
      return QuestionSource.aiGenerated;
    case 'Imported':
      return QuestionSource.imported;
    case 'Manual':
      return QuestionSource.manual;
    default:
      return null;
  }
}

bool? _usageFromLabel(String label) {
  switch (label) {
    case 'Used in exams':
      return true;
    case 'Unused':
      return false;
    default:
      return null;
  }
}

String _approvalLabel(QuestionApprovalStatus status) {
  switch (status) {
    case QuestionApprovalStatus.pending:
      return 'Pending review';
    case QuestionApprovalStatus.rejected:
      return 'Rejected';
    case QuestionApprovalStatus.approved:
      return 'Approved';
  }
}

String _usageLabel(int count) => count == 0 ? 'Unused' : 'Used in $count exam${count == 1 ? '' : 's'}';

String _shortDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return 'Unknown date';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _topicPathFromTarget(_TopicTarget? target, QuestionModel question) {
  if (target == null) return question.topicName ?? 'Not assigned';
  if (target.parentTopicTitle == null) return target.topic.title;
  return '${target.parentTopicTitle} / ${target.topic.title}';
}

String _contextLabel(QuestionModel question) {
  if ((question.topicName ?? '').trim().isNotEmpty) return question.topicName!.trim();
  if ((question.materialName ?? '').trim().isNotEmpty) return question.materialName!.trim();
  if ((question.moduleName ?? '').trim().isNotEmpty) return question.moduleName!.trim();
  return 'Not assigned';
}

String _answerText(QuestionModel question) {
  if (question.correctBool != null) return question.correctBool! ? 'True' : 'False';
  if ((question.expectedAnswer ?? '').trim().isNotEmpty) return question.expectedAnswer!.trim();
  if ((question.sampleAnswer ?? '').trim().isNotEmpty) return question.sampleAnswer!.trim();
  if ((question.correctOptionId ?? '').trim().isNotEmpty) return question.correctOptionId!.trim();
  return '';
}

String _moduleLabel(ModuleItem module) => module.title.trim().isEmpty ? 'Module ${module.id}' : module.title.trim();

String _selectedModuleLabel(List<ModuleItem> modules, int? id) {
  if (id == null) return 'All modules';
  for (final module in modules) {
    if (module.id == id) return _moduleLabel(module);
  }
  return 'All modules';
}

QuestionDifficulty? _difficultyFromLabel(String label) {
  switch (label) {
    case 'Easy':
      return QuestionDifficulty.easy;
    case 'Medium':
      return QuestionDifficulty.medium;
    case 'Hard':
      return QuestionDifficulty.hard;
    default:
      return null;
  }
}

QuestionType? _typeFromLabel(String label) {
  switch (label) {
    case 'Multiple Choice':
      return QuestionType.multipleChoice;
    case 'True / False':
      return QuestionType.trueFalse;
    case 'Short Answer':
      return QuestionType.shortAnswer;
    case 'Essay':
      return QuestionType.essay;
    case 'Multi-Select':
      return QuestionType.multiSelect;
    case 'Fill in the Blank':
      return QuestionType.fillInTheBlank;
    case 'Numeric':
      return QuestionType.numeric;
    case 'Code':
      return QuestionType.code;
    default:
      return null;
  }
}

bool _backendEditableType(QuestionType type) {
  return type == QuestionType.multipleChoice ||
      type == QuestionType.multiSelect ||
      type == QuestionType.trueFalse ||
      type == QuestionType.shortAnswer ||
      type == QuestionType.essay;
}

String _initialAnswerText(QuestionModel q) {
  if (q.type == QuestionType.shortAnswer || q.type == QuestionType.essay) {
    return q.sampleAnswer ?? q.expectedAnswer ?? '';
  }
  return q.expectedAnswer ?? '';
}

List<_EditableOption> _initialOptions(QuestionModel q) {
  if (q.options.isEmpty) {
    return [
      _EditableOption(controller: TextEditingController(), correct: true),
      _EditableOption(controller: TextEditingController(), correct: false),
    ];
  }
  return q.options.map((option) {
    final correct = option.isCorrect || option.id == q.correctOptionId;
    return _EditableOption(
      controller: TextEditingController(text: option.text),
      correct: correct,
    );
  }).toList();
}

String? _topicPickerLabel(List<_TopicTarget> targets, int? topicId) {
  if (topicId == null) return null;
  for (final target in targets) {
    if (target.topic.id == topicId) return target.topic.title;
  }
  return null;
}

String? _moduleNameFromTargets(List<_TopicTarget> targets, int? topicId) {
  if (topicId == null) return null;
  for (final target in targets) {
    if (target.topic.id == topicId) return target.module.title;
  }
  return null;
}

String? _materialNameFromTargets(List<_TopicTarget> targets, int? topicId) {
  if (topicId == null) return null;
  for (final target in targets) {
    if (target.topic.id == topicId) return target.material.displayTitle;
  }
  return null;
}

String? _topicNameFromTargets(List<_TopicTarget> targets, int? topicId) {
  if (topicId == null) return null;
  for (final target in targets) {
    if (target.topic.id == topicId) return target.topic.title;
  }
  return null;
}
