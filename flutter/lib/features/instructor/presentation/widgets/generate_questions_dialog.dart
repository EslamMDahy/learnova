import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/toast.dart';
import '../controllers/course_details_controller.dart';
import '../controllers/course_details_state.dart';
import '../../data/materials_models.dart';
import '../../data/modules_models.dart';
import '../../data/topics_models.dart';
import '../../data/questions_api.dart';
import '../../data/modules_materials_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  GenerateQuestionsDialog — AI question generation dialog for instructors.
//
//  Flow:
//    1. Instructor selects topics (required) from the course tree.
//    2. Instructor configures per-type / per-difficulty question counts.
//    3. On submit: POST /courses/{course_id}/questions/ai-generate
//       Body: { topics: [ { topic_id, question_configs: [{type, difficulty, count}] } ] }
//    4. Backend responds with { status, ai_processing_started, message }.
//    5. Show success/error toast and close.
//
//  The backend only accepts specific type strings:
//    "multiple_choice" | "multi_select" | "true_false" | "short_answer" | "essay"
//  And difficulty strings: "easy" | "medium" | "hard"
//  (No "mixed" — must be expanded client-side.)
// ─────────────────────────────────────────────────────────────────────────────

// ── Internal difficulty / type constants ──────────────────────────────────────

const _kDifficulties = ['easy', 'medium', 'hard'];

const _kTypes = [
  _QType(backendValue: 'multiple_choice', label: 'MCQ'),
  _QType(backendValue: 'true_false', label: 'True / False'),
  _QType(backendValue: 'short_answer', label: 'Short Answer'),
  _QType(backendValue: 'essay', label: 'Essay'),
  _QType(backendValue: 'multi_select', label: 'Multi-Select'),
];

class _QType {
  final String backendValue;
  final String label;
  const _QType({required this.backendValue, required this.label});
}

// ── Per-topic config model ─────────────────────────────────────────────────

class _TopicConfig {
  /// topic_id as received from the backend.
  final int topicId;

  /// Map from backendType -> Map<difficulty, count>.
  /// e.g. { 'multiple_choice': { 'easy': 2, 'medium': 3 } }
  final Map<String, Map<String, int>> configs;

  const _TopicConfig({required this.topicId, required this.configs});

  /// Returns total question count across all configs.
  int get total => configs.values
      .expand((m) => m.values)
      .fold(0, (sum, v) => sum + v);

  /// Converts to the backend `question_configs` list.
  List<AiQuestionGenerationConfig> toApiConfigs() {
    final result = <AiQuestionGenerationConfig>[];
    for (final entry in configs.entries) {
      for (final diffEntry in entry.value.entries) {
        if (diffEntry.value > 0) {
          result.add(AiQuestionGenerationConfig(
            type: entry.key,
            difficulty: diffEntry.key,
            count: diffEntry.value,
          ));
        }
      }
    }
    return result;
  }

  bool get isValid => toApiConfigs().isNotEmpty;

  _TopicConfig copyWithCount(String type, String difficulty, int count) {
    final newConfigs = Map<String, Map<String, int>>.from(
      configs.map((k, v) => MapEntry(k, Map<String, int>.from(v))),
    );
    newConfigs[type] ??= {};
    newConfigs[type]![difficulty] = count < 0 ? 0 : count;
    return _TopicConfig(topicId: topicId, configs: newConfigs);
  }
}

// ── Topic selection item (enriched with module + material context) ─────────

class _TopicSelectionItem {
  final ModuleItem module;
  final MaterialItem material;
  final TopicItem topic;

  const _TopicSelectionItem({
    required this.module,
    required this.material,
    required this.topic,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Main dialog widget
// ─────────────────────────────────────────────────────────────────────────────

class GenerateQuestionsDialog extends ConsumerStatefulWidget {
  final int courseId;
  final int? initialModuleId;
  final int? initialTopicId;
  final List<int>? initialTopicIds;

  /// Kept for call-site compatibility — the dialog works on topic-level scope,
  /// so material IDs are not forwarded to the backend but the module filter
  /// still narrows which topics appear in the list.
  // ignore: unused_element
  final int? initialMaterialId;
  // ignore: unused_element
  final List<int>? initialMaterialIds;

  const GenerateQuestionsDialog({
    super.key,
    required this.courseId,
    this.initialModuleId,
    this.initialMaterialId,
    this.initialMaterialIds,
    this.initialTopicId,
    this.initialTopicIds,
  });

  @override
  ConsumerState<GenerateQuestionsDialog> createState() =>
      _GenerateQuestionsDialogState();
}

class _GenerateQuestionsDialogState
    extends ConsumerState<GenerateQuestionsDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Step 1 — topic selection
  final Set<int> _selectedTopicIds = {};
  String _searchQuery = '';

  // Step 2 — per-topic config
  final Map<int, _TopicConfig> _topicConfigs = {};

  // UI state
  bool _submitting = false;

  // Current step: 0 = select topics, 1 = configure
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (widget.initialTopicIds != null) {
      _selectedTopicIds.addAll(widget.initialTopicIds!);
    }
    if (widget.initialTopicId != null) {
      _selectedTopicIds.add(widget.initialTopicId!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Topic tree helpers ────────────────────────────────────────────────────

  List<_TopicSelectionItem> _buildTopicList(CourseDetailsState state) {
    final modules = state.modules;
    final allMaterials = <MaterialItem>[];
    for (final entry in state.materials.entries) {
      allMaterials.addAll(entry.value);
    }
    final moduleById = {for (final m in modules) m.id: m};
    final materialById = {for (final m in allMaterials) m.id: m};

    final items = <_TopicSelectionItem>[];
    for (final entry in state.topics.entries) {
      final module = moduleById[entry.key];
      if (module == null) continue;
      for (final topic in entry.value) {
        final material = materialById[topic.materialId];
        if (material == null) continue;
        if (widget.initialModuleId != null &&
            module.id != widget.initialModuleId) continue;
        items.add(_TopicSelectionItem(
          module: module,
          material: material,
          topic: topic,
        ));
      }
    }

    items.sort((a, b) {
      final mc = a.module.title.toLowerCase().compareTo(b.module.title.toLowerCase());
      if (mc != 0) return mc;
      final mtc = a.material.displayTitle.toLowerCase().compareTo(b.material.displayTitle.toLowerCase());
      if (mtc != 0) return mtc;
      return a.topic.orderIndex.compareTo(b.topic.orderIndex);
    });

    return items;
  }

  List<_TopicSelectionItem> _filtered(List<_TopicSelectionItem> all) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((item) {
      return item.topic.title.toLowerCase().contains(q) ||
          item.material.displayTitle.toLowerCase().contains(q) ||
          item.module.title.toLowerCase().contains(q);
    }).toList();
  }

  // ── Config helpers ────────────────────────────────────────────────────────

  _TopicConfig _configFor(int topicId) {
    return _topicConfigs[topicId] ??
        _TopicConfig(topicId: topicId, configs: {});
  }

  void _setCount(int topicId, String type, String difficulty, int count) {
    setState(() {
      _topicConfigs[topicId] =
          _configFor(topicId).copyWithCount(type, difficulty, count);
    });
  }

  int _getCount(int topicId, String type, String difficulty) {
    return _topicConfigs[topicId]?.configs[type]?[difficulty] ?? 0;
  }

  int get _totalQuestions => _selectedTopicIds.fold(0, (sum, id) {
        return sum + _configFor(id).total;
      });

  bool get _canSubmit {
    if (_selectedTopicIds.isEmpty) return false;
    return _selectedTopicIds.every((id) => _configFor(id).isValid);
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;

    setState(() => _submitting = true);

    try {
      final topics = _selectedTopicIds.map((id) {
        return AiQuestionGenerationTopic(
          topicId: id,
          questionConfigs: _configFor(id).toApiConfigs(),
        );
      }).toList();

      final request = AiQuestionGenerationRequest(topics: topics);

      final resp = await ref.read(questionsApiProvider).generateQuestions(
            courseId: widget.courseId,
            payload: request,
          );

      if (!mounted) return;

      if (resp.aiProcessingStarted) {
        AppToast.success(
          context,
          title: 'Generation started',
          message: resp.message ??
              'AI is generating your questions. They will appear in the question bank once ready.',
          duration: const Duration(seconds: 6),
        );
        Navigator.of(context).pop(true);
      } else {
        AppToast.warning(
          context,
          title: 'Request received',
          message: resp.message ?? 'Request submitted but AI processing has not started yet.',
          duration: const Duration(seconds: 5),
        );
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.error(
        context,
        title: 'Generation failed',
        message: _humanizeError(e),
        duration: const Duration(seconds: 6),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _humanizeError(Object e) {
    final raw = e.toString();
    if (raw.contains('403')) return 'Only instructors can generate questions.';
    if (raw.contains('404')) return 'One or more topics were not found. Please refresh and try again.';
    if (raw.contains('422')) return 'Invalid request. Check your configuration and try again.';
    if (raw.contains('503')) return 'AI service is temporarily unavailable. Please try again later.';
    return 'Something went wrong. Please try again.';
  }

  // ── Navigation between steps ──────────────────────────────────────────────

  void _goToStep(int step) {
    setState(() => _step = step);
    _tabController.animateTo(step);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(courseDetailsControllerProvider(widget.courseId));
    final allTopics = _buildTopicList(state);
    final filtered = _filtered(allTopics);

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 780,
        height: 660,
        child: Column(
          children: [
            _DialogHeader(
              step: _step,
              selectedCount: _selectedTopicIds.length,
              totalQuestions: _totalQuestions,
              onClose: () => Navigator.of(context).pop(),
            ),
            _StepTabBar(controller: _tabController, step: _step),
            const SizedBox(height: 4),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // ── Step 1: Select Topics ─────────────────────────────
                  _SelectTopicsStep(
                    allItems: allTopics,
                    filteredItems: filtered,
                    selectedIds: _selectedTopicIds,
                    searchQuery: _searchQuery,
                    onSearchChanged: (v) => setState(() => _searchQuery = v),
                    onToggle: (id, selected) => setState(() {
                      if (selected) {
                        _selectedTopicIds.add(id);
                      } else {
                        _selectedTopicIds.remove(id);
                        _topicConfigs.remove(id);
                      }
                    }),
                    onSelectAll: () => setState(() {
                      for (final item in filtered) {
                        _selectedTopicIds.add(item.topic.id);
                      }
                    }),
                    onClearAll: () => setState(() {
                      _selectedTopicIds.clear();
                      _topicConfigs.clear();
                    }),
                  ),
                  // ── Step 2: Configure ─────────────────────────────────
                  _ConfigureStep(
                    selectedTopicIds: _selectedTopicIds,
                    allTopics: allTopics,
                    getCount: _getCount,
                    setCount: _setCount,
                  ),
                ],
              ),
            ),
            _DialogFooter(
              step: _step,
              selectedCount: _selectedTopicIds.length,
              canProceed: _selectedTopicIds.isNotEmpty,
              canSubmit: _canSubmit,
              submitting: _submitting,
              totalQuestions: _totalQuestions,
              onBack: () => _goToStep(0),
              onNext: () => _goToStep(1),
              onCancel: () => Navigator.of(context).pop(),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _DialogHeader
// ─────────────────────────────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  final int step;
  final int selectedCount;
  final int totalQuestions;
  final VoidCallback onClose;

  const _DialogHeader({
    required this.step,
    required this.selectedCount,
    required this.totalQuestions,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generate Questions with AI',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step == 0
                      ? 'Select the topics you want questions generated for.'
                      : 'Configure question types, difficulty, and count per topic.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (step == 1 && selectedCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.badgeBlueBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.badgeBlueBorder),
              ),
              child: Text(
                '$totalQuestions questions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.badgeBlueFg,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _StepTabBar — visual step indicator
// ─────────────────────────────────────────────────────────────────────────────

class _StepTabBar extends StatelessWidget {
  final TabController controller;
  final int step;

  const _StepTabBar({required this.controller, required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          _StepChip(index: 0, label: 'Select Topics', active: step == 0, done: step > 0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ),
          _StepChip(index: 1, label: 'Configure', active: step == 1, done: false),
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  final int index;
  final String label;
  final bool active;
  final bool done;

  const _StepChip({
    required this.index,
    required this.label,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary
                : done
                    ? AppColors.primary.withOpacity(0.15)
                    : AppColors.border,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: done
                ? Icon(Icons.check_rounded, size: 12, color: AppColors.primary)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : AppColors.textMuted,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppColors.textTitle : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Step 1 — Select Topics
// ─────────────────────────────────────────────────────────────────────────────

class _SelectTopicsStep extends StatelessWidget {
  final List<_TopicSelectionItem> allItems;
  final List<_TopicSelectionItem> filteredItems;
  final Set<int> selectedIds;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final void Function(int id, bool selected) onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;

  const _SelectTopicsStep({
    required this.allItems,
    required this.filteredItems,
    required this.selectedIds,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onToggle,
    required this.onSelectAll,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Column(
        children: [
          // Search + actions row
          Row(
            children: [
              Expanded(
                child: _SearchField(
                  hint: 'Search topics, materials, or modules…',
                  value: searchQuery,
                  onChanged: onSearchChanged,
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: filteredItems.isEmpty ? null : onSelectAll,
                child: const Text('Select all'),
              ),
              TextButton(
                onPressed: selectedIds.isEmpty ? null : onClearAll,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Selected count badge
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${selectedIds.length} topic${selectedIds.length == 1 ? '' : 's'} selected',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selectedIds.isNotEmpty
                    ? AppColors.primary
                    : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // List
          Expanded(
            child: allItems.isEmpty
                ? _EmptyState(
                    icon: Icons.topic_outlined,
                    title: 'No topics found',
                    subtitle:
                        'Add topics inside materials first, then come back to generate questions.',
                  )
                : filteredItems.isEmpty
                    ? _EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No results',
                        subtitle: 'Try a different search term.',
                      )
                    : _GroupedTopicList(
                        items: filteredItems,
                        selectedIds: selectedIds,
                        onToggle: onToggle,
                      ),
          ),
        ],
      ),
    );
  }
}

class _GroupedTopicList extends StatelessWidget {
  final List<_TopicSelectionItem> items;
  final Set<int> selectedIds;
  final void Function(int id, bool selected) onToggle;

  const _GroupedTopicList({
    required this.items,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Group by module → material
    final grouped = <String, List<_TopicSelectionItem>>{};
    for (final item in items) {
      final key = '${item.module.id}::${item.material.id}';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    final sections = grouped.entries.toList();

    return ListView.builder(
      itemCount: sections.length,
      itemBuilder: (_, si) {
        final entries = sections[si].value;
        final first = entries.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
              child: Row(
                children: [
                  Icon(Icons.folder_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    '${first.module.title}  ›  ${first.material.displayTitle}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < entries.length; i++) ...[
                    if (i > 0)
                      Divider(
                          height: 1, indent: 16, color: AppColors.border),
                    _TopicRow(
                      item: entries[i],
                      selected: selectedIds.contains(entries[i].topic.id),
                      onToggle: (v) => onToggle(entries[i].topic.id, v),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}

class _TopicRow extends StatelessWidget {
  final _TopicSelectionItem item;
  final bool selected;
  final ValueChanged<bool> onToggle;

  const _TopicRow({
    required this.item,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onToggle(!selected),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: selected,
                onChanged: (v) => onToggle(v ?? false),
                activeColor: AppColors.primary,
                side: BorderSide(color: AppColors.border, width: 1.5),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.topic.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTitle,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _ReadinessBadge(readiness: item.topic.readiness),
                      const SizedBox(width: 8),
                      Text(
                        item.topic.difficulty.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
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

class _ReadinessBadge extends StatelessWidget {
  final TopicReadiness readiness;
  const _ReadinessBadge({required this.readiness});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (readiness) {
      case TopicReadiness.ready:
        bg = AppColors.successBg;
        fg = AppColors.successText;
        break;
      case TopicReadiness.review:
        bg = AppColors.warningSoftBg;
        fg = AppColors.warningText;
        break;
      case TopicReadiness.draft:
        bg = AppColors.surfaceBg;
        fg = AppColors.textMuted;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        readiness.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Step 2 — Configure
// ─────────────────────────────────────────────────────────────────────────────

class _ConfigureStep extends StatelessWidget {
  final Set<int> selectedTopicIds;
  final List<_TopicSelectionItem> allTopics;
  final int Function(int topicId, String type, String difficulty) getCount;
  final void Function(int topicId, String type, String difficulty, int count)
      setCount;

  const _ConfigureStep({
    required this.selectedTopicIds,
    required this.allTopics,
    required this.getCount,
    required this.setCount,
  });

  String _topicTitle(int topicId) {
    for (final item in allTopics) {
      if (item.topic.id == topicId) return item.topic.title;
    }
    return 'Topic $topicId';
  }

  @override
  Widget build(BuildContext context) {
    final topicIds = selectedTopicIds.toList();

    if (topicIds.isEmpty) {
      return _EmptyState(
        icon: Icons.checklist_rounded,
        title: 'No topics selected',
        subtitle: 'Go back and select at least one topic.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      itemCount: topicIds.length,
      itemBuilder: (_, i) => _TopicConfigCard(
        topicId: topicIds[i],
        title: _topicTitle(topicIds[i]),
        getCount: getCount,
        setCount: setCount,
      ),
    );
  }
}

class _TopicConfigCard extends StatelessWidget {
  final int topicId;
  final String title;
  final int Function(int topicId, String type, String difficulty) getCount;
  final void Function(int topicId, String type, String difficulty, int count)
      setCount;

  const _TopicConfigCard({
    required this.topicId,
    required this.title,
    required this.getCount,
    required this.setCount,
  });

  int get _total => _kTypes.fold(0, (sum, t) {
        return sum +
            _kDifficulties.fold(
                0, (s, d) => s + getCount(topicId, t.backendValue, d));
      });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTitle,
                    ),
                  ),
                ),
                if (_total > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.badgeBlueBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.badgeBlueBorder),
                    ),
                    child: Text(
                      '$_total total',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.badgeBlueFg,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          // Grid header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                const SizedBox(width: 130),
                ..._kDifficulties.map((d) => Expanded(
                      child: Text(
                        d[0].toUpperCase() + d.substring(1),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    )),
              ],
            ),
          ),
          // Grid rows
          for (final qtype in _kTypes)
            _TypeRow(
              typeLabel: qtype.label,
              topicId: topicId,
              backendType: qtype.backendValue,
              getCount: getCount,
              setCount: setCount,
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  final String typeLabel;
  final int topicId;
  final String backendType;
  final int Function(int topicId, String type, String difficulty) getCount;
  final void Function(int topicId, String type, String difficulty, int count)
      setCount;

  const _TypeRow({
    required this.typeLabel,
    required this.topicId,
    required this.backendType,
    required this.getCount,
    required this.setCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              typeLabel,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textTitle,
              ),
            ),
          ),
          ..._kDifficulties.map((diff) {
            final count = getCount(topicId, backendType, diff);
            return Expanded(
              child: _CountStepper(
                value: count,
                onChanged: (v) => setCount(topicId, backendType, diff, v),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CountStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _CountStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: value > 0 ? () => onChanged(value - 1) : null,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: value > 0 ? AppColors.surfaceBg : AppColors.border,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              Icons.remove_rounded,
              size: 14,
              color: value > 0 ? AppColors.textTitle : AppColors.textMuted,
            ),
          ),
        ),
        SizedBox(
          width: 30,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: value > 0 ? AppColors.textTitle : AppColors.textMuted,
            ),
          ),
        ),
        GestureDetector(
          onTap: value < 20 ? () => onChanged(value + 1) : null,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.surfaceBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              Icons.add_rounded,
              size: 14,
              color: value < 20 ? AppColors.textTitle : AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Footer
// ─────────────────────────────────────────────────────────────────────────────

class _DialogFooter extends StatelessWidget {
  final int step;
  final int selectedCount;
  final bool canProceed;
  final bool canSubmit;
  final bool submitting;
  final int totalQuestions;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const _DialogFooter({
    required this.step,
    required this.selectedCount,
    required this.canProceed,
    required this.canSubmit,
    required this.submitting,
    required this.totalQuestions,
    required this.onBack,
    required this.onNext,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (submitting) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                backgroundColor: AppColors.border,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              // Summary label
              Text(
                step == 0
                    ? '$selectedCount topic${selectedCount == 1 ? '' : 's'} selected'
                    : '$totalQuestions question${totalQuestions == 1 ? '' : 's'} to generate',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: submitting ? null : onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              if (step == 0) ...[
                ElevatedButton.icon(
                  onPressed: canProceed ? onNext : null,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Configure'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: submitting ? null : onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Back'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: (canSubmit && !submitting) ? onSubmit : null,
                  icon: submitting
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: Text(submitting ? 'Generating…' : 'Generate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SearchField extends StatefulWidget {
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: AppColors.primary.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textTitle,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}