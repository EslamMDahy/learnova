import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/ui/toast.dart';
import '../../../data/courses_models.dart';
import '../../../data/materials_models.dart';
import '../../../data/modules_models.dart';
import '../../../data/question_models.dart';
import '../../../data/modules_materials_providers.dart';
import '../../../data/topics_models.dart';
import '../../controllers/course_details_controller.dart';
import '../add_question_sheet.dart' as add_question_sheet;

class QuestionBankAuthoringFlow extends ConsumerStatefulWidget {
  final MyCourseItem course;
  final Set<int> initialModuleIds;
  final Set<int> initialMaterialIds;
  final Set<int> initialTopicIds;
  final bool embedded;
  final VoidCallback? onClose;

  const QuestionBankAuthoringFlow({
    super.key,
    required this.course,
    this.initialModuleIds = const <int>{},
    this.initialMaterialIds = const <int>{},
    this.initialTopicIds = const <int>{},
    this.embedded = false,
    this.onClose,
  });

  @override
  ConsumerState<QuestionBankAuthoringFlow> createState() =>
      _QuestionBankAuthoringFlowState();
}

class _QuestionBankAuthoringFlowState
    extends ConsumerState<QuestionBankAuthoringFlow> {
  bool _loading = true;
  List<add_question_sheet.QuestionAuthoringTarget> _targets = const <add_question_sheet.QuestionAuthoringTarget>[];

  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selectedQuestionIds = <String>{};
  final List<QuestionModel> _draftQuestions = <QuestionModel>[];
  bool _savingDrafts = false;

  String _selectedTopicFilter = 'All Topics';
  String _selectedDifficultyFilter = 'Any Difficulty';
  String _selectedTypeFilter = 'All Types';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await ref
        .read(courseDetailsControllerProvider(widget.course.id).notifier)
        .loadModulesAndAllMaterials(force: false);
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

    final List<add_question_sheet.QuestionAuthoringTarget> resolved = <add_question_sheet.QuestionAuthoringTarget>[];
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
            a.orderIndex.compareTo(b.orderIndex));

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
            a.orderIndex.compareTo(b.orderIndex));
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
              a.orderIndex.compareTo(b.orderIndex));
        for (final TopicItem root in roots) {
          addLeafTargets(module, material, root, materialTopics);
        }
      }
    }

    return resolved;
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

  void _closeFlow() {
    if (widget.onClose != null) {
      widget.onClose!.call();
      return;
    }
    Navigator.of(context).maybePop();
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

  void _handleGeneratePressed() {
    AppToast.info(
      context,
      title: 'Generation scope prepared',
      message:
          'Selected ${_targets.length} target(s). The workspace is ready for backend AI question generation once the endpoint is connected.',
    );
  }

  Future<void> _saveDraftQuestions() async {
    if (_draftQuestions.isEmpty || _savingDrafts) return;

    setState(() => _savingDrafts = true);

    final api = ref.read(questionsApiProvider);
    final controller = ref.read(
      courseDetailsControllerProvider(widget.course.id).notifier,
    );
    final List<QuestionModel> savedQuestions = <QuestionModel>[];

    try {
      for (final QuestionModel draft in _draftQuestions.reversed) {
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
        _draftQuestions.clear();
        _selectedQuestionIds.clear();
        _savingDrafts = false;
      });

      AppToast.success(
        context,
        title: 'Questions saved',
        message: 'Questions were added to the question bank.',
      );
      _closeFlow();
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingDrafts = false);
      AppToast.error(
        context,
        title: 'Could not save questions',
        message: 'Check the question data and try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _wrapBody(
        const Scaffold(
          backgroundColor: Color(0xFFF8FAFC),
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final dynamic state = ref.watch(courseDetailsControllerProvider(widget.course.id));
    final List<QuestionModel> persistedQuestions =
        List<QuestionModel>.from(state.questions as List<dynamic>);
    final List<QuestionModel> allQuestions = <QuestionModel>[
      ..._draftQuestions,
      ...persistedQuestions,
    ];
    final List<QuestionModel> filteredQuestions = _filteredQuestions(allQuestions);
    final List<QuestionModel> selectedQuestions = allQuestions
        .where((QuestionModel question) => _selectedQuestionIds.contains(question.id))
        .toList();

    final Widget body = Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            children: <Widget>[
              _buildHeader(),
              const SizedBox(height: 18),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _buildMainPane(
                        filteredQuestions: filteredQuestions,
                        allQuestions: allQuestions,
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 280,
                      child: _buildSummaryPane(
                        allQuestions: allQuestions,
                        selectedQuestions: selectedQuestions,
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

    return _wrapBody(body);
  }

  Widget _wrapBody(Widget child) {
    if (widget.embedded) return child;
    return Dialog.fullscreen(child: child);
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 0, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextButton.icon(
                  onPressed: _closeFlow,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back to content'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF475467),
                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add Questions',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF101828),
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Build the question bank for the selected content.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _scopeChip(
                      icon: Icons.description_outlined,
                      label: _scopeLabel(),
                    ),
                    _scopeChip(
                      icon: Icons.adjust_rounded,
                      label:
                          '${_targets.length} target${_targets.length == 1 ? '' : 's'}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _savingDrafts || _draftQuestions.isEmpty
                    ? null
                    : _saveDraftQuestions,
                icon: _savingDrafts
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(
                  _savingDrafts
                      ? 'Saving...'
                      : 'Save Questions (${_draftQuestions.length})',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1570EF),
                  side: const BorderSide(color: Color(0xFF1570EF)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _savingDrafts ? null : _openAddQuestion,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add New Question'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1570EF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainPane({
    required List<QuestionModel> filteredQuestions,
    required List<QuestionModel> allQuestions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildAiGeneratorBanner(),
        const SizedBox(height: 16),
        _buildFiltersBar(allQuestions),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            const Text(
              'AVAILABLE QUESTIONS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.15,
                color: Color(0xFF667085),
              ),
            ),
            const Spacer(),
            _countPill(
              '${filteredQuestions.length} question${filteredQuestions.length == 1 ? '' : 's'}',
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: filteredQuestions.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  itemCount: filteredQuestions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int index) {
                    final QuestionModel question = filteredQuestions[index];
                    return _buildQuestionCard(
                      question,
                      selected: _selectedQuestionIds.contains(question.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAiGeneratorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E6F8)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF2F80ED),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'AI Question Generator',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF101828),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Let AI analyze the selected content and suggest relevant questions for your bank.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF667085),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: _handleGeneratePressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1570EF),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFD0D5DD)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Generate Questions',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBar(List<QuestionModel> allQuestions) {
    final List<String> topicItems = <String>['All Topics', ..._targets.map((add_question_sheet.QuestionAuthoringTarget target) => target.label).toSet()];
    final List<String> difficultyItems = <String>['Any Difficulty', ...allQuestions.map((QuestionModel question) => question.difficultyLabel).toSet()];
    final List<String> typeItems = <String>['All Types', ...allQuestions.map((QuestionModel question) => question.typeLabel).toSet()];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4E7EC)),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF344054),
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search questions by keyword or',
                  hintStyle: TextStyle(
                    color: Color(0xFF98A2B3),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: Color(0xFF667085),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _FilterMenu(
            width: 150,
            label: _selectedTopicFilter,
            items: topicItems,
            onSelected: (String value) {
              setState(() {
                _selectedTopicFilter = value;
              });
            },
          ),
          const SizedBox(width: 12),
          _FilterMenu(
            width: 140,
            label: _selectedDifficultyFilter,
            items: difficultyItems,
            onSelected: (String value) {
              setState(() {
                _selectedDifficultyFilter = value;
              });
            },
          ),
          const SizedBox(width: 12),
          _FilterMenu(
            width: 132,
            label: _selectedTypeFilter,
            items: typeItems,
            onSelected: (String value) {
              setState(() {
                _selectedTypeFilter = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(
    QuestionModel question, {
    required bool selected,
  }) {
    return InkWell(
      onTap: () => _toggleSelection(question.id, !selected),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFFB2DDFF) : const Color(0xFFE4E7EC),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Checkbox(
              value: selected,
              onChanged: (bool? value) => _toggleSelection(question.id, value ?? false),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: Color(0xFFD0D5DD)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    question.text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF101828),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: <Widget>[
                      _inlineMeta(Icons.account_tree_outlined, question.contextLabel),
                      _inlineMeta(Icons.view_list_rounded, question.typeLabel),
                      _inlineMeta(
                        Icons.history_toggle_off_rounded,
                        question.usageCount > 0
                            ? 'Used ${question.usageCount} time${question.usageCount == 1 ? '' : 's'}'
                            : 'New',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (_draftQuestions.any((QuestionModel item) => item.id == question.id)) ...<Widget>[
              _draftPill(),
              const SizedBox(width: 8),
            ],
            _difficultyPill(question.difficultyLabel),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFCFD),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF3FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.playlist_add_check_circle_outlined,
                color: Color(0xFF1570EF),
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No questions yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF101828),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start by adding your first manual question for the selected topic or subtopic.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF667085),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _openAddQuestion,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add New Question'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1570EF),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryPane({
    required List<QuestionModel> allQuestions,
    required List<QuestionModel> selectedQuestions,
  }) {
    final int draftCount = _draftQuestions.length;
    final String difficulty = _difficultySummary(
      selectedQuestions.isEmpty ? allQuestions : selectedQuestions,
    );

    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Question Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF101828),
                ),
              ),
              const SizedBox(height: 18),
              _summaryRow('Draft Questions', '$draftCount'),
              _summaryRow('Selected Targets', '${_targets.length}'),
              _summaryRow('Difficulty', difficulty, emphasizeValue: true),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFF1570EF),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Questions are kept as drafts here. They will be added to the database only when you click Save Questions.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475467),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scopeChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD0D5DD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: const Color(0xFF667085)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF344054),
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
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475467),
        ),
      ),
    );
  }

  Widget _inlineMeta(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: const Color(0xFF98A2B3)),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF667085),
            fontWeight: FontWeight.w500,
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
        textColor = const Color(0xFF027A48);
        backgroundColor = const Color(0xFFECFDF3);
        break;
      case 'hard':
        textColor = const Color(0xFFB42318);
        backgroundColor = const Color(0xFFFEF3F2);
        break;
      default:
        textColor = const Color(0xFFB54708);
        backgroundColor = const Color(0xFFFFF4ED);
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
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }

  Widget _draftPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Draft',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1570EF),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool emphasizeValue = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: emphasizeValue ? const Color(0xFFB54708) : const Color(0xFF101828),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  List<QuestionModel> _filteredQuestions(List<QuestionModel> questions) {
    final Set<int> targetTopicIds = _targets.map((add_question_sheet.QuestionAuthoringTarget target) => target.topicId).toSet();
    final String rawSearch = _searchCtrl.text.trim().toLowerCase();

    final List<QuestionModel> filtered = questions.where((QuestionModel question) {
      final bool topicAllowed = question.topicId != null && targetTopicIds.contains(question.topicId);
      if (!topicAllowed) return false;

      if (_selectedTopicFilter != 'All Topics') {
        add_question_sheet.QuestionAuthoringTarget? target;
        for (final add_question_sheet.QuestionAuthoringTarget item in _targets) {
          if (item.label == _selectedTopicFilter) {
            target = item;
            break;
          }
        }
        if (target == null || question.topicId != target.topicId) return false;
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
          ...question.tags,
        ].join(' ').toLowerCase();
        if (!haystack.contains(rawSearch)) return false;
      }

      return true;
    }).toList();

    filtered.sort((QuestionModel a, QuestionModel b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  String _difficultySummary(List<QuestionModel> questions) {
    if (questions.isEmpty) return 'Medium';

    int easy = 0;
    int medium = 0;
    int hard = 0;

    for (final QuestionModel question in questions) {
      switch (question.difficulty) {
        case QuestionDifficulty.easy:
          easy++;
          break;
        case QuestionDifficulty.medium:
          medium++;
          break;
        case QuestionDifficulty.hard:
          hard++;
          break;
      }
    }

    if (hard >= medium && hard >= easy) return 'Hard';
    if (easy >= medium && easy >= hard) return 'Easy';
    return 'Medium';
  }

  String _scopeLabel() {
    if (widget.initialTopicIds.isNotEmpty) return 'Selected topic / subtopic';
    if (widget.initialMaterialIds.isNotEmpty) return 'Selected file';
    if (widget.initialModuleIds.isNotEmpty) return 'Selected module';
    return 'Selected content';
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
    final List<String> normalizedItems = <String>[];
    for (final String item in items) {
      if (!normalizedItems.contains(item)) {
        normalizedItems.add(item);
      }
    }

    return SizedBox(
      width: width,
      height: 48,
      child: PopupMenuButton<String>(
        tooltip: '',
        color: Colors.white,
        elevation: 3,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE4E7EC)),
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
                  color: isSelected ? const Color(0xFFF2F4F7) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF344054),
                  ),
                ),
              ),
            );
          }).toList();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD0D5DD)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF344054),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF667085),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
