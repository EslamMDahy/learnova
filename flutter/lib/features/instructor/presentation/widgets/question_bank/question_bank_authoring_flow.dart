import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/ui/toast.dart';
import '../../../../../shared/widgets/components/dropdowns.dart';
import '../../../../../shared/widgets/components/inputs.dart';
import '../../../data/courses_models.dart';
import '../../../data/materials_models.dart';
import '../../../data/modules_materials_providers.dart';
import '../../../data/questions_api.dart';
import '../../../data/modules_models.dart';
import '../../../data/question_models.dart';
import '../../../data/question_vocabulary.dart';
import '../../../data/topics_models.dart';
import '../../controllers/course_details_controller.dart';
import '../add_question_sheet.dart' as add_question_sheet;

enum _WorkspaceMode { manual, ai, review }

enum QuestionAuthoringScopeKind { module, material, topic, subtopic, selection }

class QuestionAuthoringLaunchContext {
  final QuestionAuthoringScopeKind kind;
  final String title;
  final String subtitle;
  final int? selectedModuleId;
  final int? selectedMaterialId;
  final int? selectedTopicId;
  final Set<int> selectedModuleIds;
  final Set<int> selectedMaterialIds;
  final Set<int> selectedTopicIds;

  const QuestionAuthoringLaunchContext({
    required this.kind,
    required this.title,
    required this.subtitle,
    this.selectedModuleId,
    this.selectedMaterialId,
    this.selectedTopicId,
    this.selectedModuleIds = const <int>{},
    this.selectedMaterialIds = const <int>{},
    this.selectedTopicIds = const <int>{},
  });

  String get label {
    switch (kind) {
      case QuestionAuthoringScopeKind.module:
        return 'Module scope';
      case QuestionAuthoringScopeKind.material:
        return 'Material scope';
      case QuestionAuthoringScopeKind.topic:
        return 'Topic scope';
      case QuestionAuthoringScopeKind.subtopic:
        return 'Subtopic scope';
      case QuestionAuthoringScopeKind.selection:
        return 'Custom selection';
    }
  }
}


class QuestionBankAuthoringFlow extends ConsumerStatefulWidget {
  final MyCourseItem course;
  final Set<int> initialModuleIds;
  final Set<int> initialMaterialIds;
  final Set<int> initialTopicIds;
  final bool embedded;
  final QuestionAuthoringLaunchContext? launchContext;
  final VoidCallback? onClose;

  const QuestionBankAuthoringFlow({
    super.key,
    required this.course,
    this.initialModuleIds = const <int>{},
    this.initialMaterialIds = const <int>{},
    this.initialTopicIds = const <int>{},
    this.embedded = false,
    this.launchContext,
    this.onClose,
  });

  @override
  ConsumerState<QuestionBankAuthoringFlow> createState() =>
      _QuestionBankAuthoringFlowState();
}

class _QuestionBankAuthoringFlowState
    extends ConsumerState<QuestionBankAuthoringFlow> {
  bool _loading = true;
  bool _savingDrafts = false;
  _WorkspaceMode _mode = _WorkspaceMode.manual;

  List<add_question_sheet.QuestionAuthoringTarget> _targets =
      const <add_question_sheet.QuestionAuthoringTarget>[];
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selectedQuestionIds = <String>{};
  final List<QuestionModel> _draftQuestions = <QuestionModel>[];

  // ── AI polling state ──────────────────────────────────────────────────────
  Timer? _aiPollTimer;
  bool _aiPolling = false;
  int _aiPollAttempts = 0;
  static const int _kMaxPollAttempts = 24;   // 24 × 5 s = 2 min max
  static const Duration _kPollInterval = Duration(seconds: 5);
  // Known question IDs before generation started (to detect new arrivals)
  Set<int> _knownRemoteIds = <int>{};

  int? _selectedTopicFilterId;
  String _selectedDifficultyFilter = 'Any Difficulty';
  String _selectedTypeFilter = 'All Types';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _aiPollTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await ref
        .read(courseDetailsControllerProvider(widget.course.id).notifier)
        .loadModulesAndAllMaterials();
    if (!mounted) return;

    final dynamic st = ref.read(courseDetailsControllerProvider(widget.course.id));
    setState(() {
      _targets = _resolveTargets(st);
      _loading = false;
    });
  }

  List<add_question_sheet.QuestionAuthoringTarget> _resolveTargets(dynamic st) {
    final List<ModuleItem> modules = st.modules as List<ModuleItem>;
    final Map<int, List<MaterialItem>> materialsMap =
        Map<int, List<MaterialItem>>.from(st.materials as Map<dynamic, dynamic>);
    final Map<int, List<TopicItem>> topicsMap =
        Map<int, List<TopicItem>>.from(st.topics as Map<dynamic, dynamic>);

    final List<add_question_sheet.QuestionAuthoringTarget> resolved =
        <add_question_sheet.QuestionAuthoringTarget>[];
    final Set<int> seen = <int>{};

    ModuleItem? findModule(int id) {
      for (final ModuleItem module in modules) {
        if (module.id == id) return module;
      }
      return null;
    }

    MaterialItem? findMaterial(int id) {
      for (final List<MaterialItem> mats in materialsMap.values) {
        for (final MaterialItem material in mats) {
          if (material.id == id) return material;
        }
      }
      return null;
    }

    TopicItem? findTopic(int id) {
      for (final List<TopicItem> topics in topicsMap.values) {
        for (final TopicItem topic in topics) {
          if (topic.id == id) return topic;
        }
      }
      return null;
    }

    void addLeafTargets(
      ModuleItem module,
      MaterialItem material,
      TopicItem topic,
      List<TopicItem> materialTopics,
    ) {
      final List<TopicItem> children = materialTopics
          .where((TopicItem item) => item.parentTopicId == topic.id)
          .toList()
        ..sort((TopicItem a, TopicItem b) =>
            a.orderIndex.compareTo(b.orderIndex),);

      if (children.isEmpty || topic.parentTopicId != null) {
        if (seen.add(topic.id)) {
          TopicItem? parent;
          if (topic.parentTopicId != null) {
            for (final TopicItem item in materialTopics) {
              if (item.id == topic.parentTopicId) {
                parent = item;
                break;
              }
            }
          }

          resolved.add(
            add_question_sheet.QuestionAuthoringTarget(
              moduleId: module.id,
              moduleName: module.title,
              materialId: material.id,
              materialName: material.displayTitle,
              topicId: topic.id,
              topicName: topic.title,
              isSubtopic: topic.parentTopicId != null,
              parentTopicName: parent?.title,
            ),
          );
        }
        return;
      }

      for (final TopicItem child in children) {
        addLeafTargets(module, material, child, materialTopics);
      }
    }

    for (final int topicId in widget.initialTopicIds) {
      final TopicItem? topic = findTopic(topicId);
      if (topic == null) continue;
      final MaterialItem? material = findMaterial(topic.materialId);
      if (material == null) continue;
      final ModuleItem? module = findModule(material.moduleId);
      if (module == null) continue;
      final List<TopicItem> materialTopics =
          (topicsMap[module.id] ?? const <TopicItem>[])
              .where((TopicItem item) => item.materialId == material.id)
              .toList();
      addLeafTargets(module, material, topic, materialTopics);
    }

    for (final int materialId in widget.initialMaterialIds) {
      final MaterialItem? material = findMaterial(materialId);
      if (material == null) continue;
      final ModuleItem? module = findModule(material.moduleId);
      if (module == null) continue;
      final List<TopicItem> materialTopics =
          (topicsMap[module.id] ?? const <TopicItem>[])
              .where((TopicItem item) => item.materialId == material.id)
              .toList();
      final List<TopicItem> roots = materialTopics
          .where((TopicItem item) => item.parentTopicId == null)
          .toList()
        ..sort((TopicItem a, TopicItem b) =>
            a.orderIndex.compareTo(b.orderIndex),);
      for (final TopicItem root in roots) {
        addLeafTargets(module, material, root, materialTopics);
      }
    }

    for (final int moduleId in widget.initialModuleIds) {
      final ModuleItem? module = findModule(moduleId);
      if (module == null) continue;
      final List<MaterialItem> materials =
          materialsMap[module.id] ?? const <MaterialItem>[];
      final List<TopicItem> moduleTopics =
          topicsMap[module.id] ?? const <TopicItem>[];
      for (final MaterialItem material in materials) {
        final List<TopicItem> materialTopics = moduleTopics
            .where((TopicItem item) => item.materialId == material.id)
            .toList();
        final List<TopicItem> roots = materialTopics
            .where((TopicItem item) => item.parentTopicId == null)
            .toList()
          ..sort((TopicItem a, TopicItem b) =>
              a.orderIndex.compareTo(b.orderIndex),);
        for (final TopicItem root in roots) {
          addLeafTargets(module, material, root, materialTopics);
        }
      }
    }

    return resolved;
  }

  void _closeFlow() {
    if (widget.onClose != null) {
      widget.onClose!.call();
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _openAddQuestion() async {
    if (_targets.isEmpty) {
      AppToast.error(
        context,
        title: 'No topics found',
        message: 'Add topics or subtopics first.',
      );
      return;
    }

    await add_question_sheet.showAddQuestionDialog(
      context,
      moduleId: _targets.first.moduleId,
      moduleName: _targets.first.moduleName,
      materialId: _targets.first.materialId,
      materialName: _targets.first.materialName,
      topicId: _targets.first.topicId,
      topicName: _targets.first.topicName,
      topicTargets: _targets,
      onAdd: (QuestionModel question) async {
        setState(() {
          _draftQuestions.insert(0, question);
        });
      },
    );
  }

  Future<void> _openEditDraftQuestion(QuestionModel question) async {
    final QuestionModel? updated = await showDialog<QuestionModel>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.34),
      builder: (_) => _DraftQuestionEditDialog(
        question: question,
        targets: _targets,
      ),
    );

    if (updated == null || !mounted) return;
    setState(() {
      final int idx = _draftQuestions.indexWhere((QuestionModel item) => item.id == question.id);
      if (idx != -1) _draftQuestions[idx] = updated;
    });
  }

  void _deleteDraftQuestion(QuestionModel question) {
    setState(() {
      _draftQuestions.removeWhere((QuestionModel item) => item.id == question.id);
      _selectedQuestionIds.remove(question.id);
    });
  }

  void _toggleSelection(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedQuestionIds.add(id);
      } else {
        _selectedQuestionIds.remove(id);
      }
    });
  }

  Future<void> _handleGeneratePressed() async {
    final List<add_question_sheet.QuestionAuthoringTarget> generationTargets =
        _targetsForCurrentTopicFilter();
    if (generationTargets.isEmpty) {
      AppToast.error(
        context,
        title: 'No generation target',
        message: 'Choose at least one topic or subtopic first.',
      );
      return;
    }

    final _AiGenerationRequest? request = await showDialog<_AiGenerationRequest>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.34),
      builder: (_) => _AiGenerationDialog(targets: generationTargets),
    );

    if (request == null || !mounted) return;

    // ── Send the real API request ──────────────────────────────────────────
    try {
      final api = ref.read(questionsApiProvider);
      final aiRequest = AiQuestionGenerationRequest(
        topics: request.topics.map((t) {
          final configs = (t['question_configs'] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .map((c) => AiQuestionGenerationConfig(
                    type: c['type'] as String,
                    difficulty: c['difficulty'] as String,
                    count: (c['count'] as num).toInt(),
                  ))
              .toList();
          return AiQuestionGenerationTopic(
            topicId: (t['topic_id'] as num).toInt(),
            questionConfigs: configs,
          );
        }).toList(),
      );

      // Snapshot which remote IDs already exist so we can detect new arrivals.
      _knownRemoteIds = _draftQuestions
          .map((q) => q.remoteId)
          .whereType<int>()
          .toSet();

      final resp = await api.generateQuestions(
        courseId: widget.course.id,
        payload: aiRequest,
      );

      if (!mounted) return;

      if (resp.aiProcessingStarted) {
        AppToast.info(
          context,
          title: 'AI is working…',
          message: 'Generating ${request.totalQuestions} question(s) for '
              '${request.topicCount} topic(s). This page will update automatically.',
          duration: const Duration(seconds: 5),
        );
        // Switch to AI Drafts tab so the user sees results as they arrive.
        setState(() => _mode = _WorkspaceMode.ai);
        _startAiPolling();
      } else {
        AppToast.warning(
          context,
          title: 'Request received',
          message: resp.message ??
              'Request submitted but AI processing has not started yet.',
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      AppToast.error(
        context,
        title: 'Generation failed',
        message: msg.contains('403')
            ? 'Only instructors can generate questions.'
            : msg.contains('404')
                ? 'One or more topics were not found. Please refresh and try again.'
                : msg.contains('422')
                    ? 'Invalid request. Check your configuration.'
                    : msg.contains('503')
                        ? 'AI service is temporarily unavailable. Please try again later.'
                        : 'Something went wrong. Please try again.',
        duration: const Duration(seconds: 6),
      );
    }
  }

  // ── AI Polling ────────────────────────────────────────────────────────────
  /// Starts polling GET /courses/{id}/questions every [_kPollInterval].
  /// Stops when new AI questions arrive or after [_kMaxPollAttempts].
  void _startAiPolling() {
    _aiPollTimer?.cancel();
    _aiPollAttempts = 0;
    _aiPolling = true;
    if (mounted) setState(() {});

    _aiPollTimer = Timer.periodic(_kPollInterval, (_) => _pollForAiQuestions());
  }

  void _stopAiPolling() {
    _aiPollTimer?.cancel();
    _aiPollTimer = null;
    _aiPolling = false;
    if (mounted) setState(() {});
  }

  Future<void> _pollForAiQuestions() async {
    if (!mounted) {
      _stopAiPolling();
      return;
    }

    _aiPollAttempts++;
    if (_aiPollAttempts > _kMaxPollAttempts) {
      _stopAiPolling();
      if (mounted) {
        AppToast.warning(
          context,
          title: 'Generation taking longer than expected',
          message: "Pull down to refresh when you're ready to review the questions.",
          duration: const Duration(seconds: 6),
        );
      }
      return;
    }

    try {
      final api = ref.read(questionsApiProvider);
      final resp = await api.getCourseQuestions(courseId: widget.course.id);

      if (!mounted) {
        _stopAiPolling();
        return;
      }

      // Find newly arrived AI questions (pending approval, not seen before)
      final newAiQuestions = resp.questions
          .where((q) =>
              q.source == QuestionSource.aiGenerated &&
              q.approvalStatus == QuestionApprovalStatus.pending &&
              q.remoteId != null &&
              !_knownRemoteIds.contains(q.remoteId))
          .toList();

      if (newAiQuestions.isNotEmpty) {
        _stopAiPolling();
        // Update known IDs to include all current questions
        _knownRemoteIds = resp.questions
            .map((q) => q.remoteId)
            .whereType<int>()
            .toSet();

        setState(() {
          // Add new AI questions to drafts (avoid duplicates)
          final existingIds = _draftQuestions
              .map((q) => q.remoteId)
              .whereType<int>()
              .toSet();
          for (final q in newAiQuestions) {
            if (!existingIds.contains(q.remoteId)) {
              _draftQuestions.add(q);
            }
          }
          _mode = _WorkspaceMode.ai;
        });

        if (mounted) {
          AppToast.success(
            context,
            title: '${newAiQuestions.length} question${newAiQuestions.length == 1 ? '' : 's'} ready for review',
            message: 'Review the AI drafts and check the ones you want to save.',
            duration: const Duration(seconds: 6),
          );
        }
      }
    } catch (_) {
      // Silent — keep polling, transient errors are expected
    }
  }

  Future<void> _saveSelectedDraftQuestions() async {
    final List<QuestionModel> selectedDrafts = _selectedDraftQuestions();
    if (selectedDrafts.isEmpty || _savingDrafts) return;

    setState(() => _savingDrafts = true);

    final api = ref.read(questionsApiProvider);
    final controller = ref.read(
      courseDetailsControllerProvider(widget.course.id).notifier,
    );
    final List<QuestionModel> savedQuestions = <QuestionModel>[];

    try {
      for (final QuestionModel draft in selectedDrafts.reversed) {
        final payload = api.buildCreatePayloadFromQuestion(draft);
        if (payload == null) {
          throw StateError(
            'Question type or topic is not compatible with backend.',
          );
        }

        final QuestionModel saved = await api.createQuestion(
          courseId: widget.course.id,
          payload: payload,
        );

        final QuestionModel hydrated = QuestionModel(
          id: saved.id,
          remoteId: saved.remoteId,
          text: saved.text,
          type: saved.type,
          difficulty: saved.difficulty,
          source: saved.source,
          approvalStatus: saved.approvalStatus,
          options: saved.options,
          correctOptionId: saved.correctOptionId ?? draft.correctOptionId,
          correctBool: saved.correctBool ?? draft.correctBool,
          sampleAnswer: saved.sampleAnswer ?? draft.sampleAnswer,
          explanation: saved.explanation ?? draft.explanation,
          expectedAnswer: saved.expectedAnswer ?? draft.expectedAnswer,
          tags: saved.tags.isEmpty ? draft.tags : saved.tags,
          usageCount: saved.usageCount,
          successRate: saved.successRate,
          maxScore: saved.maxScore,
          autoGradable: saved.autoGradable,
          courseId: saved.courseId ?? widget.course.id,
          moduleId: draft.moduleId,
          moduleName: draft.moduleName,
          materialId: draft.materialId,
          materialName: draft.materialName,
          topicId: saved.topicId ?? draft.topicId,
          topicName: draft.topicName,
          createdAt: saved.createdAt,
        );

        savedQuestions.add(hydrated);
      }

      if (!mounted) return;
      for (final QuestionModel question in savedQuestions.reversed) {
        controller.addQuestion(question);
      }

      setState(() {
        final Set<String> savedIds = selectedDrafts.map((QuestionModel q) => q.id).toSet();
        _draftQuestions.removeWhere((QuestionModel q) => savedIds.contains(q.id));
        _selectedQuestionIds.removeAll(savedIds);
        _savingDrafts = false;
      });

      AppToast.success(
        context,
        title: 'Questions saved',
        message: '${savedQuestions.length} question(s) were added to the question bank.',
      );
      _closeFlow();
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingDrafts = false);
      AppToast.error(
        context,
        title: 'Could not save questions',
        message: 'Check selected questions and try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    if (_loading) {
      return _wrapBody(
        Scaffold(
          backgroundColor: AppColors.surfaceBg,
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final List<QuestionModel> visibleQuestions = _visibleQuestionsForMode();
    final List<QuestionModel> filteredQuestions = _filteredQuestions(visibleQuestions);

    final Widget body = Scaffold(
      backgroundColor: AppColors.surfaceBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < 900;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : 20,
                compact ? 12 : 16,
                compact ? 14 : 20,
                compact ? 14 : 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildHeader(compact: compact),
                  const SizedBox(height: 10),
                  _buildModeTabs(compact: compact),
                  const SizedBox(height: 10),
                  _buildFiltersBar(compact: compact),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _buildModeContent(
                      filteredQuestions: filteredQuestions,
                      totalVisible: visibleQuestions.length,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    return _wrapBody(body);
  }

  Widget _wrapBody(Widget child) {
    if (widget.embedded) return child;
    return Dialog.fullscreen(child: child);
  }

  Widget _buildHeader({required bool compact}) {
    final Widget titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _BackToMaterialsButton(
          onPressed: _closeFlow,
          compact: compact,
        ),
        const SizedBox(height: 12),
        Text(
          'Question Workspace',
          style: TextStyle(
            fontSize: compact ? 21 : 25,
            fontWeight: FontWeight.w900,
            color: AppColors.textTitle,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _headerSubtitle(),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _scopeChip(
              icon: Icons.school_outlined,
              label: widget.course.title,
            ),
            _scopeChip(
              icon: Icons.account_tree_outlined,
              label: _scopeLabel(),
            ),
            _scopeChip(
              icon: Icons.adjust_rounded,
              label: '${_targets.length} target${_targets.length == 1 ? '' : 's'}',
            ),
            _scopeChip(
              icon: Icons.folder_copy_outlined,
              label: _scopeBreakdown(),
            ),
          ],
        ),
      ],
    );

    final Widget actionButton = _buildPrimaryActionButton(compact: compact);

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          titleBlock,
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: actionButton),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: titleBlock),
        const SizedBox(width: 20),
        actionButton,
      ],
    );
  }

  Widget _buildPrimaryActionButton({required bool compact}) {
    late final String label;
    late final IconData icon;
    late final VoidCallback? onPressed;

    switch (_mode) {
      case _WorkspaceMode.manual:
        label = 'Add Question';
        icon = Icons.add_rounded;
        onPressed = _targets.isEmpty ? null : _openAddQuestion;
        break;
      case _WorkspaceMode.ai:
        label = 'Generate Questions';
        icon = Icons.auto_awesome_rounded;
        onPressed = _targets.isEmpty ? null : _handleGeneratePressed;
        break;
      case _WorkspaceMode.review:
        final int count = _selectedDraftQuestions().length;
        label = _savingDrafts ? 'Saving...' : 'Save ($count)';
        icon = Icons.save_outlined;
        onPressed = count == 0 || _savingDrafts ? null : _saveSelectedDraftQuestions;
        break;
    }

    return SizedBox(
      height: 42,
      width: compact ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: _savingDrafts && _mode == _WorkspaceMode.review
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildModeTabs({required bool compact}) {
    final List<_ModeSpec> specs = <_ModeSpec>[
      _ModeSpec(
        mode: _WorkspaceMode.manual,
        title: 'Manual Questions',
        subtitle: '${_manualDrafts().length} drafts',
        icon: Icons.edit_note_rounded,
      ),
      _ModeSpec(
        mode: _WorkspaceMode.ai,
        title: 'AI Drafts',
        subtitle: _aiPolling ? 'generating…' : '${_aiDrafts().length} drafts',
        icon: Icons.auto_awesome_rounded,
      ),
      _ModeSpec(
        mode: _WorkspaceMode.review,
        title: 'Review & Save',
        subtitle: '${_selectedDraftQuestions().length} ready',
        icon: Icons.fact_check_outlined,
      ),
    ];

    return Container(
      height: compact ? null : 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: compact
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: specs
                    .map(
                      (spec) => SizedBox(
                        width: 190,
                        child: _buildModeTab(spec, compact: compact),
                      ),
                    )
                    .toList(),
              ),
            )
          : Row(
              children: specs
                  .map((spec) => Expanded(child: _buildModeTab(spec, compact: compact)))
                  .toList(),
            ),
    );
  }

  Widget _buildModeTab(_ModeSpec spec, {required bool compact}) {
    final bool active = _mode == spec.mode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => setState(() => _mode = spec.mode),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.borderSoft.withOpacity(0.45),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                spec.icon,
                size: 17,
                color: active ? Colors.white : AppColors.textMuted,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      spec.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: active ? Colors.white : AppColors.textTitle,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      spec.subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.8,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white.withOpacity(0.82) : AppColors.textMuted,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersBar({required bool compact}) {
    final List<String> difficultyItems = <String>[
      'Any Difficulty',
      QuestionDifficulty.easy.label,
      QuestionDifficulty.medium.label,
      QuestionDifficulty.hard.label,
    ];
    final List<String> typeItems = <String>[
      'All Types',
      QuestionType.multipleChoice.label,
      QuestionType.multiSelect.label,
      QuestionType.trueFalse.label,
      QuestionType.shortAnswer.label,
      QuestionType.essay.label,
    ];

    final Widget search = FigmaUmSearch40(
      controller: _searchCtrl,
      hint: 'Search by question, topic, or tag...',
      onChanged: (_) => setState(() {}),
    );

    final Widget topicFilter = _TopicTreeFilterButton(
      selectedTopicId: _selectedTopicFilterId,
      targets: _targets,
      onChanged: (int? id) {
        setState(() => _selectedTopicFilterId = id);
      },
    );

    final Widget difficultyFilter = FigmaUmDropdown40(
      width: compact ? 170 : 158,
      value: _selectedDifficultyFilter,
      items: difficultyItems,
      onChanged: (String value) => setState(() => _selectedDifficultyFilter = value),
    );

    final Widget typeFilter = FigmaUmDropdown40(
      width: compact ? 148 : 136,
      value: _selectedTypeFilter,
      items: typeItems,
      onChanged: (String value) => setState(() => _selectedTypeFilter = value),
    );

    return Container(
      height: compact ? null : 56,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 12 : 0),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                search,
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      SizedBox(width: 220, child: topicFilter),
                      const SizedBox(width: 10),
                      difficultyFilter,
                      const SizedBox(width: 10),
                      typeFilter,
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(child: search),
                const SizedBox(width: 12),
                SizedBox(width: 230, child: topicFilter),
                const SizedBox(width: 10),
                difficultyFilter,
                const SizedBox(width: 10),
                typeFilter,
              ],
            ),
    );
  }

  Widget _buildModeContent({
    required List<QuestionModel> filteredQuestions,
    required int totalVisible,
  }) {
    switch (_mode) {
      case _WorkspaceMode.manual:
        return _buildQuestionList(
          title: 'Manual drafts',
          subtitle: 'Only checked questions move to Review & Save.',
          emptyTitle: 'No manual questions yet',
          emptyBody: 'Add a question, check it when it is ready, then review before saving.',
          emptyActionLabel: 'Add Question',
          emptyAction: _openAddQuestion,
          questions: filteredQuestions,
          totalVisible: totalVisible,
        );
      case _WorkspaceMode.ai:
        return Column(
          children: <Widget>[
            if (_aiPolling)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.badgeBlueBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.badgeBlueBorder),
                ),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'AI is generating your questions… This page updates automatically.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.badgeBlueFg,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _stopAiPolling,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        'Dismiss',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _buildQuestionList(
                title: 'AI drafts',
                subtitle: 'Check the questions you want to keep, then go to Review & Save.',
                emptyTitle: _aiPolling ? 'Waiting for AI…' : 'No AI drafts yet',
                emptyBody: _aiPolling
                    ? 'Questions will appear here as soon as the AI finishes. No need to refresh.'
                    : 'Use Generate Questions to configure the exact backend request for this scope.',
                emptyActionLabel: _aiPolling ? null : 'Generate Questions',
                emptyAction: _aiPolling ? null : _handleGeneratePressed,
                questions: filteredQuestions,
                totalVisible: totalVisible,
              ),
            ),
          ],
        );
      case _WorkspaceMode.review:
        return _buildQuestionList(
          title: 'Review queue',
          subtitle: 'These checked drafts are the only questions that will be saved.',
          emptyTitle: 'No selected questions',
          emptyBody: 'Check manual or AI drafts first. Only selected drafts appear here.',
          emptyActionLabel: 'Go to Manual',
          emptyAction: () => setState(() => _mode = _WorkspaceMode.manual),
          questions: filteredQuestions,
          totalVisible: totalVisible,
          reviewMode: true,
        );
    }
  }

  Widget _buildQuestionList({
    required String title,
    required String subtitle,
    required String emptyTitle,
    required String emptyBody,
    String? emptyActionLabel,
    VoidCallback? emptyAction,
    required List<QuestionModel> questions,
    required int totalVisible,
    bool reviewMode = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.infoBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    reviewMode ? Icons.fact_check_outlined : Icons.table_rows_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textTitle,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.8,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                _countPill('$totalVisible total'),
                const SizedBox(width: 8),
                _countPill('${questions.length} shown'),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderGray),
          Expanded(
            child: questions.isEmpty
                ? _buildEmptyState(
                    title: emptyTitle,
                    body: emptyBody,
                    actionLabel: emptyActionLabel,
                    action: emptyAction,
                  )
                : _buildQuestionTable(
                    questions: questions,
                    reviewMode: reviewMode,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionTable({
    required List<QuestionModel> questions,
    required bool reviewMode,
  }) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Column(
        children: <Widget>[
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: AppColors.surfaceBg,
            child: Row(
              children: <Widget>[
                const SizedBox(width: 42),
                _tableHeader('Question', flex: 5),
                _tableHeader('Topic', flex: 3),
                _tableHeader('Type', width: 128),
                _tableHeader('Difficulty', width: 108),
                _tableHeader('Source', width: 96),
                SizedBox(width: 96, child: Align(alignment: Alignment.centerRight, child: Text('Actions', style: _tableHeaderStyle()))),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderGray),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: questions.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.borderGray.withOpacity(0.75)),
              itemBuilder: (BuildContext context, int index) {
                final QuestionModel question = questions[index];
                return _buildQuestionTableRow(
                  question,
                  selected: _selectedQuestionIds.contains(question.id),
                  reviewMode: reviewMode,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String label, {int? flex, double? width}) {
    final Widget child = Text(label, overflow: TextOverflow.ellipsis, style: _tableHeaderStyle());
    if (width != null) return SizedBox(width: width, child: child);
    return Expanded(flex: flex ?? 1, child: child);
  }

  TextStyle _tableHeaderStyle() {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.35,
      color: AppColors.textMuted,
    );
  }

  Widget _buildQuestionTableRow(
    QuestionModel question, {
    required bool selected,
    required bool reviewMode,
  }) {
    final bool isDraft = _draftQuestions.any((QuestionModel item) => item.id == question.id);
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: selected ? AppColors.selectedBg.withOpacity(0.55) : AppColors.cardBg,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 42,
            child: Checkbox(
              value: selected,
              onChanged: (bool? value) => _toggleSelection(question.id, value ?? false),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              side: BorderSide(color: AppColors.borderSoft),
            ),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                question.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.2,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                  color: AppColors.textTitle,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                _questionTargetLabel(question),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          SizedBox(width: 128, child: Align(alignment: Alignment.centerLeft, child: _tablePill(question.typeLabel))),
          SizedBox(width: 108, child: Align(alignment: Alignment.centerLeft, child: _difficultyPill(question.difficultyLabel))),
          SizedBox(width: 96, child: Align(alignment: Alignment.centerLeft, child: _sourcePill(question.source))),
          SizedBox(
            width: 96,
            child: isDraft
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      _iconAction(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit draft',
                        compact: true,
                        onTap: () => _openEditDraftQuestion(question),
                      ),
                      const SizedBox(width: 6),
                      _iconAction(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Delete draft',
                        danger: true,
                        compact: true,
                        onTap: () => _deleteDraftQuestion(question),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String body,
    String? actionLabel,
    VoidCallback? action,
  }) {
    return Center(
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[Color(0xFF137FEC), Color(0xFF4F46E5)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.playlist_add_check_circle_outlined, color: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textTitle,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (actionLabel != null && action != null) ...<Widget>[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: action,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(actionLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<QuestionModel> _visibleQuestionsForMode() {
    switch (_mode) {
      case _WorkspaceMode.manual:
        return _manualDrafts();
      case _WorkspaceMode.ai:
        return _aiDrafts();
      case _WorkspaceMode.review:
        return _selectedDraftQuestions();
    }
  }

  List<QuestionModel> _manualDrafts() {
    return _draftQuestions
        .where((QuestionModel q) => q.source == QuestionSource.manual)
        .toList();
  }

  List<QuestionModel> _aiDrafts() {
    return _draftQuestions
        .where((QuestionModel q) => q.source == QuestionSource.aiGenerated)
        .toList();
  }

  List<QuestionModel> _selectedDraftQuestions() {
    return _draftQuestions
        .where((QuestionModel q) => _selectedQuestionIds.contains(q.id))
        .toList();
  }

  List<add_question_sheet.QuestionAuthoringTarget> _targetsForCurrentTopicFilter() {
    if (_selectedTopicFilterId == null) return _targets;
    return _targets
        .where((add_question_sheet.QuestionAuthoringTarget target) =>
            target.topicId == _selectedTopicFilterId,)
        .toList();
  }

  List<QuestionModel> _filteredQuestions(List<QuestionModel> questions) {
    final Set<int> targetTopicIds = _targets
        .map((add_question_sheet.QuestionAuthoringTarget target) => target.topicId)
        .toSet();
    final String rawSearch = _searchCtrl.text.trim().toLowerCase();

    final List<QuestionModel> filtered = questions.where((QuestionModel question) {
      final bool topicAllowed =
          question.topicId != null && targetTopicIds.contains(question.topicId);
      if (!topicAllowed) return false;

      if (_selectedTopicFilterId != null && question.topicId != _selectedTopicFilterId) {
        return false;
      }

      if (_selectedDifficultyFilter != 'Any Difficulty' &&
          question.difficultyLabel.toLowerCase() != _selectedDifficultyFilter.toLowerCase()) {
        return false;
      }

      if (_selectedTypeFilter != 'All Types' &&
          question.typeLabel.toLowerCase() != _selectedTypeFilter.toLowerCase()) {
        return false;
      }

      if (rawSearch.isNotEmpty) {
        final String haystack = <String>[
          question.text,
          question.contextLabel,
          question.typeLabel,
          _questionTargetLabel(question),
          ...question.tags,
        ].join(' ').toLowerCase();
        if (!haystack.contains(rawSearch)) return false;
      }

      return true;
    }).toList();

    filtered.sort((QuestionModel a, QuestionModel b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  String _headerSubtitle() {
    final QuestionAuthoringLaunchContext? launch = widget.launchContext;
    if (launch != null && launch.subtitle.trim().isNotEmpty) {
      return launch.subtitle;
    }
    if (widget.initialTopicIds.isNotEmpty) {
      return '${_primaryScopeTitle()} • questions will use this topic and its subtopics if they exist.';
    }
    if (widget.initialMaterialIds.isNotEmpty) {
      return '${_primaryScopeTitle()} • questions will use this file topics and subtopics.';
    }
    if (widget.initialModuleIds.isNotEmpty) {
      return '${_primaryScopeTitle()} • questions will use this module content tree.';
    }
    return '${_primaryScopeTitle()} • questions will use the selected content tree.';
  }

  String _primaryScopeTitle() {
    final QuestionAuthoringLaunchContext? launch = widget.launchContext;
    if (launch != null && launch.title.trim().isNotEmpty) {
      return launch.title;
    }
    if (_targets.isEmpty) return widget.course.title;
    final Set<String> materialNames = _targets
        .map((add_question_sheet.QuestionAuthoringTarget target) => target.materialName ?? '')
        .where((String name) => name.trim().isNotEmpty)
        .toSet();
    if (widget.initialMaterialIds.length == 1 && materialNames.length == 1) {
      return materialNames.first;
    }
    if (widget.initialTopicIds.length == 1) {
      return _compactTargetLabel(_targets.first);
    }
    final Set<String> moduleNames = _targets
        .map((add_question_sheet.QuestionAuthoringTarget target) => target.moduleName ?? '')
        .where((String name) => name.trim().isNotEmpty)
        .toSet();
    if (widget.initialModuleIds.length == 1 && moduleNames.length == 1) {
      return moduleNames.first;
    }
    return widget.course.title;
  }

  String _scopeLabel() {
    final QuestionAuthoringLaunchContext? launch = widget.launchContext;
    if (launch != null) return launch.label;
    if (widget.initialTopicIds.isNotEmpty) return 'Topic scope';
    if (widget.initialMaterialIds.isNotEmpty) return 'Material scope';
    if (widget.initialModuleIds.isNotEmpty) return 'Module scope';
    return 'Selected scope';
  }

  String _scopeBreakdown() {
    final int moduleCount = _targets.map((t) => t.moduleId).whereType<int>().toSet().length;
    final int materialCount = _targets.map((t) => t.materialId).whereType<int>().toSet().length;
    return '$moduleCount module • $materialCount file • ${_targets.length} topics';
  }

  String _questionTargetLabel(QuestionModel question) {
    for (final add_question_sheet.QuestionAuthoringTarget target in _targets) {
      if (target.topicId == question.topicId) return _compactTargetLabel(target);
    }
    return question.topicName ?? 'Unassigned topic';
  }

  Widget _scopeChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textGray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.textGray,
        ),
      ),
    );
  }

  Widget _inlineMeta(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _difficultyPill(String label) {
    final String normalized = label.toLowerCase();
    late Color textColor;
    late Color backgroundColor;

    switch (normalized) {
      case 'easy':
        textColor = AppColors.successText;
        backgroundColor = AppColors.successBg;
        break;
      case 'hard':
        textColor = AppColors.dangerTitle;
        backgroundColor = AppColors.dangerBg;
        break;
      default:
        textColor = AppColors.warningText;
        backgroundColor = AppColors.warningBg;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }

  Widget _sourcePill(QuestionSource source) {
    final bool ai = source == QuestionSource.aiGenerated;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ai ? AppColors.purpleBg : AppColors.infoBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            ai ? Icons.auto_awesome_rounded : Icons.edit_note_rounded,
            size: 13,
            color: ai ? AppColors.purpleText : AppColors.primary,
          ),
          const SizedBox(width: 5),
          Text(
            ai ? 'AI draft' : 'Manual',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: ai ? AppColors.purpleText : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tablePill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textGray,
        ),
      ),
    );
  }

  Widget _softPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: AppColors.textGray,
        ),
      ),
    );
  }

  Widget _readyPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.greenBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Selected for review',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: AppColors.greenText,
        ),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool danger = false,
    bool compact = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: compact ? 30 : 36,
          height: compact ? 30 : 36,
          decoration: BoxDecoration(
            color: danger ? AppColors.dangerBg : AppColors.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: danger ? AppColors.dangerBorder : AppColors.borderSoft),
          ),
          child: Icon(
            icon,
            size: compact ? 16 : 18,
            color: danger ? AppColors.dangerText : AppColors.textGray,
          ),
        ),
      ),
    );
  }
}

class _ModeSpec {
  final _WorkspaceMode mode;
  final String title;
  final String subtitle;
  final IconData icon;

  const _ModeSpec({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _BackToMaterialsButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool compact;

  const _BackToMaterialsButton({
    required this.onPressed,
    required this.compact,
  });

  @override
  State<_BackToMaterialsButton> createState() => _BackToMaterialsButtonState();
}

class _BackToMaterialsButtonState extends State<_BackToMaterialsButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          height: 42,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 12 : 14),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.primary : AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered ? AppColors.primary : AppColors.infoBorder,
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.shadowBlue.withOpacity(_hovered ? 0.28 : 0.18),
                blurRadius: _hovered ? 16 : 10,
                offset: Offset(0, _hovered ? 6 : 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _hovered ? Colors.white.withOpacity(0.18) : AppColors.infoBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 16,
                  color: _hovered ? Colors.white : AppColors.primary,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                'Back to Materials',
                style: TextStyle(
                  fontSize: widget.compact ? 12.5 : 13,
                  fontWeight: FontWeight.w900,
                  color: _hovered ? Colors.white : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterMenu extends StatelessWidget {
  final double width;
  final String label;
  final List<String> items;
  final ValueChanged<String> onSelected;

  const _FilterMenu({
    required this.width,
    required this.label,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final List<String> normalizedItems = <String>[];
    for (final String item in items) {
      if (!normalizedItems.contains(item)) normalizedItems.add(item);
    }

    return SizedBox(
      width: width,
      height: 48,
      child: PopupMenuButton<String>(
        tooltip: '',
        color: AppColors.cardBg,
        elevation: 5,
        surfaceTintColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.borderGray),
        ),
        position: PopupMenuPosition.under,
        offset: const Offset(0, 8),
        onSelected: onSelected,
        itemBuilder: (BuildContext context) {
          return normalizedItems.map((String item) {
            final bool isSelected = item == label;
            return PopupMenuItem<String>(
              value: item,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.selectedBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textGray,
                  ),
                ),
              ),
            );
          }).toList();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textGray,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicTreeFilterButton extends StatelessWidget {
  final int? selectedTopicId;
  final List<add_question_sheet.QuestionAuthoringTarget> targets;
  final ValueChanged<int?> onChanged;

  const _TopicTreeFilterButton({
    required this.selectedTopicId,
    required this.targets,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final add_question_sheet.QuestionAuthoringTarget? selected =
        selectedTopicId == null ? null : _findTarget(targets, selectedTopicId!);
    final String label = selected == null ? 'All Topics' : _compactTargetLabel(selected);

    return InkWell(
      onTap: () async {
        final int? result = await showDialog<int?>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.30),
          builder: (_) => _TopicTreeFilterDialog(
            targets: targets,
            selectedTopicId: selectedTopicId,
          ),
        );
        if (result != -999999) onChanged(result);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.account_tree_outlined, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textGray,
                ),
              ),
            ),
            Icon(Icons.unfold_more_rounded, color: AppColors.textMuted, size: 19),
          ],
        ),
      ),
    );
  }
}

class _TopicTreeFilterDialog extends StatefulWidget {
  final int? selectedTopicId;
  final List<add_question_sheet.QuestionAuthoringTarget> targets;

  const _TopicTreeFilterDialog({
    required this.selectedTopicId,
    required this.targets,
  });

  @override
  State<_TopicTreeFilterDialog> createState() => _TopicTreeFilterDialogState();
}

class _TopicTreeFilterDialogState extends State<_TopicTreeFilterDialog> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String query = _searchCtrl.text.trim().toLowerCase();
    final List<add_question_sheet.QuestionAuthoringTarget> filtered = widget.targets.where((target) {
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
                            'Topic filter',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textTitle,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Pick one topic/subtopic from the resolved course tree.',
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
                      onPressed: () => Navigator.of(context).pop(-999999),
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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  children: <Widget>[
                    _treeOption(
                      context,
                      selected: widget.selectedTopicId == null,
                      icon: Icons.all_inclusive_rounded,
                      title: 'All Topics',
                      subtitle: '${widget.targets.length} targets in current scope',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 8),
                    ..._buildGroupedTargetRows(context, filtered),
                  ],
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
    List<add_question_sheet.QuestionAuthoringTarget> targets,
  ) {
    final List<Widget> rows = <Widget>[];
    String? currentModule;
    String? currentMaterial;

    for (final add_question_sheet.QuestionAuthoringTarget target in targets) {
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
            title: _compactTargetLabel(target),
            subtitle: target.isSubtopic ? 'Subtopic' : 'Topic',
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
          border: Border.all(color: selected ? AppColors.primary.withOpacity(0.50) : AppColors.borderGray),
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

class _DraftQuestionEditDialog extends StatefulWidget {
  final QuestionModel question;
  final List<add_question_sheet.QuestionAuthoringTarget> targets;

  const _DraftQuestionEditDialog({
    required this.question,
    required this.targets,
  });

  @override
  State<_DraftQuestionEditDialog> createState() => _DraftQuestionEditDialogState();
}

class _DraftQuestionEditDialogState extends State<_DraftQuestionEditDialog> {
  late final TextEditingController _questionCtrl;
  late final TextEditingController _explanationCtrl;
  late QuestionDifficulty _difficulty;
  late int? _topicId;

  @override
  void initState() {
    super.initState();
    _questionCtrl = TextEditingController(text: widget.question.text);
    _explanationCtrl = TextEditingController(text: widget.question.explanation ?? '');
    _difficulty = widget.question.difficulty;
    _topicId = widget.question.topicId;
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _explanationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                      child: const Icon(Icons.edit_outlined, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Edit draft question',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textTitle,
                        ),
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
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                child: Column(
                  children: <Widget>[
                    _dialogField(
                      controller: _questionCtrl,
                      label: 'Question text',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    _dialogField(
                      controller: _explanationCtrl,
                      label: 'Explanation / note',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _simpleDropdown<QuestionDifficulty>(
                            label: 'Difficulty',
                            value: _difficulty,
                            items: QuestionDifficulty.values,
                            itemLabel: (QuestionDifficulty value) => value.label,
                            onChanged: (QuestionDifficulty? value) {
                              if (value != null) setState(() => _difficulty = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _simpleDropdown<int>(
                            label: 'Topic / Subtopic',
                            value: _topicId,
                            items: widget.targets.map((t) => t.topicId).toList(),
                            itemLabel: (int value) => _compactTargetLabel(_findTarget(widget.targets, value)!),
                            onChanged: (int? value) => setState(() => _topicId = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Apply changes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: AppColors.textGray, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
        filled: true,
        fillColor: AppColors.surfaceBg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _simpleDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T value) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
        filled: true,
        fillColor: AppColors.surfaceBg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
      dropdownColor: AppColors.cardBg,
      items: items
          .map((T value) => DropdownMenuItem<T>(
                value: value,
                child: Text(
                  itemLabel(value),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textGray, fontWeight: FontWeight.w700),
                ),
              ),)
          .toList(),
      onChanged: onChanged,
    );
  }

  void _submit() {
    final String text = _questionCtrl.text.trim();
    if (text.isEmpty || _topicId == null) return;
    final add_question_sheet.QuestionAuthoringTarget? target = _findTarget(widget.targets, _topicId!);

    Navigator.of(context).pop(
      QuestionModel(
        id: widget.question.id,
        remoteId: widget.question.remoteId,
        text: text,
        type: widget.question.type,
        difficulty: _difficulty,
        source: widget.question.source,
        approvalStatus: widget.question.approvalStatus,
        options: widget.question.options,
        correctOptionId: widget.question.correctOptionId,
        correctBool: widget.question.correctBool,
        sampleAnswer: widget.question.sampleAnswer,
        explanation: _explanationCtrl.text.trim().isEmpty ? null : _explanationCtrl.text.trim(),
        expectedAnswer: widget.question.expectedAnswer,
        tags: widget.question.tags,
        usageCount: widget.question.usageCount,
        successRate: widget.question.successRate,
        maxScore: widget.question.maxScore,
        autoGradable: widget.question.autoGradable,
        courseId: widget.question.courseId,
        moduleId: target?.moduleId ?? widget.question.moduleId,
        moduleName: target?.moduleName ?? widget.question.moduleName,
        materialId: target?.materialId ?? widget.question.materialId,
        materialName: target?.materialName ?? widget.question.materialName,
        topicId: target?.topicId ?? widget.question.topicId,
        topicName: target?.topicName ?? widget.question.topicName,
        learningOutcomes: widget.question.learningOutcomes,
        createdAt: widget.question.createdAt,
      ),
    );
  }
}

class _AiQuestionConfig {
  QuestionType type;
  QuestionDifficulty difficulty;
  int count;

  _AiQuestionConfig({
    required this.type,
    required this.difficulty,
    required this.count,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type.backendValue,
        'difficulty': difficulty.backendValue,
        'count': count,
      };
}

class _AiGenerationRequest {
  final List<Map<String, dynamic>> topics;

  const _AiGenerationRequest({required this.topics});

  int get topicCount => topics.length;

  int get totalQuestions {
    var total = 0;
    for (final Map<String, dynamic> topic in topics) {
      final List<dynamic> configs = topic['question_configs'] as List<dynamic>;
      for (final dynamic config in configs) {
        total += ((config as Map<String, dynamic>)['count'] as num).toInt();
      }
    }
    return total;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{'topics': topics};
}

class _AiGenerationDialog extends StatefulWidget {
  final List<add_question_sheet.QuestionAuthoringTarget> targets;

  const _AiGenerationDialog({required this.targets});

  @override
  State<_AiGenerationDialog> createState() => _AiGenerationDialogState();
}

class _AiGenerationDialogState extends State<_AiGenerationDialog> {
  final List<_AiQuestionConfig> _configs = <_AiQuestionConfig>[
    _AiQuestionConfig(
      type: QuestionType.multipleChoice,
      difficulty: QuestionDifficulty.medium,
      count: 5,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final _AiGenerationRequest request = _buildRequest();
    final String preview = const JsonEncoder.withIndent('  ').convert(request.toJson());

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 16, 18),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[Color(0xFF137FEC), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'AI question request',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textTitle,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Configure the exact payload expected by POST /courses/{course_id}/questions/ai-generate.',
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
              Divider(height: 1, color: AppColors.borderGray),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: 5,
                      child: ListView(
                        padding: const EdgeInsets.all(22),
                        children: <Widget>[
                          _sectionTitle('Generation targets', '${widget.targets.length} topics/subtopics'),
                          const SizedBox(height: 10),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 160),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.borderGray),
                            ),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(10),
                              shrinkWrap: true,
                              itemCount: widget.targets.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (BuildContext context, int index) {
                                final target = widget.targets[index];
                                return Row(
                                  children: <Widget>[
                                    Icon(
                                      target.isSubtopic
                                          ? Icons.subdirectory_arrow_right_rounded
                                          : Icons.topic_outlined,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _compactTargetLabel(target),
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textGray,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 22),
                          _sectionTitle('Question rules', '${_configs.length} config${_configs.length == 1 ? '' : 's'}'),
                          const SizedBox(height: 10),
                          ...List<Widget>.generate(_configs.length, (int index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _configRow(index),
                            );
                          }),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _configs.add(
                                  _AiQuestionConfig(
                                    type: QuestionType.trueFalse,
                                    difficulty: QuestionDifficulty.medium,
                                    count: 3,
                                  ),
                                );
                              });
                            },
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add rule'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.borderSoft),
                            ),
                          ),
                        ],
                      ),
                    ),
                    VerticalDivider(width: 1, color: AppColors.borderGray),
                    Expanded(
                      flex: 4,
                      child: Container(
                        color: AppColors.surfaceBg,
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _sectionTitle('Backend payload preview', '${request.totalQuestions} requested'),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.borderGray),
                                ),
                                child: SingleChildScrollView(
                                  child: Text(
                                    preview,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      height: 1.45,
                                      color: AppColors.textGray,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.of(context).pop(request),
                                icon: const Icon(Icons.auto_awesome_rounded),
                                label: const Text('Generate with this payload'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String meta) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: AppColors.textTitle,
            ),
          ),
        ),
        Text(
          meta,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _configRow(int index) {
    final _AiQuestionConfig config = _configs[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: _smallDropdown<QuestionType>(
              value: config.type,
              items: <QuestionType>[
                QuestionType.multipleChoice,
                QuestionType.multiSelect,
                QuestionType.trueFalse,
                QuestionType.shortAnswer,
                QuestionType.essay,
              ],
              label: (QuestionType value) => value.label,
              onChanged: (QuestionType? value) {
                if (value != null) setState(() => config.type = value);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _smallDropdown<QuestionDifficulty>(
              value: config.difficulty,
              items: QuestionDifficulty.values,
              label: (QuestionDifficulty value) => value.label,
              onChanged: (QuestionDifficulty? value) {
                if (value != null) setState(() => config.difficulty = value);
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 86,
            child: Row(
              children: <Widget>[
                _miniCountButton(Icons.remove_rounded, () {
                  setState(() => config.count = (config.count - 1).clamp(1, 50).toInt());
                }),
                Expanded(
                  child: Text(
                    '${config.count}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textTitle,
                    ),
                  ),
                ),
                _miniCountButton(Icons.add_rounded, () {
                  setState(() => config.count = (config.count + 1).clamp(1, 50).toInt());
                }),
              ],
            ),
          ),
          if (_configs.length > 1) ...<Widget>[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => setState(() => _configs.removeAt(index)),
              icon: Icon(Icons.close_rounded, size: 18, color: AppColors.dangerText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _smallDropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T value) label,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        dropdownColor: AppColors.cardBg,
        items: items
            .map((T item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    label(item),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),)
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _miniCountButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Icon(icon, size: 16, color: AppColors.textGray),
      ),
    );
  }

  _AiGenerationRequest _buildRequest() {
    return _AiGenerationRequest(
      topics: widget.targets.map((target) {
        return <String, dynamic>{
          'topic_id': target.topicId,
          'question_configs': _configs.map((config) => config.toJson()).toList(),
        };
      }).toList(),
    );
  }
}

add_question_sheet.QuestionAuthoringTarget? _findTarget(
  List<add_question_sheet.QuestionAuthoringTarget> targets,
  int topicId,
) {
  for (final add_question_sheet.QuestionAuthoringTarget target in targets) {
    if (target.topicId == topicId) return target;
  }
  return null;
}

String _compactTargetLabel(add_question_sheet.QuestionAuthoringTarget target) {
  final String topic = _compactText(target.topicName, max: 38);
  if (target.isSubtopic && target.parentTopicName != null) {
    return '${_compactText(target.parentTopicName!, max: 24)} › $topic';
  }
  return topic;
}

String _compactText(String value, {int max = 42}) {
  final String normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= max) return normalized;
  return '${normalized.substring(0, max - 1).trimRight()}…';
}