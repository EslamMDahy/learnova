// ─────────────────────────────────────────────────────────────────────────────
//  Topic Management Panel
//  - AI-generated topics from materials
//  - Manual add (instructor adds missing topics)
//  - Difficulty per topic
//  - Link topic to Learning Outcome
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/toast.dart';
import '../../data/topics_models.dart';
import '../../data/learning_outcomes_models.dart';
import '../../data/mock_services.dart';

// ── Colors ────────────────────────────────────────────────────────────────────
class _C {
  static const blue       = Color(0xFF137FEC);
  static const blueSoft   = Color(0xFFEFF6FF);
  static const blueBdr    = Color(0xFFBFDBFE);
  static const purple     = Color(0xFF7C3AED);
  static const purpleSoft = Color(0xFFF5F3FF);
  static const purpleBdr  = Color(0xFFDDD6FE);
  static const green      = Color(0xFF16A34A);
  static const greenSoft  = Color(0xFFF0FDF4);
  static const amber      = Color(0xFFD97706);
  static const amberSoft  = Color(0xFFFFFBEB);
  static const red        = Color(0xFFDC2626);
  static const redSoft    = Color(0xFFFEF2F2);
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _topicsProvider =
    StateProvider.family<List<TopicItem>, int>((ref, moduleId) => []);
final _topicsLoadingProvider =
    StateProvider.family<bool, int>((ref, moduleId) => false);
final _aiGeneratingProvider =
    StateProvider.family<bool, int>((ref, moduleId) => false);

// ─────────────────────────────────────────────────────────────────────────────
//  TopicManagementPanel
// ─────────────────────────────────────────────────────────────────────────────
class TopicManagementPanel extends ConsumerStatefulWidget {
  final int courseId;
  final int moduleId;
  final int materialId;
  final String moduleTitle;
  final List<LearningOutcome> outcomes;

  const TopicManagementPanel({
    super.key,
    required this.courseId,
    required this.moduleId,
    required this.materialId,
    required this.moduleTitle,
    required this.outcomes,
  });

  @override
  ConsumerState<TopicManagementPanel> createState() =>
      _TopicManagementPanelState();
}

class _TopicManagementPanelState extends ConsumerState<TopicManagementPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    ref.read(_topicsLoadingProvider(widget.moduleId).notifier).state = true;
    final svc = ref.read(topicMockServiceProvider);
    final topics = await svc.listTopics(widget.moduleId);
    if (!mounted) return;
    ref.read(_topicsProvider(widget.moduleId).notifier).state = topics;
    ref.read(_topicsLoadingProvider(widget.moduleId).notifier).state = false;
  }

  // ── AI Generation ─────────────────────────────────────────────────────────
  Future<void> _generateWithAi() async {
    final alreadyGenerating =
        ref.read(_aiGeneratingProvider(widget.moduleId));
    if (alreadyGenerating) return;

    ref.read(_aiGeneratingProvider(widget.moduleId).notifier).state = true;

    // Simulate AI extraction from materials
    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) {
      ref.read(_aiGeneratingProvider(widget.moduleId).notifier).state = false;
      return;
    }

    final svc = ref.read(topicMockServiceProvider);
    final existing = ref.read(_topicsProvider(widget.moduleId));

    // Generate AI topics (simulated)
    final aiTopics = [
      const TopicCreateRequest(title: 'Introduction & Overview', source: TopicSource.ai),
      const TopicCreateRequest(title: 'Core Concepts & Terminology', source: TopicSource.ai),
      const TopicCreateRequest(title: 'Practical Applications', source: TopicSource.ai, difficulty: TopicDifficulty.intermediate),
      const TopicCreateRequest(title: 'Advanced Techniques', source: TopicSource.ai, difficulty: TopicDifficulty.advanced),
    ];

    // Only add topics not already present
    final existingTitles = existing.map((t) => t.title.toLowerCase()).toSet();
    final toAdd = aiTopics.where((t) => !existingTitles.contains(t.title.toLowerCase())).toList();

    final created = <TopicItem>[];
    for (final req in toAdd) {
      final t = await svc.createTopic(
        widget.moduleId,
        req,
        materialId: widget.materialId,
      );
      created.add(t);
    }

    if (!mounted) {
      ref.read(_aiGeneratingProvider(widget.moduleId).notifier).state = false;
      return;
    }

    ref.read(_topicsProvider(widget.moduleId).notifier).update(
          (list) => [...list, ...created],
        );
    ref.read(_aiGeneratingProvider(widget.moduleId).notifier).state = false;

    if (mounted) {
      AppToast.success(context,
          title: 'AI Topics Generated',
          message: '${created.length} topics extracted from materials.',);
    }
  }

  // ── Manual add ────────────────────────────────────────────────────────────
  Future<void> _openAddDialog() async {
    final result = await showDialog<TopicCreateRequest>(
      context: context,
      builder: (_) => _TopicEditDialog(
        outcomes: widget.outcomes,
      ),
    );
    if (result == null || !mounted) return;
    final svc = ref.read(topicMockServiceProvider);
    final topic = await svc.createTopic(
      widget.moduleId,
      result,
      materialId: widget.materialId,
    );
    ref.read(_topicsProvider(widget.moduleId).notifier).update(
          (list) => [...list, topic],
        );
    if (mounted) {
      AppToast.success(context,
          title: 'Topic added',
          message: '"${topic.title}" created manually.',);
    }
  }

  // ── Edit ──────────────────────────────────────────────────────────────────
  Future<void> _openEditDialog(TopicItem t) async {
    final result = await showDialog<TopicItem>(
      context: context,
      builder: (_) => _TopicEditDialog(outcomes: widget.outcomes, existing: t),
    );
    if (result == null || !mounted) return;
    final svc = ref.read(topicMockServiceProvider);
    final updated = await svc.updateTopic(widget.moduleId, result);
    ref.read(_topicsProvider(widget.moduleId).notifier).update(
          (list) => list.map((x) => x.id == updated.id ? updated : x).toList(),
        );
    if (mounted) {
      AppToast.success(context,
          title: 'Topic updated', message: '"${updated.title}" saved.',);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> _deleteTopic(TopicItem t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Topic'),
        content: Text('Delete "${t.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Color(0xFFDC2626))),),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final svc = ref.read(topicMockServiceProvider);
    await svc.deleteTopic(widget.moduleId, t.id);
    ref.read(_topicsProvider(widget.moduleId).notifier).update(
          (list) => list.where((x) => x.id != t.id).toList(),
        );
    if (mounted) {
      AppToast.success(context, title: 'Deleted', message: '"${t.title}" removed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final topics   = ref.watch(_topicsProvider(widget.moduleId));
    final loading  = ref.watch(_topicsLoadingProvider(widget.moduleId));
    final aiGen    = ref.watch(_aiGeneratingProvider(widget.moduleId));

    final aiCount     = topics.where((t) => t.source == TopicSource.ai).length;
    final manualCount = topics.where((t) => t.source == TopicSource.manual).length;

    return Container(
      color: AppColors.pageBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ───────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _C.blueSoft, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.topic_outlined, size: 18, color: _C.blue),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.moduleTitle,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textTitle),),
              Text('${topics.length} topic${topics.length == 1 ? "" : "s"}'
                  '${aiCount > 0 ? " · $aiCount AI" : ""}'
                  '${manualCount > 0 ? " · $manualCount Manual" : ""}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),),
            ],),),
            // AI Generate button
            _AiGenerateButton(loading: aiGen, onTap: _generateWithAi),
            const SizedBox(width: 8),
            // Manual Add button
            FilledButton.icon(
              onPressed: _openAddDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Topic'),
              style: FilledButton.styleFrom(
                backgroundColor: _C.purple,
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ],),
        ),

        // ── Legend row ────────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: const Wrap(spacing: 14, runSpacing: 6, children: [
            _BadgeLegend(label: 'AI Generated', bg: _C.blueSoft, fg: _C.blue),
            _BadgeLegend(label: 'Added Manually', bg: _C.purpleSoft, fg: _C.purple),
            _DiffDot(label: 'Beginner', color: _C.green),
            _DiffDot(label: 'Intermediate', color: _C.amber),
            _DiffDot(label: 'Advanced', color: _C.red),
          ],),
        ),
        Container(height: 1, color: AppColors.border),

        // ── Body ─────────────────────────────────────────────────────────────
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : aiGen
                  ? _AiLoadingState()
                  : topics.isEmpty
                      ? _EmptyState(onGenerate: _generateWithAi, onAdd: _openAddDialog)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemCount: topics.length,
                          itemBuilder: (_, i) => _TopicCard(
                            topic: topics[i],
                            outcomes: widget.outcomes,
                            onEdit: () => _openEditDialog(topics[i]),
                            onDelete: () => _deleteTopic(topics[i]),
                          ),
                        ),
        ),
      ],),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AI Generate Button
// ─────────────────────────────────────────────────────────────────────────────
class _AiGenerateButton extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  const _AiGenerateButton({required this.loading, required this.onTap});

  @override
  State<_AiGenerateButton> createState() => _AiGenerateButtonState();
}

class _AiGenerateButtonState extends State<_AiGenerateButton> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.loading ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _h && !widget.loading ? _C.blueSoft : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _h && !widget.loading ? _C.blue : AppColors.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.loading)
              const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: _C.blue),
              )
            else
              const Icon(Icons.auto_awesome_rounded, size: 15, color: _C.blue),
            const SizedBox(width: 7),
            Text(
              widget.loading ? 'Generating…' : 'Generate with AI',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.blue),
            ),
          ],),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Topic Card
// ─────────────────────────────────────────────────────────────────────────────
class _TopicCard extends StatelessWidget {
  final TopicItem topic;
  final List<LearningOutcome> outcomes;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TopicCard({
    required this.topic,
    required this.outcomes,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final lo = outcomes.where((o) => o.id.toString() == topic.linkedOutcomeId).firstOrNull;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        _SourceBadge(source: topic.source),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(topic.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textTitle),),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _DifficultyChip(difficulty: topic.difficulty),
            if (lo != null) _LoChip(code: lo.code, description: lo.title, difficulty: lo.difficulty),
          ],),
        ],),),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 17),
          color: AppColors.textMuted,
          tooltip: 'Edit',
          onPressed: onEdit,
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 17),
          color: const Color(0xFFDC2626),
          tooltip: 'Delete',
          onPressed: onDelete,
          visualDensity: VisualDensity.compact,
        ),
      ],),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Topic Edit / Create Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _TopicEditDialog extends StatefulWidget {
  final List<LearningOutcome> outcomes;
  final TopicItem? existing;
  final TopicSource defaultSource;

  const _TopicEditDialog({
    required this.outcomes,
    this.existing,
    this.defaultSource = TopicSource.manual,
  });

  @override
  State<_TopicEditDialog> createState() => _TopicEditDialogState();
}

class _TopicEditDialogState extends State<_TopicEditDialog> {
  late TextEditingController _titleCtrl;
  late TopicSource _source;
  late TopicDifficulty _difficulty;
  int? _linkedOutcomeId;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _titleCtrl  = TextEditingController(text: ex?.title ?? '');
    _source     = ex?.source ?? widget.defaultSource;
    _difficulty = ex?.difficulty ?? TopicDifficulty.beginner;
    _linkedOutcomeId = ex?.linkedOutcomeId == null ? null : int.tryParse(ex!.linkedOutcomeId!);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Topic name is required.');
      return;
    }
    if (widget.existing != null) {
      Navigator.pop(context, widget.existing!.copyWith(
        title: title, source: _source, difficulty: _difficulty,
        linkedOutcomeId: _linkedOutcomeId?.toString(), updatedAt: DateTime.now(),
      ),);
    } else {
      Navigator.pop(context, TopicCreateRequest(
        title: title, source: _source,
        difficulty: _difficulty, linkedOutcomeId: _linkedOutcomeId?.toString(),
      ),);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isEdit ? _C.purpleSoft : _C.blueSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  isEdit ? Icons.edit_outlined : Icons.add_circle_outline_rounded,
                  size: 18, color: isEdit ? _C.purple : _C.blue,
                ),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isEdit ? 'Edit Topic' : 'Add Topic Manually',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textTitle),),
                Text(isEdit ? 'Update topic details.' : 'Add a topic the AI might have missed.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),),
              ],),
            ],),
            const SizedBox(height: 22),

            // Topic Name
            const _FieldLabel('Topic Name', required: true),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              onChanged: (_) { if (_titleError != null) setState(() => _titleError = null); },
              decoration: InputDecoration(
                hintText: 'e.g. Database Normalization',
                errorText: _titleError,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: const BorderSide(color: _C.blue, width: 1.5),),
                isDense: true,
              ),
            ),
            const SizedBox(height: 18),

            // Source
            const _FieldLabel('Source'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _RadioChip(
                label: 'AI Generated', icon: Icons.auto_awesome,
                selected: _source == TopicSource.ai, selectedColor: _C.blue,
                onTap: () => setState(() => _source = TopicSource.ai),
              ),),
              const SizedBox(width: 10),
              Expanded(child: _RadioChip(
                label: 'Manual', icon: Icons.edit_note_rounded,
                selected: _source == TopicSource.manual, selectedColor: _C.purple,
                onTap: () => setState(() => _source = TopicSource.manual),
              ),),
            ],),
            const SizedBox(height: 18),

            // Difficulty
            const _FieldLabel('Difficulty Level'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _DifficultyBtn(
                label: 'Beginner', color: _C.green,
                selected: _difficulty == TopicDifficulty.beginner,
                onTap: () => setState(() => _difficulty = TopicDifficulty.beginner),
              ),),
              const SizedBox(width: 8),
              Expanded(child: _DifficultyBtn(
                label: 'Intermediate', color: _C.amber,
                selected: _difficulty == TopicDifficulty.intermediate,
                onTap: () => setState(() => _difficulty = TopicDifficulty.intermediate),
              ),),
              const SizedBox(width: 8),
              Expanded(child: _DifficultyBtn(
                label: 'Advanced', color: _C.red,
                selected: _difficulty == TopicDifficulty.advanced,
                onTap: () => setState(() => _difficulty = TopicDifficulty.advanced),
              ),),
            ],),

            // Learning Outcome link
            if (widget.outcomes.isNotEmpty) ...[
              const SizedBox(height: 18),
              const _FieldLabel('Link to Learning Outcome'),
              const SizedBox(height: 4),
              const Text('Connect this topic to a course learning outcome.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                value: _linkedOutcomeId,
                decoration: InputDecoration(
                  hintText: 'Select outcome (optional)',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: const BorderSide(color: _C.blue, width: 1.5),),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<int?>(
                      child: Text('— None —', style: TextStyle(color: AppColors.textMuted)),),
                  ...widget.outcomes.map((o) => DropdownMenuItem<int?>(
                    value: o.id,
                    child: Row(children: [
                      _DiffDotInline(o.difficulty),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${o.code} – ${o.title}',
                          overflow: TextOverflow.ellipsis,),),
                    ],),
                  ),),
                ],
                onChanged: (v) => setState(() => _linkedOutcomeId = v),
              ),
            ],

            const SizedBox(height: 24),

            // Actions
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(backgroundColor: _C.blue),
                child: Text(isEdit ? 'Save Changes' : 'Add Topic'),
              ),
            ],),
          ],),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Empty state (no topics yet)
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onGenerate;
  final VoidCallback onAdd;
  const _EmptyState({required this.onGenerate, required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(color: _C.blueSoft, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.topic_outlined, size: 30, color: _C.blue),
      ),
      const SizedBox(height: 16),
      const Text('No topics yet',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textTitle),),
      const SizedBox(height: 6),
      const Text(
        'Generate topics automatically from materials,\nor add them manually.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
      ),
      const SizedBox(height: 20),
      Row(mainAxisSize: MainAxisSize.min, children: [
        FilledButton.icon(
          onPressed: onGenerate,
          icon: const Icon(Icons.auto_awesome_rounded, size: 16),
          label: const Text('Generate with AI'),
          style: FilledButton.styleFrom(backgroundColor: _C.blue),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Manually'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _C.purple,
            side: const BorderSide(color: _C.purple),
          ),
        ),
      ],),
    ],),
  );
}

// ── AI loading state ──────────────────────────────────────────────────────────
class _AiLoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(color: _C.blueSoft, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.auto_awesome_rounded, size: 30, color: _C.blue),
      ),
      const SizedBox(height: 16),
      const Text('AI is analyzing materials…',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textTitle),),
      const SizedBox(height: 8),
      const Text('Extracting topics from course materials.',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),),
      const SizedBox(height: 20),
      const SizedBox(
        width: 180,
        child: LinearProgressIndicator(
          backgroundColor: Color(0xFFDBEAFE),
          color: _C.blue,
          minHeight: 4,
        ),
      ),
    ],),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SourceBadge extends StatelessWidget {
  final TopicSource source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final isAi = source == TopicSource.ai;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAi ? _C.blueSoft : _C.purpleSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isAi ? _C.blueBdr : _C.purpleBdr),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isAi ? Icons.auto_awesome : Icons.edit_note_rounded,
            size: 12, color: isAi ? _C.blue : _C.purple,),
        const SizedBox(width: 4),
        Text(isAi ? 'AI' : 'Manual',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: isAi ? _C.blue : _C.purple,),),
      ],),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final TopicDifficulty difficulty;
  const _DifficultyChip({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    late Color color, bg;
    switch (difficulty) {
      case TopicDifficulty.beginner:     color = _C.green; bg = _C.greenSoft; break;
      case TopicDifficulty.intermediate: color = _C.amber; bg = _C.amberSoft; break;
      case TopicDifficulty.advanced:     color = _C.red;   bg = _C.redSoft;   break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(difficulty.label,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),),
    );
  }
}

class _LoChip extends StatelessWidget {
  final String code, description;
  final OutcomeDifficulty difficulty;
  const _LoChip({required this.code, required this.description, required this.difficulty});

  @override
  Widget build(BuildContext context) {
    // Color matches LO difficulty
    Color dotColor;
    switch (difficulty) {
      case OutcomeDifficulty.beginner:     dotColor = _C.green; break;
      case OutcomeDifficulty.intermediate: dotColor = _C.amber; break;
      case OutcomeDifficulty.advanced:     dotColor = _C.red;   break;
    }
    return Tooltip(
      message: description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(code, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF0369A1))),
        ],),
      ),
    );
  }
}

class _DiffDotInline extends StatelessWidget {
  final OutcomeDifficulty difficulty;
  const _DiffDotInline(this.difficulty);

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (difficulty) {
      case OutcomeDifficulty.beginner:     c = _C.green; break;
      case OutcomeDifficulty.intermediate: c = _C.amber; break;
      case OutcomeDifficulty.advanced:     c = _C.red;   break;
    }
    return Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
  }
}

class _BadgeLegend extends StatelessWidget {
  final String label; final Color bg, fg;
  const _BadgeLegend({required this.label, required this.bg, required this.fg});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
  ],);
}

class _DiffDot extends StatelessWidget {
  final String label; final Color color;
  const _DiffDot({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
  ],);
}

class _FieldLabel extends StatelessWidget {
  final String text; final bool required;
  const _FieldLabel(this.text, {this.required = false});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
    if (required) const Text(' *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
  ],);
}

class _RadioChip extends StatelessWidget {
  final String label; final IconData icon; final bool selected;
  final Color selectedColor; final VoidCallback onTap;
  const _RadioChip({required this.label, required this.icon, required this.selected,
      required this.selectedColor, required this.onTap,});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? selectedColor.withOpacity(0.08) : AppColors.pageBg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: selected ? selectedColor : AppColors.border, width: selected ? 1.5 : 1),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 15, color: selected ? selectedColor : AppColors.textMuted),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600,
            color: selected ? selectedColor : AppColors.textMuted,),),
      ],),
    ),
  );
}

class _DifficultyBtn extends StatelessWidget {
  final String label; final Color color; final bool selected; final VoidCallback onTap;
  const _DifficultyBtn({required this.label, required this.color, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : AppColors.border, width: selected ? 1.5 : 1),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: selected ? color : AppColors.textMuted,),),
      ),
    ),
  );
}
