import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/ui/toast.dart';
import '../../../data/courses_models.dart';
import '../../../data/materials_models.dart';
import '../../../data/modules_models.dart';
import '../../../data/question_models.dart';
import '../../../data/topics_models.dart';
import '../../controllers/course_details_controller.dart';
import '../add_question_sheet.dart';

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
  List<QuestionAuthoringTarget> _targets = const [];

  final TextEditingController _searchCtrl = TextEditingController();
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
    final st = ref.read(courseDetailsControllerProvider(widget.course.id));
    setState(() {
      _targets = _resolveTargets(st);
      _loading = false;
    });
  }

  List<QuestionAuthoringTarget> _resolveTargets(dynamic st) {
    final modules = st.modules as List<ModuleItem>;
    final Map<int, List<MaterialItem>> materialsMap =
        Map<int, List<MaterialItem>>.from(st.materials as Map);
    final Map<int, List<TopicItem>> topicsMap =
        Map<int, List<TopicItem>>.from(st.topics as Map);
    final resolved = <QuestionAuthoringTarget>[];
    final seen = <int>{};

    ModuleItem? findModule(int id) =>
        modules.cast<ModuleItem?>().firstWhere((m) => m?.id == id, orElse: () => null);

    MaterialItem? findMaterial(int id) {
      for (final mats in materialsMap.values) {
        for (final mat in mats) {
          if (mat.id == id) return mat;
        }
      }
      return null;
    }

    TopicItem? findTopic(int id) {
      for (final tops in topicsMap.values) {
        for (final topic in tops) {
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
      final children = materialTopics
          .where((t) => t.parentTopicId == topic.id)
          .toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      if (children.isEmpty || topic.parentTopicId != null) {
        if (seen.add(topic.id)) {
          final parent = topic.parentTopicId == null
              ? null
              : materialTopics.cast<TopicItem?>().firstWhere(
                    (t) => t?.id == topic.parentTopicId,
                    orElse: () => null,
                  );
          resolved.add(
            QuestionAuthoringTarget(
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

      for (final child in children) {
        addLeafTargets(module, material, child, materialTopics);
      }
    }

    for (final topicId in widget.initialTopicIds) {
      final topic = findTopic(topicId);
      if (topic == null) continue;
      final material = findMaterial(topic.materialId);
      if (material == null) continue;
      final module = findModule(topic.moduleId);
      if (module == null) continue;
      final materialTopics = (topicsMap[module.id] ?? const <TopicItem>[])
          .where((t) => t.materialId == material.id)
          .toList();
      addLeafTargets(module, material, topic, materialTopics);
    }

    for (final materialId in widget.initialMaterialIds) {
      final material = findMaterial(materialId);
      if (material == null) continue;
      final module = findModule(material.moduleId);
      if (module == null) continue;
      final materialTopics = (topicsMap[module.id] ?? const <TopicItem>[])
          .where((t) => t.materialId == material.id)
          .toList();
      final roots = materialTopics.where((t) => t.parentTopicId == null).toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      for (final root in roots) {
        addLeafTargets(module, material, root, materialTopics);
      }
    }

    for (final moduleId in widget.initialModuleIds) {
      final module = findModule(moduleId);
      if (module == null) continue;
      final materials = materialsMap[module.id] ?? const <MaterialItem>[];
      final moduleTopics = topicsMap[module.id] ?? const <TopicItem>[];
      for (final material in materials) {
        final materialTopics =
            moduleTopics.where((t) => t.materialId == material.id).toList();
        final roots = materialTopics.where((t) => t.parentTopicId == null).toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        for (final root in roots) {
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

    await showAddQuestionDialog(
      context,
      moduleId: _targets.first.moduleId,
      moduleName: _targets.first.moduleName,
      materialId: _targets.first.materialId,
      materialName: _targets.first.materialName,
      topicId: _targets.first.topicId,
      topicName: _targets.first.topicName,
      topicTargets: _targets,
      onAdd: (q) => ref
          .read(courseDetailsControllerProvider(widget.course.id).notifier)
          .addQuestion(q),
    );
  }

  void _closeFlow() {
    if (widget.onClose != null) {
      widget.onClose!.call();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _wrapBody(
        const Center(child: CircularProgressIndicator()),
      );
    }

    final st = ref.watch(courseDetailsControllerProvider(widget.course.id));
    final filteredQuestions = _filteredQuestions(st.questions);

    final body = Container(
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildLeftPane(filteredQuestions),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 320,
                    child: _buildRightPane(st.questions),
                  ),
                ],
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _closeFlow,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Questions',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Build the question bank for the selected content.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _headerPill(
                      icon: Icons.account_tree_outlined,
                      label: _scopeLabel(),
                    ),
                    _headerPill(
                      icon: Icons.ads_click_outlined,
                      label: '${_targets.length} target${_targets.length == 1 ? '' : 's'}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _openAddQuestion,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add New Question'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF137FEC),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPane(List<QuestionModel> filteredQuestions) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Question Generator',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Let AI analyze the selected content and suggest relevant questions for your bank.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Generate Questions',
                        style: TextStyle(
                          color: Color(0xFF137FEC),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search questions by keyword',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: Color(0xFF94A3B8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF137FEC),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildFilterDropdown(
                      value: _selectedTopicFilter,
                      width: 132,
                      items: ['All Topics', ..._targets.map((e) => e.label)],
                      onChanged: (value) => setState(() => _selectedTopicFilter = value!),
                    ),
                    const SizedBox(width: 12),
                    _buildFilterDropdown(
                      value: _selectedDifficultyFilter,
                      width: 132,
                      items: const ['Any Difficulty', 'Easy', 'Medium', 'Hard'],
                      onChanged: (value) =>
                          setState(() => _selectedDifficultyFilter = value!),
                    ),
                    const SizedBox(width: 12),
                    _buildFilterDropdown(
                      value: _selectedTypeFilter,
                      width: 116,
                      items: const [
                        'All Types',
                        'Multiple Choice',
                        'True / False',
                        'Short Answer',
                        'Essay',
                        'Multi Select',
                      ],
                      onChanged: (value) => setState(() => _selectedTypeFilter = value!),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
            child: Row(
              children: [
                const Text(
                  'AVAILABLE QUESTIONS',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    '${filteredQuestions.length} question${filteredQuestions.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredQuestions.isEmpty
                ? _buildEmptyQuestionsState()
                : Scrollbar(
                    thumbVisibility: true,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: filteredQuestions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) =>
                          _buildQuestionCard(filteredQuestions[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPane(List<QuestionModel> allQuestions) {
    final manualCount = allQuestions
        .where((q) => q.source == QuestionSource.manual)
        .length;
    final aiCount = allQuestions
        .where((q) => q.source == QuestionSource.aiGenerated)
        .length;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quiz Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 20),
                _summaryRow('Total Questions', '${allQuestions.length}'),
                _summaryRow('Selected Targets', '${_targets.length}'),
                _summaryRow('Difficulty', _difficultySummary(allQuestions)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _openAddQuestion,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: const Color(0xFF137FEC),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Add New Question',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _closeFlow,
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Back to tree'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            foregroundColor: const Color(0xFF0F172A),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildEmptyQuestionsState() {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                size: 30,
                color: Color(0xFF137FEC),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No questions yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start by adding your first manual question for the selected topic or subtopic.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _openAddQuestion,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add New Question'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF137FEC),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
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

  Widget _buildQuestionCard(QuestionModel question) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _metaPill(question.contextLabel),
                    _metaPill(question.typeLabel),
                    _metaPill(
                      question.usageCount > 0
                          ? 'Used ${question.usageCount} time${question.usageCount == 1 ? '' : 's'}'
                          : 'New',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _difficultyPill(question.difficultyLabel),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required double width,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : items.first,
        onChanged: onChanged,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF137FEC), width: 1.2),
          ),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _headerPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _difficultyPill(String label) {
    final normalized = label.toLowerCase();
    Color textColor;
    Color bgColor;

    switch (normalized) {
      case 'easy':
        textColor = const Color(0xFF15803D);
        bgColor = const Color(0xFFDCFCE7);
        break;
      case 'hard':
        textColor = const Color(0xFFB91C1C);
        bgColor = const Color(0xFFFEE2E2);
        break;
      default:
        textColor = const Color(0xFFC2410C);
        bgColor = const Color(0xFFFFEDD5);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
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

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  List<QuestionModel> _filteredQuestions(List<QuestionModel> questions) {
    final targetTopicIds = _targets.map((e) => e.topicId).toSet();
    final rawSearch = _searchCtrl.text.trim().toLowerCase();

    return questions.where((question) {
      final topicAllowed =
          question.topicId != null && targetTopicIds.contains(question.topicId);
      if (!topicAllowed) return false;

      if (_selectedTopicFilter != 'All Topics') {
        final target = _targets.cast<QuestionAuthoringTarget?>().firstWhere(
              (t) => t?.label == _selectedTopicFilter,
              orElse: () => null,
            );
        if (target == null || question.topicId != target.topicId) return false;
      }

      if (_selectedDifficultyFilter != 'Any Difficulty' &&
          question.difficultyLabel.toLowerCase() !=
              _selectedDifficultyFilter.toLowerCase()) {
        return false;
      }

      if (_selectedTypeFilter != 'All Types' &&
          question.typeLabel.toLowerCase() != _selectedTypeFilter.toLowerCase()) {
        return false;
      }

      if (rawSearch.isNotEmpty) {
        final haystack = [
          question.text,
          question.contextLabel,
          question.typeLabel,
          ...question.tags,
        ].join(' ').toLowerCase();
        if (!haystack.contains(rawSearch)) return false;
      }

      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  String _difficultySummary(List<QuestionModel> questions) {
    final filtered = _filteredQuestions(questions);
    if (filtered.isEmpty) return 'Medium';

    int easy = 0;
    int medium = 0;
    int hard = 0;

    for (final question in filtered) {
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
