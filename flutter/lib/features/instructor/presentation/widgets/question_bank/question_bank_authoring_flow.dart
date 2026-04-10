import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../data/courses_models.dart';
import '../../../data/materials_models.dart';
import '../../../data/modules_models.dart';
import '../../../data/topics_models.dart';
import '../../controllers/course_details_controller.dart';
import '../../controllers/course_details_state.dart';
import 'question_bank_question_editor_dialog.dart';

class QuestionBankAuthoringFlow extends ConsumerStatefulWidget {
  final MyCourseItem course;
  final VoidCallback? onQuestionsSaved;

  const QuestionBankAuthoringFlow({
    super.key,
    required this.course,
    this.onQuestionsSaved,
  });

  @override
  ConsumerState<QuestionBankAuthoringFlow> createState() =>
      _QuestionBankAuthoringFlowState();
}

class _QuestionBankAuthoringFlowState
    extends ConsumerState<QuestionBankAuthoringFlow> {
  final Set<int> _selectedModuleIds = <int>{};
  final Set<int> _selectedMaterialIds = <int>{};
  final Set<int> _selectedTopicIds = <int>{};
  String _search = '';
  bool _bootstrapping = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    setState(() => _bootstrapping = true);
    await ref
        .read(courseDetailsControllerProvider(widget.course.id).notifier)
        .loadModulesAndAllMaterials();
    if (!mounted) return;
    setState(() => _bootstrapping = false);
  }

  @override
  Widget build(BuildContext context) {
    final courseState = ref.watch(courseDetailsControllerProvider(widget.course.id));
    final moduleEntries = _buildEntries(courseState);
    final targets = _resolveTargets(moduleEntries);

    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textTitle,
          titleSpacing: 20,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Question Bank Authoring',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                widget.course.title,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Close'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Row(
          children: [
            Expanded(
              flex: 6,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _AuthoringHero(
                    selectedModules: _selectedModuleIds.length,
                    selectedMaterials: _selectedMaterialIds.length,
                    selectedTopics: targets.length,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
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
                                    'Select source content',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textTitle,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Choose modules, materials, and/or specific topics. Broad selections expand to eligible topics automatically.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 280,
                              child: TextField(
                                onChanged: (value) => setState(() => _search = value),
                                decoration: InputDecoration(
                                  hintText: 'Search modules, materials, or topics...',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (_bootstrapping || courseState.modulesLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (moduleEntries.isEmpty)
                          const _TreeEmptyState()
                        else
                          ...moduleEntries.map((entry) {
                            if (!_matchesSearch(entry)) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _ModuleSelectionCard(
                                entry: entry,
                                selectedModuleIds: _selectedModuleIds,
                                selectedMaterialIds: _selectedMaterialIds,
                                selectedTopicIds: _selectedTopicIds,
                                onToggleModule: () => _toggleModule(entry),
                                onToggleMaterial: (material) => _toggleMaterial(entry, material),
                                onToggleTopic: (topic) => _toggleTopic(topic),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 1, color: AppColors.border),
            Expanded(
              flex: 4,
              child: Container(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resolved topic scope',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textTitle,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'The question editor will only save questions against these exact topics.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _SummaryPill(label: 'Modules', value: '${_selectedModuleIds.length}'),
                          _SummaryPill(label: 'Materials', value: '${_selectedMaterialIds.length}'),
                          _SummaryPill(label: 'Eligible topics', value: '${targets.length}'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: targets.isEmpty
                            ? const _ScopeEmptyState()
                            : ListView.separated(
                                itemCount: targets.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final target = targets[index];
                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          target.topic.title,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textTitle,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          target.material.displayTitle,
                                          style: const TextStyle(fontSize: 11.5, color: AppColors.textTitle),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          target.module.title,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: targets.isEmpty
                              ? null
                              : () async {
                                  final savedCount = await showDialog<int>(
                                    context: context,
                                    builder: (_) => QuestionBankQuestionEditorDialog(
                                      courseId: widget.course.id,
                                      topicTargets: targets,
                                    ),
                                  );
                                  if (savedCount != null && savedCount > 0) {
                                    widget.onQuestionsSaved?.call();
                                  }
                                },
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Start question authoring'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedModuleIds.clear();
                            _selectedMaterialIds.clear();
                            _selectedTopicIds.clear();
                          });
                        },
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: const Text('Clear selection'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ModuleEntry> _buildEntries(CourseDetailsState state) {
    return state.modules.map((module) {
      final materials = state.materials[module.id] ?? const <MaterialItem>[];
      final topics = state.topics[module.id] ?? const <TopicItem>[];
      final materialEntries = materials.map((material) {
        final materialTopics = topics.where((topic) => topic.materialId == material.id).toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        return _MaterialEntry(material: material, topics: materialTopics);
      }).toList();
      return _ModuleEntry(module: module, materials: materialEntries);
    }).toList()
      ..sort((a, b) => a.module.orderIndex.compareTo(b.module.orderIndex));
  }

  bool _matchesSearch(_ModuleEntry entry) {
    final term = _search.trim().toLowerCase();
    if (term.isEmpty) return true;
    if (entry.module.title.toLowerCase().contains(term)) return true;
    for (final material in entry.materials) {
      if (material.material.displayTitle.toLowerCase().contains(term)) return true;
      for (final topic in material.topics) {
        if (topic.title.toLowerCase().contains(term)) return true;
      }
    }
    return false;
  }

  void _toggleModule(_ModuleEntry entry) {
    final isSelecting = !_selectedModuleIds.contains(entry.module.id);
    setState(() {
      if (isSelecting) {
        _selectedModuleIds.add(entry.module.id);
        for (final material in entry.materials) {
          _selectedMaterialIds.add(material.material.id);
          for (final topic in material.topics) {
            _selectedTopicIds.add(topic.id);
          }
        }
      } else {
        _selectedModuleIds.remove(entry.module.id);
        for (final material in entry.materials) {
          _selectedMaterialIds.remove(material.material.id);
          for (final topic in material.topics) {
            _selectedTopicIds.remove(topic.id);
          }
        }
      }
    });
  }

  void _toggleMaterial(_ModuleEntry entry, _MaterialEntry materialEntry) {
    final isSelecting = !_selectedMaterialIds.contains(materialEntry.material.id);
    setState(() {
      if (isSelecting) {
        _selectedMaterialIds.add(materialEntry.material.id);
        for (final topic in materialEntry.topics) {
          _selectedTopicIds.add(topic.id);
        }
      } else {
        _selectedMaterialIds.remove(materialEntry.material.id);
        for (final topic in materialEntry.topics) {
          _selectedTopicIds.remove(topic.id);
        }
      }

      final allMaterialsSelected = entry.materials.every(
        (m) => _selectedMaterialIds.contains(m.material.id),
      );
      if (allMaterialsSelected && entry.materials.isNotEmpty) {
        _selectedModuleIds.add(entry.module.id);
      } else {
        _selectedModuleIds.remove(entry.module.id);
      }
    });
  }

  void _toggleTopic(TopicItem topic) {
    setState(() {
      if (_selectedTopicIds.contains(topic.id)) {
        _selectedTopicIds.remove(topic.id);
      } else {
        _selectedTopicIds.add(topic.id);
      }
    });
  }

  List<QuestionAuthoringTopicTarget> _resolveTargets(List<_ModuleEntry> entries) {
    final targets = <QuestionAuthoringTopicTarget>[];
    final seen = <int>{};

    for (final moduleEntry in entries) {
      final moduleSelected = _selectedModuleIds.contains(moduleEntry.module.id);
      for (final materialEntry in moduleEntry.materials) {
        final materialSelected = _selectedMaterialIds.contains(materialEntry.material.id);
        for (final topic in materialEntry.topics) {
          final topicSelected = _selectedTopicIds.contains(topic.id);
          if (moduleSelected || materialSelected || topicSelected) {
            if (seen.add(topic.id)) {
              targets.add(
                QuestionAuthoringTopicTarget(
                  module: moduleEntry.module,
                  material: materialEntry.material,
                  topic: topic,
                ),
              );
            }
          }
        }
      }
    }

    targets.sort((a, b) {
      final moduleCompare = a.module.orderIndex.compareTo(b.module.orderIndex);
      if (moduleCompare != 0) return moduleCompare;
      final materialCompare = a.material.displayTitle.compareTo(b.material.displayTitle);
      if (materialCompare != 0) return materialCompare;
      return a.topic.orderIndex.compareTo(b.topic.orderIndex);
    });

    return targets;
  }
}

class _AuthoringHero extends StatelessWidget {
  final int selectedModules;
  final int selectedMaterials;
  final int selectedTopics;

  const _AuthoringHero({
    required this.selectedModules,
    required this.selectedMaterials,
    required this.selectedTopics,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F4CBA), Color(0xFF2D8CFF)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Build reusable Question Bank content',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Select course structure items first, then move straight into question authoring. No exam setup, no extra assessment metadata.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroMetric(label: 'Modules', value: '$selectedModules'),
              const SizedBox(height: 10),
              _HeroMetric(label: 'Materials', value: '$selectedMaterials'),
              const SizedBox(height: 10),
              _HeroMetric(label: 'Resolved topics', value: '$selectedTopics'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }
}

class _ModuleSelectionCard extends StatefulWidget {
  final _ModuleEntry entry;
  final Set<int> selectedModuleIds;
  final Set<int> selectedMaterialIds;
  final Set<int> selectedTopicIds;
  final VoidCallback onToggleModule;
  final ValueChanged<_MaterialEntry> onToggleMaterial;
  final ValueChanged<TopicItem> onToggleTopic;

  const _ModuleSelectionCard({
    required this.entry,
    required this.selectedModuleIds,
    required this.selectedMaterialIds,
    required this.selectedTopicIds,
    required this.onToggleModule,
    required this.onToggleMaterial,
    required this.onToggleTopic,
  });

  @override
  State<_ModuleSelectionCard> createState() => _ModuleSelectionCardState();
}

class _ModuleSelectionCardState extends State<_ModuleSelectionCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final module = widget.entry.module;
    final moduleSelected = widget.selectedModuleIds.contains(module.id);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Checkbox(value: moduleSelected, onChanged: (_) => widget.onToggleModule()),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(module.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        if ((module.description ?? '').trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              module.description!,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${widget.entry.materials.length} material${widget.entry.materials.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: widget.entry.materials.map((materialEntry) {
                  final materialSelected = widget.selectedMaterialIds.contains(materialEntry.material.id);
                  return Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: materialSelected,
                              onChanged: (_) => widget.onToggleMaterial(materialEntry),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    materialEntry.material.displayTitle,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${materialEntry.topics.length} topic${materialEntry.topics.length == 1 ? '' : 's'} · ${materialEntry.material.type}',
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (materialEntry.topics.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 42, top: 8),
                            child: Column(
                              children: materialEntry.topics.map((topic) {
                                final topicSelected = widget.selectedTopicIds.contains(topic.id);
                                return CheckboxListTile(
                                  value: topicSelected,
                                  onChanged: (_) => widget.onToggleTopic(topic),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  title: Text(
                                    topic.title,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: topic.description == null || topic.description!.trim().isEmpty
                                      ? null
                                      : Text(
                                          topic.description!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TreeEmptyState extends StatelessWidget {
  const _TreeEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'No modules or materials are available yet for this course.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _ScopeEmptyState extends StatelessWidget {
  const _ScopeEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined, size: 32, color: AppColors.primary),
            SizedBox(height: 12),
            Text(
              'Select at least one module, material, or topic',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              'Your selection will be converted into exact topic targets so each saved question has one precise topic owner.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleEntry {
  final ModuleItem module;
  final List<_MaterialEntry> materials;

  const _ModuleEntry({required this.module, required this.materials});
}

class _MaterialEntry {
  final MaterialItem material;
  final List<TopicItem> topics;

  const _MaterialEntry({required this.material, required this.topics});
}
