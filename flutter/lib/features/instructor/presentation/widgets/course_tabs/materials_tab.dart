import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/storage/key_value_store_factory.dart';
import '../../../../../core/ui/toast.dart';
import '../../../../../shared/widgets/app_ui_components.dart';
import '../../../data/courses_models.dart';
import '../../../data/courses_providers.dart';
import '../../../data/modules_models.dart';
import '../../../data/materials_models.dart';
import '../../../data/topics_models.dart';
import '../../../data/learning_outcomes_models.dart';
import '../../controllers/course_details_controller.dart';
import '../../controllers/course_details_state.dart';
import '../add_question_sheet.dart';
import '../course_outcomes_panel.dart';
import '../upload_material_sheet.dart';
import '../generate_questions_dialog.dart';
import '../module_selector_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Color palette
// ─────────────────────────────────────────────────────────────────────────────
class _K {
  _K._();
  static const purple     = Color(0xFF7C3AED);
  static const purpleSoft = Color(0xFFF5F3FF);
  static const purpleBd   = Color(0xFFDDD6FE);
  static const amber      = Color(0xFFD97706);
  static const amberSoft  = Color(0xFFFFFBEB);
  static const green      = Color(0xFF16A34A);
  static const greenSoft  = Color(0xFFF0FDF4);
  static const redSoft    = Color(0xFFFFF1F2);
  static const blue       = Color(0xFF2563EB);
  static const blueSoft   = Color(0xFFEFF6FF);
  static const blueMid    = Color(0xFFDBEAFE);
  static const div        = Color(0xFFEEEEEE);
  static const bg         = Color(0xFFF6F7F9);
  static const sidebar    = Color(0xFFFAFAFA);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Context types
// ─────────────────────────────────────────────────────────────────────────────
enum _CType { module, material, topic }

class _Ctx {
  final _CType       type;
  final ModuleItem?  module;
  final MaterialItem? material;
  final TopicItem?   topic;
  const _Ctx._({required this.type, this.module, this.material, this.topic});
  factory _Ctx.module(ModuleItem m)                     => _Ctx._(type: _CType.module, module: m);
  factory _Ctx.material(ModuleItem m, MaterialItem mat) => _Ctx._(type: _CType.material, module: m, material: mat);
  factory _Ctx.topic(ModuleItem m, MaterialItem mat, TopicItem t) =>
      _Ctx._(type: _CType.topic, module: m, material: mat, topic: t);
}

// ─────────────────────────────────────────────────────────────────────────────
//  CourseMaterialsTab
// ─────────────────────────────────────────────────────────────────────────────
class CourseMaterialsTab extends ConsumerStatefulWidget {
  final MyCourseItem course;
  const CourseMaterialsTab({super.key, required this.course});
  @override
  ConsumerState<CourseMaterialsTab> createState() => _CourseMaterialsTabState();
}

class _CourseMaterialsTabState extends ConsumerState<CourseMaterialsTab>
    with AutomaticKeepAliveClientMixin {
  final Set<int>    _expanded = {};
  _Ctx?             _sel;
  final List<_Ctx>  _stack   = [];
  final ScrollController _scroll = ScrollController();
  late final _session = createSessionStore();
  bool _restored = false;
  bool _dialogOpen = false;
  int? _draggingModuleId;

  @override
  bool get wantKeepAlive => true;

  String get _uiStateKey => 'course:${widget.course.id}:materials_ui';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_persistUiState);
  }

  @override
  void dispose() { _persistUiState(); _scroll.dispose(); super.dispose(); }

  _Ctx? get _active => _stack.isNotEmpty ? _stack.last : _sel;

  Future<T?> _showManagedDialog<T>({
    required WidgetBuilder builder,
    Color? barrierColor,
    bool barrierDismissible = true,
  }) async {
    if (mounted) setState(() => _dialogOpen = true);
    try {
      return await showDialog<T>(
        context: context,
        barrierColor: barrierColor,
        barrierDismissible: barrierDismissible,
        builder: builder,
      );
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }


  void _persistUiState() {
    final sel = _sel;
    final active = _active;
    final payload = <String, dynamic>{
      'expanded': _expanded.toList(),
      'scrollOffset': _scroll.hasClients ? _scroll.offset : 0.0,
      'selectedType': sel?.type.name,
      'selectedModuleId': sel?.module?.id,
      'selectedMaterialId': sel?.material?.id,
      'selectedTopicId': sel?.topic?.id,
      'activeTopicId': active?.type == _CType.topic ? active?.topic?.id : null,
    };
    _session.setString(_uiStateKey, jsonEncode(payload));
  }

  void _maybeRestoreUiState(CourseDetailsState st) {
    if (_restored) return;
    final raw = _session.getString(_uiStateKey);
    if (raw == null || raw.isEmpty) {
      _restored = true;
      return;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final expanded = ((map['expanded'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toSet();
      final selectedType = map['selectedType']?.toString();
      final selectedModuleId = (map['selectedModuleId'] as num?)?.toInt();
      final selectedMaterialId = (map['selectedMaterialId'] as num?)?.toInt();
      final selectedTopicId = (map['selectedTopicId'] as num?)?.toInt();
      final activeTopicId = (map['activeTopicId'] as num?)?.toInt();
      final storedOffset = (map['scrollOffset'] as num?)?.toDouble() ?? 0.0;

      ModuleItem? findModule(int? id) {
        if (id == null) return null;
        for (final m in st.modules) {
          if (m.id == id) return m;
        }
        return null;
      }

      MaterialItem? findMaterial(int moduleId, int? materialId) {
        if (materialId == null) return null;
        final materials = st.materials[moduleId] ?? const <MaterialItem>[];
        for (final mat in materials) {
          if (mat.id == materialId) return mat;
        }
        return null;
      }

      TopicItem? findTopic(int moduleId, int materialId, int? topicId) {
        if (topicId == null) return null;
        final topics = st.topics[moduleId] ?? const <TopicItem>[];
        for (final t in topics) {
          if (t.id == topicId && t.materialId == materialId) return t;
        }
        return null;
      }

      final module = findModule(selectedModuleId);
      if (selectedModuleId != null && module == null && st.modules.isNotEmpty) {
        return;
      }

      _expanded
        ..clear()
        ..addAll(expanded.where((id) => st.modules.any((m) => m.id == id)));

      if (module != null && !st.materials.containsKey(module.id)) {
        ref.read(courseDetailsControllerProvider(widget.course.id).notifier).loadMaterials(module.id);
        return;
      }

      if (module != null && selectedMaterialId != null && ((st.topics[module.id] == null) || (st.topics[module.id]!.isEmpty && selectedTopicId != null))) {
        ref.read(courseDetailsControllerProvider(widget.course.id).notifier).loadTopics(module.id);
      }

      _sel = null;
      _stack.clear();

      if (module != null) {
        if (selectedType == _CType.module.name) {
          _sel = _Ctx.module(module);
        } else {
          final material = findMaterial(module.id, selectedMaterialId);
          if (material != null) {
            if (selectedType == _CType.material.name) {
              _sel = _Ctx.material(module, material);
            } else {
              final topic = findTopic(module.id, material.id, selectedTopicId);
              _sel = _Ctx.material(module, material);
              if (topic != null) {
                _stack.add(_Ctx.topic(module, material, topic));
                if (activeTopicId != null && activeTopicId != selectedTopicId) {
                  final activeTopic = findTopic(module.id, material.id, activeTopicId);
                  if (activeTopic != null) {
                    _stack
                      ..clear()
                      ..add(_Ctx.topic(module, material, activeTopic));
                  }
                }
              }
              ref.read(courseDetailsControllerProvider(widget.course.id).notifier).fetchDownloadUrl(moduleId: module.id, materialId: material.id);
            }
          }
        }
      }

      _restored = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        final max = _scroll.position.maxScrollExtent;
        final target = storedOffset.clamp(0.0, max);
        _scroll.jumpTo(target);
      });
      if (mounted) setState(() {});
    } catch (_) {
      _restored = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final st = ref.watch(courseDetailsControllerProvider(widget.course.id));
    _maybeRestoreUiState(st);
    final active = _active ?? _sel;
    return Column(children: [
      Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SidebarWidget(
            state: st,
            expanded: _expanded,
            active: _active,
            scroll: _scroll,
            draggingModuleId: _draggingModuleId,
            onModuleTap: (m) => _tapModule(m, st),
            onMaterialTap: _tapMaterial,
            onTopicTap: _tapTopic,
            onAddMaterial: _showUploadSheet,
            onAddModule: _showCreateModuleDialog,
            onModuleReorder: _handleModuleReorder,
            onDragChanged: (moduleId) {
              if (!mounted) return;
              setState(() => _draggingModuleId = moduleId);
            },
            onRefresh: () => ref
                .read(courseDetailsControllerProvider(widget.course.id).notifier)
                .loadModulesAndAllMaterials(force: true),
          ),
          Expanded(child: _buildPanel(st)),
        ]),
      ),
      if (_sel != null && active != null)
        _FooterWidget(
          ctx: active,
          uploading: st.uploading,
          canGenerate: _canGenerate(active, st),
          onUpload: () { final m = _sel?.module; if (m != null) _showUploadSheet(m); },
          onGenerate: () => _openGenerateDialog(
            moduleId: active.module?.id,
            materialId: active.material?.id,
            topicId: active.topic?.id,
          ),
          onClose: () => setState(() { _sel = null; _stack.clear(); _persistUiState(); }),
        ),
    ]);
  }

  bool _canGenerate(_Ctx ctx, CourseDetailsState st) {
    switch (ctx.type) {
      case _CType.module:
        final mats = st.materials[ctx.module!.id] ?? const <MaterialItem>[];
        return mats.isNotEmpty;
      case _CType.material:
        return ctx.material != null;
      case _CType.topic:
        return ctx.material != null && ctx.topic != null;
    }
  }

  // ── Tap handlers ────────────────────────────────────────────────────────
  void _tapModule(ModuleItem m, CourseDetailsState st) {
    setState(() {
      final alreadySel = _active?.type == _CType.module && _active?.module?.id == m.id;
      if (_expanded.contains(m.id) && alreadySel) {
        _expanded.remove(m.id); _sel = null; _stack.clear();
        _persistUiState();
      } else {
        _expanded.add(m.id); _sel = _Ctx.module(m); _stack.clear();
        if (!st.materials.containsKey(m.id)) {
          ref.read(courseDetailsControllerProvider(widget.course.id).notifier).loadMaterials(m.id);
        }
        _persistUiState();
      }
    });
  }

  void _tapMaterial(ModuleItem m, MaterialItem mat) {
    setState(() { _sel = _Ctx.material(m, mat); _stack.clear(); });
    _persistUiState();
    final notifier = ref.read(courseDetailsControllerProvider(widget.course.id).notifier);
    notifier.loadTopics(m.id);
    notifier.fetchDownloadUrl(moduleId: m.id, materialId: mat.id);
  }

  void _tapTopic(ModuleItem m, MaterialItem mat, TopicItem t) {
    setState(() { _sel = _Ctx.material(m, mat); _stack..clear()..add(_Ctx.topic(m, mat, t)); });
    _persistUiState();
  }

  Future<void> _handleModuleReorder(int oldIndex, int newIndex) async {
    final orderedModules = [...ref.read(courseDetailsControllerProvider(widget.course.id)).modules]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    if (orderedModules.length < 2) return;

    var targetIndex = newIndex;
    if (targetIndex > oldIndex) targetIndex -= 1;
    if (targetIndex < 0 || targetIndex >= orderedModules.length) return;

    final movedModule = orderedModules[oldIndex];
    final movedTitle = movedModule.title;
    final success = await ref
        .read(courseDetailsControllerProvider(widget.course.id).notifier)
        .reorderModule(moduleId: movedModule.id, newPosition: targetIndex);

    if (!mounted) return;
    setState(() => _draggingModuleId = null);
    if (success) {
      AppToast.success(
        context,
        title: 'Module reordered',
        message: '"$movedTitle" moved to position ${targetIndex + 1}.',
      );
      _persistUiState();
    } else {
      AppToast.error(
        context,
        title: 'Reorder failed',
        message: 'Could not update the module order. Please try again.',
      );
    }
  }

  void _drillTopic(TopicItem t) {
    final c = _sel; if (c?.module == null || c?.material == null) return;
    setState(() { _stack.add(_Ctx.topic(c!.module!, c.material!, t)); });
    _persistUiState();
  }

  void _pop() => setState(() { if (_stack.isNotEmpty) _stack.removeLast(); _persistUiState(); });

  // ── Right panel routing ──────────────────────────────────────────────────
  Widget _buildPanel(CourseDetailsState st) {
    final c = _active;
    if (c == null) return _EmptyStateWidget(onCreate: _showCreateModuleDialog);

    if (c.type == _CType.module) {
      return _ModulePanelWidget(
        module: c.module!, materials: st.materials[c.module!.id] ?? [],
        uploading: st.uploading, uploadProgress: st.uploadProgress,
        onUpload: () => _showUploadSheet(c.module!),
        onMaterialTap: (mat) => _tapMaterial(c.module!, mat),
        onRename: () => _showRenameDialog(c.module!),
        onEditDescription: () => _showEditDescriptionDialog(c.module!),
        onTogglePublish: () => _togglePublish(c.module!),
        onChangePosition: () => _showChangePositionDialog(c.module!),
        onDelete: () => _confirmDelete(c.module!),
        onShare: () => _showShareModuleDialog(c.module!),
      );
    }

    if (c.type == _CType.material) {
      final mid = c.module!.id;
      final matId = c.material!.id;
      final materialTopics = (st.topics[mid] ?? const <TopicItem>[])
          .where((t) => t.materialId == matId)
          .toList();
      final outcomes = ref.watch(courseLOProvider(widget.course.id));
      return _MaterialPanelWidget(
        module: c.module!, material: c.material!,
        topics: materialTopics, topicsLoading: st.topicsLoading[mid] ?? false,
        outcomes: outcomes,
        downloadUrl: st.downloadUrls[matId] ?? c.material!.downloadUrl,
        urlLoading: st.downloadUrlLoading[matId] ?? false,
        onTopicTap: _drillTopic,
        onAddTopicManual: () => _showAddTopicDialog(c.module!, c.material!),
        onGenerateTopicsAI: () => _openGenerateDialog(moduleId: mid, materialId: matId),
        onRefreshUrl: () => ref.read(courseDetailsControllerProvider(widget.course.id).notifier)
            .fetchDownloadUrl(moduleId: mid, materialId: matId, force: true),
        previewInteractive: !_dialogOpen,
      );
    }

    final outcomes = ref.watch(courseLOProvider(widget.course.id));
    final mid = c.module!.id;
    final matId = c.material!.id;
    final materialTopics = (st.topics[mid] ?? const <TopicItem>[])
        .where((t) => t.materialId == matId)
        .toList();
    return _TopicPanelWidget(
      module: c.module!,
      material: c.material!,
      topic: c.topic!,
      allMaterialTopics: materialTopics,
      outcomes: outcomes,
      canPop: _stack.isNotEmpty,
      onBack: _pop,
      onGenerate: () => _openGenerateDialog(
        moduleId: c.module!.id,
        materialId: c.material!.id,
        topicId: c.topic!.id,
      ),
      onAddManualQuestion: () => _showAddQuestionSheet(c.module!, c.material!, c.topic!),
      onEditTopic: () => _showEditTopicDialog(c.module!, c.material!, c.topic!),
      onOpenSubtopic: (TopicItem subtopic) {
        _drillTopic(subtopic);
      },
      onAddSubtopic: () => _showAddSubtopicDialog(c.module!, c.material!, c.topic!),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────
Future<void> _showAddSubtopicDialog(
  ModuleItem m,
  MaterialItem mat,
  TopicItem parent,
) async {
  final outcomes = ref.read(courseLOProvider(widget.course.id));

  final result = await _showManagedDialog<_TopicDialogResult>(
    barrierColor: Colors.black.withOpacity(0.42),
    builder: (_) => _AddTopicDialogV2(outcomes: outcomes),
  );

  if (result == null || !mounted) return;

  final title = result.title.trim();
  if (title.isEmpty) return;

  final notifier =
      ref.read(courseDetailsControllerProvider(widget.course.id).notifier);

  final topic = await notifier.createTopic(
    moduleId: m.id,
    materialId: mat.id,
    payload: TopicCreateRequest(
      title: title,
      parentTopicId: parent.id,
      learningOutcomeIds: result.learningOutcomeIds,
    ),
  );

  if (!mounted) return;

  if (topic != null) {
    AppToast.success(context,
        title: 'Subtopic added', message: '"${topic.title}" created.');
  }
}

Future<void> _showCreateModuleDialog() async {
  final currentModules =
      ref.read(courseDetailsControllerProvider(widget.course.id)).modules;

  if (mounted) setState(() => _dialogOpen = true);

  final result = await showModuleSelectorSheet(
    context,
    widget.course.id,
    currentModules: currentModules,
  );

  if (mounted) setState(() => _dialogOpen = false);

  if (result == null || !mounted) return;

  final notifier =
      ref.read(courseDetailsControllerProvider(widget.course.id).notifier);

  if (result.isNew) {
    final m = await notifier.createModule(
      result.newTitle!,
      description: result.newDescription,
    );

    if (m != null && mounted) {
      AppToast.success(context,
          title: 'Module created', message: '"${m.title}" added.');
    }
  }
}

  Future<void> _showUploadSheet(ModuleItem module) async {
    final results = await _showManagedDialog<List<UploadSheetResult>>(
        barrierColor: Colors.black.withOpacity(0.35),
        builder: (_) => UploadMaterialSheet(moduleTitle: module.title));
    if (results == null || results.isEmpty || !mounted) return;
    int ok = 0;
    for (final r in results) {
      if (!mounted) break;
      final success = await ref.read(courseDetailsControllerProvider(widget.course.id).notifier)
          .uploadMaterial(moduleId: module.id, bytes: r.bytes,
              filename: r.filename, contentType: r.contentType, title: r.title);
      if (success) ok++;
    }
    if (mounted && ok > 0) {
      AppToast.success(context, title: 'Uploaded',
          message: ok == 1 ? '"${results.first.title}" is ready.' : '$ok files uploaded.');
    }
  }

  Future<void> _showShareModuleDialog(ModuleItem m) async {
    final targetCourse = await _showManagedDialog<MyCourseItem>(
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => _ShareModuleDialog(module: m, currentCourseId: widget.course.id),
    );
    if (targetCourse == null || !mounted) return;

    final copied = await ref
        .read(courseDetailsControllerProvider(widget.course.id).notifier)
        .copyModule(
          sourceCourseId: widget.course.id,
          moduleId: m.id,
          targetCourseId: targetCourse.id,
        );

    if (!mounted) return;
    if (copied != null) {
      AppToast.success(
        context,
        title: 'Module copied',
        message: '"${m.title}" has been copied to "${targetCourse.safeTitle}".',
      );
    } else {
      AppToast.error(context,
          title: 'Copy failed',
          message: 'Could not copy module. Please try again.');
    }
  }

  Future<void> _showRenameDialog(ModuleItem m) async {
    final c = TextEditingController(text: m.title);
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => _SimpleDialog(
        title: 'Rename Module',
        ctrl: c,
        confirm: 'Save',
        confirmColor: AppColors.primary,
      ),
    );
    final title = c.text.trim();
    if (ok != true || !mounted || title.isEmpty || title == m.title) return;

    final updated = await ref.read(courseDetailsControllerProvider(widget.course.id).notifier)
        .updateModule(moduleId: m.id, title: title);
    if (!mounted) return;

    if (updated != null) {
      setState(() {
        if (_active?.type == _CType.module && _active?.module?.id == updated.id) {
          _sel = _Ctx.module(updated);
        }
      });
      AppToast.success(context, title: 'Module renamed', message: 'The module name was updated.');
    } else {
      AppToast.error(context, title: 'Rename failed', message: 'Please try again.');
    }
  }

  Future<void> _showEditDescriptionDialog(ModuleItem m) async {
    final c = TextEditingController(text: m.description ?? '');
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => _DescriptionDialog(ctrl: c),
    );
    final description = c.text.trim();
    final normalizedExisting = (m.description ?? '').trim();
    if (ok != true || !mounted || description == normalizedExisting) return;

    final updated = await ref.read(courseDetailsControllerProvider(widget.course.id).notifier)
        .updateModule(moduleId: m.id, description: description);
    if (!mounted) return;

    if (updated != null) {
      setState(() {
        if (_active?.type == _CType.module && _active?.module?.id == updated.id) {
          _sel = _Ctx.module(updated);
        }
      });
      AppToast.success(context, title: 'Description updated', message: 'Module description saved successfully.');
    } else {
      AppToast.error(context, title: 'Update failed', message: 'Please try again.');
    }
  }

  Future<void> _togglePublish(ModuleItem m) async {
    final updated = await ref.read(courseDetailsControllerProvider(widget.course.id).notifier)
        .updateModule(moduleId: m.id, isPublished: !m.isPublished);
    if (!mounted) return;

    if (updated != null) {
      setState(() {
        if (_active?.type == _CType.module && _active?.module?.id == updated.id) {
          _sel = _Ctx.module(updated);
        }
      });
      AppToast.success(
        context,
        title: updated.isPublished ? 'Module published' : 'Module unpublished',
        message: updated.isPublished ? 'The module is now visible to students.' : 'The module is now hidden from students.',
      );
    } else {
      AppToast.error(context, title: 'Update failed', message: 'Please try again.');
    }
  }

  Future<void> _showChangePositionDialog(ModuleItem m) async {
    final sortedModules = [...ref.read(courseDetailsControllerProvider(widget.course.id)).modules]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final selected = await _showManagedDialog<int>(
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => _ChangeModulePositionDialog(
        module: m,
        modules: sortedModules,
      ),
    );
    if (selected == null || !mounted) return;

    final success = await ref.read(courseDetailsControllerProvider(widget.course.id).notifier)
        .reorderModule(moduleId: m.id, newPosition: selected - 1);
    if (!mounted) return;

    if (success) {
      final refreshed = ref.read(courseDetailsControllerProvider(widget.course.id)).modules
          .firstWhere((module) => module.id == m.id, orElse: () => m);
      setState(() {
        if (_active?.type == _CType.module && _active?.module?.id == m.id) {
          _sel = _Ctx.module(refreshed);
        }
      });
      AppToast.success(context, title: 'Position updated', message: 'Module moved to #$selected.');
    } else {
      AppToast.error(context, title: 'Reorder failed', message: 'Please try again.');
    }
  }

  Future<void> _confirmDelete(ModuleItem m) async {
    final ok = await _showManagedDialog<bool>(
        barrierColor: Colors.black.withOpacity(0.35),
        builder: (_) => _ConfirmDialogWidget(title: 'Delete Module',
            body: 'Delete "${m.title}"? This will also remove all its materials.',
            confirm: 'Delete', confirmColor: const Color(0xFFEF4444)));
    if (ok != true || !mounted) return;

    final success = await ref.read(courseDetailsControllerProvider(widget.course.id).notifier)
        .deleteModule(m.id);
    if (!mounted) return;

    if (success) {
      setState(() {
        _expanded.remove(m.id);
        if (_active?.module?.id == m.id) {
          _sel = null;
          _stack.clear();
        }
      });
      AppToast.success(context, title: 'Module deleted', message: '"${m.title}" was removed.');
    } else {
      AppToast.error(context, title: 'Delete failed', message: 'Please try again.');
    }
  }

  Future<void> _showAddTopicDialog(ModuleItem m, MaterialItem mat) async {
    final outcomes = ref.read(courseLOProvider(widget.course.id));
    final result = await _showManagedDialog<_TopicDialogResult>(
      barrierColor: Colors.black.withOpacity(0.42),
      builder: (_) => _AddTopicDialogV2(outcomes: outcomes),
    );

    if (result == null || !mounted) return;

    if (result.mode == _TopicCreateMode.ai) {
      _openGenerateDialog(moduleId: m.id, materialId: mat.id);
      return;
    }

    final title = result.title.trim();
    if (title.isEmpty) return;

    final notifier =
        ref.read(courseDetailsControllerProvider(widget.course.id).notifier);

    final topic = await notifier.createTopic(
      moduleId: m.id,
      materialId: mat.id,
      payload: TopicCreateRequest(
        title: title,
        learningOutcomeIds: result.learningOutcomeIds,
      ),
    );

    if (!mounted) return;

    if (topic != null) {
      AppToast.success(
        context,
        title: 'Topic added',
        message: '"${topic.title}" created successfully.',
      );
    } else {
      AppToast.error(
        context,
        title: 'Could not add topic',
        message: 'Please try again.',
      );
    }
  }
  Future<void> _showEditTopicDialog(ModuleItem m, MaterialItem mat, TopicItem topic) async {
    final outcomes = ref.read(courseLOProvider(widget.course.id));
    final notifier = ref.read(courseDetailsControllerProvider(widget.course.id).notifier);

    final titleCtrl = TextEditingController(text: topic.title);
    final descriptionCtrl = TextEditingController(text: topic.description ?? '');
    final notesCtrl = TextEditingController(text: topic.instructorNotes ?? '');
    TopicDifficulty difficulty = topic.difficulty;
    TopicReadiness readiness = topic.readiness;
    final selectedOutcomeIds = <int>{...topic.learningOutcomeIds};

    Future<bool> confirmDelete(BuildContext context) async {
      final ok = await _showManagedDialog<bool>(
            barrierColor: Colors.black.withOpacity(0.4),
            builder: (_) => _ConfirmDialogWidget(
              title: 'Delete Topic',
              body: 'Delete "${topic.title}"? This action cannot be undone.',
              confirm: 'Delete',
              confirmColor: const Color(0xFFDC2626),
            ),
          ) ??
          false;
      return ok;
    }

    final result = await _showManagedDialog<bool>(
      barrierColor: Colors.black.withOpacity(0.42),
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final selectedOutcomes = outcomes
              .where((lo) => selectedOutcomeIds.contains(lo.id))
              .toList();

          Color readinessFg(TopicReadiness value) {
            switch (value) {
              case TopicReadiness.ready:
                return _K.green;
              case TopicReadiness.review:
                return _K.amber;
              case TopicReadiness.draft:
                return AppColors.textMuted;
            }
          }

          Color readinessBg(TopicReadiness value) {
            switch (value) {
              case TopicReadiness.ready:
                return _K.greenSoft;
              case TopicReadiness.review:
                return _K.amberSoft;
              case TopicReadiness.draft:
                return const Color(0xFFF1F5F9);
            }
          }

          Color difficultyColor(TopicDifficulty value) {
            switch (value) {
              case TopicDifficulty.advanced:
                return const Color(0xFFDC2626);
              case TopicDifficulty.intermediate:
                return _K.amber;
              case TopicDifficulty.beginner:
                return _K.blue;
            }
          }

          Color difficultyBg(TopicDifficulty value) {
            switch (value) {
              case TopicDifficulty.advanced:
                return const Color(0xFFFEF2F2);
              case TopicDifficulty.intermediate:
                return const Color(0xFFFFFBEB);
              case TopicDifficulty.beginner:
                return const Color(0xFFEFF6FF);
            }
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A0F172A),
                    blurRadius: 36,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFF8FAFF), Color(0xFFFFFFFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.tune_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Manage Topic',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textTitle,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Edit topic details, map outcomes, and prepare this topic for delivery.',
                                    style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () => Navigator.pop(dialogContext, false),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _TopicStatusChip(
                              icon: Icons.auto_awesome_rounded,
                              label: topic.source == TopicSource.ai ? 'AI-generated topic' : 'Manual topic',
                              fg: AppColors.primary,
                              bg: AppColors.primarySoft,
                            ),
                            _TopicStatusChip(
                              icon: Icons.signal_cellular_alt_rounded,
                              label: difficulty.label,
                              fg: difficultyColor(difficulty),
                              bg: difficultyBg(difficulty),
                            ),
                            _TopicStatusChip(
                              icon: Icons.track_changes_rounded,
                              label: readiness.label,
                              fg: readinessFg(readiness),
                              bg: readinessBg(readiness),
                            ),
                            _TopicStatusChip(
                              icon: Icons.flag_outlined,
                              label: selectedOutcomeIds.isEmpty
                                  ? 'No outcomes linked'
                                  : '${selectedOutcomeIds.length} outcome(s) linked',
                              fg: _K.blue,
                              bg: _K.blueSoft,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CardWidget(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Core details',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textTitle,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: titleCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Topic title',
                                      hintText: 'Write a concise, teachable topic name',
                                      prefixIcon: const Icon(Icons.title_rounded),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: descriptionCtrl,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      labelText: 'Description',
                                      hintText: 'Add a short summary, scope, or teaching angle for this topic',
                                      alignLabelWithHint: true,
                                      prefixIcon: const Padding(
                                        padding: EdgeInsets.only(bottom: 52),
                                        child: Icon(Icons.notes_rounded),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _CardWidget(
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Delivery setup',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textTitle,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        const Text(
                                          'Difficulty',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: TopicDifficulty.values.map((value) {
                                            final selected = difficulty == value;
                                            return ChoiceChip(
                                              label: Text(value.label),
                                              selected: selected,
                                              onSelected: (_) => setDialogState(() => difficulty = value),
                                              avatar: Icon(
                                                value == TopicDifficulty.beginner
                                                    ? Icons.wb_sunny_outlined
                                                    : value == TopicDifficulty.intermediate
                                                        ? Icons.stacked_bar_chart_rounded
                                                        : Icons.local_fire_department_outlined,
                                                size: 16,
                                                color: selected ? Colors.white : difficultyColor(value),
                                              ),
                                              labelStyle: TextStyle(
                                                color: selected ? Colors.white : AppColors.textTitle,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              selectedColor: difficultyColor(value),
                                              backgroundColor: difficultyBg(value),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                            );
                                          }).toList(),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Readiness',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: TopicReadiness.values.map((value) {
                                            final selected = readiness == value;
                                            return ChoiceChip(
                                              label: Text(value.label),
                                              selected: selected,
                                              onSelected: (_) => setDialogState(() => readiness = value),
                                              avatar: Icon(Icons.circle, size: 10, color: selected ? Colors.white : readinessFg(value)),
                                              labelStyle: TextStyle(
                                                color: selected ? Colors.white : AppColors.textTitle,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              selectedColor: readinessFg(value),
                                              backgroundColor: readinessBg(value),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _CardWidget(
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Instructor notes',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textTitle,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Capture explanations, examples, pacing cues, or common misconceptions.',
                                          style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
                                        ),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller: notesCtrl,
                                          maxLines: 8,
                                          decoration: InputDecoration(
                                            hintText: 'Example: Start with a concrete scenario, then introduce the abstract rule.',
                                            alignLabelWithHint: true,
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _CardWidget(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Learning outcome alignment',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textTitle,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Select the outcomes this topic supports. These mappings are available in the backend update flow.',
                                    style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
                                  ),
                                  const SizedBox(height: 14),
                                  if (outcomes.isEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: const Text(
                                        'No course outcomes yet. Add them in the Outcomes tab first.',
                                        style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                                      ),
                                    )
                                  else ...[
                                    if (selectedOutcomes.isNotEmpty) ...[
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: selectedOutcomes
                                            .map(
                                              (lo) => Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: _K.blueSoft,
                                                  borderRadius: BorderRadius.circular(999),
                                                  border: Border.all(color: _K.blueMid),
                                                ),
                                                child: Text(
                                                  '${lo.code} • ${lo.title}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: outcomes.map((lo) {
                                        final selected = selectedOutcomeIds.contains(lo.id);
                                        return FilterChip(
                                          selected: selected,
                                          onSelected: (value) => setDialogState(() {
                                            if (value) {
                                              selectedOutcomeIds.add(lo.id);
                                            } else {
                                              selectedOutcomeIds.remove(lo.id);
                                            }
                                          }),
                                          label: Text('${lo.code} • ${lo.title}'),
                                          labelStyle: TextStyle(
                                            color: selected ? AppColors.primary : AppColors.textTitle,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          selectedColor: const Color(0xFFE0ECFF),
                                          backgroundColor: Colors.white,
                                          side: BorderSide(
                                            color: selected ? _K.blue : const Color(0xFFE5E7EB),
                                          ),
                                          avatar: Icon(
                                            selected ? Icons.check_circle_rounded : Icons.flag_outlined,
                                            size: 16,
                                            color: selected ? _K.blue : AppColors.textMuted,
                                          ),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFCFCFD),
                      border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                    ),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final ok = await confirmDelete(dialogContext);
                            if (!ok) return;
                            await notifier.deleteTopic(
                              moduleId: m.id,
                              topicId: topic.id,
                              materialId: mat.id,
                            );
                            if (mounted) Navigator.pop(dialogContext, true);
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Delete topic'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final title = titleCtrl.text.trim();
                            if (title.isEmpty) {
                              AppToast.error(
                                context,
                                title: 'Topic title required',
                                message: 'Please enter a title before saving.',
                              );
                              return;
                            }
                            await notifier.updateTopic(
                              topic.copyWith(
                                moduleId: m.id,
                                materialId: mat.id,
                                title: title,
                                description: descriptionCtrl.text.trim().isEmpty ? null : descriptionCtrl.text.trim(),
                                learningOutcomeIds: selectedOutcomeIds.toList(),
                                linkedOutcomeId: selectedOutcomeIds.isEmpty ? null : selectedOutcomeIds.first.toString(),
                                linkedOutcomeIds: selectedOutcomeIds.map((id) => id.toString()).toList(),
                                instructorNotes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                                difficulty: difficulty,
                                readiness: readiness,
                              ),
                            );
                            if (mounted) Navigator.pop(dialogContext, true);
                          },
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: const Text('Save changes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if ((result ?? false) && mounted) {
      AppToast.success(
        context,
        title: 'Topic updated',
        message: 'Topic details were saved.',
      );
    }
  }

  Future<void> _showAddQuestionSheet(ModuleItem module, MaterialItem material, TopicItem topic) async {
    if (mounted) setState(() => _dialogOpen = true);
    try {
      await showAddQuestionDialog(
        context,
        moduleId: module.id,
        moduleName: module.title,
        materialId: material.id,
        materialName: material.displayTitle,
        topicName: topic.title,
        onAdd: (q) => ref.read(courseDetailsControllerProvider(widget.course.id).notifier).addQuestion(q),
      );
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }

  void _openGenerateDialog({int? moduleId, int? materialId, int? topicId}) => _showManagedDialog(
      builder: (_) => GenerateQuestionsDialog(
        courseId: widget.course.id,
        initialModuleId: moduleId,
        initialMaterialId: materialId,
        initialTopicId: topicId,
      ));
}

// ─────────────────────────────────────────────────────────────────────────────
//  SIDEBAR
// ─────────────────────────────────────────────────────────────────────────────

class _SidebarWidget extends StatelessWidget {
  final CourseDetailsState state;
  final Set<int>           expanded;
  final _Ctx?              active;
  final ScrollController   scroll;
  final int?               draggingModuleId;
  final void Function(ModuleItem) onModuleTap;
  final void Function(ModuleItem, MaterialItem) onMaterialTap;
  final void Function(ModuleItem, MaterialItem, TopicItem) onTopicTap;
  final void Function(ModuleItem) onAddMaterial;
  final void Function(int oldIndex, int newIndex) onModuleReorder;
  final void Function(int? moduleId) onDragChanged;
  final VoidCallback onAddModule;
  final VoidCallback onRefresh;

  const _SidebarWidget({
    required this.state,
    required this.expanded,
    required this.active,
    required this.scroll,
    required this.draggingModuleId,
    required this.onModuleTap,
    required this.onMaterialTap,
    required this.onTopicTap,
    required this.onAddMaterial,
    required this.onModuleReorder,
    required this.onDragChanged,
    required this.onAddModule,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 268,
      decoration: const BoxDecoration(
        color: _K.sidebar,
        border: Border(right: BorderSide(color: _K.div)),
      ),
      child: Column(
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: _K.div)),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_open_rounded, size: 14, color: AppColors.textHint),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'STRUCTURE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textHint,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                if (state.modulesLoading)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                _IBtn(icon: Icons.refresh_rounded, tooltip: 'Refresh', onTap: onRefresh),
              ],
            ),
          ),
          Expanded(
            child: state.modulesLoading && state.modules.isEmpty
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : state.modules.isEmpty
                    ? _SidebarEmpty(onAdd: onAddModule)
                    : Builder(
                        builder: (context) {
                          final modules = [...state.modules]
                            ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
                          return ReorderableListView.builder(
                            key: const PageStorageKey('course-materials-sidebar-scroll'),
                            buildDefaultDragHandles: false,
                            proxyDecorator: (child, index, animation) {
                              return AnimatedBuilder(
                                animation: animation,
                                builder: (context, _) {
                                  final t = Curves.easeOutCubic.transform(animation.value);
                                  return Transform.scale(
                                    scale: 1.0 + (0.02 * t),
                                    child: Material(
                                      color: Colors.transparent,
                                      elevation: 0,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary.withOpacity(0.14),
                                              blurRadius: 16,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: child,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            onReorderStart: (index) => onDragChanged(modules[index].id),
                            onReorderEnd: (_) => onDragChanged(null),
                            onReorder: onModuleReorder,
                            scrollController: scroll,
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                            itemCount: modules.length,
                            itemBuilder: (_, i) {
                              final m = modules[i];
                              return Padding(
                                key: ValueKey('module-${m.id}'),
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _ModuleRowWidget(
                                  module: m,
                                  isExpanded: expanded.contains(m.id),
                                  materials: state.materials[m.id] ?? [],
                                  loading: state.materialsLoading[m.id] ?? false,
                                  moduleTopics: state.topics[m.id] ?? [],
                                  active: active,
                                  isDragging: draggingModuleId == m.id,
                                  onModuleTap: () => onModuleTap(m),
                                  onMaterialTap: (mat) => onMaterialTap(m, mat),
                                  onTopicTap: (mat, t) => onTopicTap(m, mat, t),
                                  onAddMaterial: () => onAddMaterial(m),
                                  dragHandle: ReorderableDragStartListener(
                                    index: i,
                                    child: Tooltip(
                                      message: 'Drag to reorder',
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: Icon(
                                          Icons.drag_indicator_rounded,
                                          size: 16,
                                          color: draggingModuleId == m.id
                                              ? AppColors.primary
                                              : AppColors.textHint,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _K.div)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                onPressed: onAddModule,
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text(
                  'Add Module',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarEmpty extends StatelessWidget {
  final VoidCallback onAdd;
  const _SidebarEmpty({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_open_outlined, size: 28, color: AppColors.textHint),
              const SizedBox(height: 12),
              const Text(
                'No modules yet',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTitle,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Create your first module to start building the course structure.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.45),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Create first module'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
}

// ─── Module row ──────────────────────────────────────────────────────────────
class _ModuleRowWidget extends StatelessWidget {
  final ModuleItem    module;
  final bool          isExpanded;
  final List<MaterialItem> materials;
  final bool          loading;
  final List<TopicItem> moduleTopics;
  final _Ctx?         active;
  final bool          isDragging;
  final Widget?       dragHandle;
  final VoidCallback  onModuleTap;
  final void Function(MaterialItem) onMaterialTap;
  final void Function(MaterialItem, TopicItem) onTopicTap;
  final VoidCallback  onAddMaterial;

  const _ModuleRowWidget({
    required this.module,
    required this.isExpanded,
    required this.materials,
    required this.loading,
    required this.moduleTopics,
    required this.active,
    required this.isDragging,
    required this.dragHandle,
    required this.onModuleTap,
    required this.onMaterialTap,
    required this.onTopicTap,
    required this.onAddMaterial,
  });

  bool get _isSel => active?.type == _CType.module && active?.module?.id == module.id;

  @override
  Widget build(BuildContext context) {
    final highlight = _isSel || isDragging;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          onTap: onModuleTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(8, 9, 8, 9),
            decoration: BoxDecoration(
              color: highlight ? _K.blueSoft : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: highlight ? AppColors.primary.withOpacity(0.18) : _K.div,
              ),
            ),
            child: Row(
              children: [
                dragHandle ?? const SizedBox(width: 22, height: 22),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded,
                  size: 15,
                  color: highlight ? AppColors.primary : AppColors.textHint,
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.folder_rounded,
                  size: 16,
                  color: highlight ? AppColors.primary : const Color(0xFFEA580C),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: highlight ? AppColors.primary : AppColors.textTitle,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${materials.length} material${materials.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: module.isPublished ? _K.greenSoft : _K.amberSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    module.isPublished ? 'Live' : 'Draft',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: module.isPublished ? _K.green : _K.amber,
                    ),
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    hoverColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                    onTap: onAddMaterial,
                    borderRadius: BorderRadius.circular(7),
                    child: const Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(Icons.add_rounded, size: 14, color: AppColors.textHint),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
          firstChild: const SizedBox.shrink(),
          secondChild: _buildChildren(),
        ),
      ],
    );
  }

  Widget _buildChildren() {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5)),
        ),
      );
    }
    if (materials.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(34, 8, 6, 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _K.div),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textHint),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No materials yet. Use the plus button to upload one.',
                style: TextStyle(fontSize: 11, color: AppColors.textHint, height: 1.35),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: materials.map((mat) {
        final matSel = active?.material?.id == mat.id &&
            (active?.type == _CType.material || active?.type == _CType.topic);
        final scopedTopics = moduleTopics.where((t) => t.materialId == mat.id).toList();
        return _MatRowWidget(
          material: mat,
          topics: scopedTopics,
          isSelected: matSel,
          active: active,
          onTap: () => onMaterialTap(mat),
          onTopicTap: (t) => onTopicTap(mat, t),
        );
      }).toList(),
    );
  }
}

class _MatRowWidget extends StatelessWidget {
  final MaterialItem material;
  final List<TopicItem> topics;
  final bool isSelected;
  final _Ctx? active;
  final VoidCallback onTap;
  final void Function(TopicItem) onTopicTap;
  const _MatRowWidget({required this.material, required this.topics, required this.isSelected, required this.active, required this.onTap, required this.onTopicTap});

  @override
  Widget build(BuildContext context) {
    const iconMap = {
      'video': (Icons.play_circle_outline_rounded, Color(0xFF2563EB)),
      'pdf'  : (Icons.picture_as_pdf_outlined,    Color(0xFFDC2626)),
      'quiz' : (Icons.quiz_outlined,               Color(0xFF7C3AED)),
    };
    final (ico, col) = iconMap[material.type] ?? (Icons.article_outlined, AppColors.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.fromLTRB(28, 1, 6, 1),
            padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
            decoration: BoxDecoration(
              color: isSelected ? _K.blueSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                Container(width: 1, height: 14, color: _K.div, margin: const EdgeInsets.only(right: 8)),
                Icon(ico, size: 13, color: isSelected ? AppColors.primary : col),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    material.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.primary : const Color(0xFF334155),
                    ),
                  ),
                ),
                _Dot(status: material.status),
              ],
            ),
          ),
        ),
        ...topics.map((t) {
          final tSel = active?.type == _CType.topic && active?.topic?.id == t.id;
          return InkWell(
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            onTap: () => onTopicTap(t),
            child: Container(
              margin: const EdgeInsets.fromLTRB(42, 0, 6, 0),
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
              decoration: BoxDecoration(
                color: tSel ? AppColors.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                children: [
                  Container(width: 1, height: 11, color: _K.div, margin: const EdgeInsets.only(right: 7)),
                  Icon(Icons.tag_rounded, size: 10, color: tSel ? AppColors.primary : AppColors.textHint),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: tSel ? FontWeight.w600 : FontWeight.w400,
                        color: tSel ? AppColors.primary : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FOOTER
// ─────────────────────────────────────────────────────────────────────────────
class _FooterWidget extends StatelessWidget {
  final _Ctx ctx; final bool uploading; final bool canGenerate;
  final VoidCallback onUpload, onGenerate, onClose;
  const _FooterWidget({required this.ctx, required this.uploading, required this.canGenerate,
      required this.onUpload, required this.onGenerate, required this.onClose});

  String get _label => switch (ctx.type) {
    _CType.module   => ctx.module?.title ?? 'Module',
    _CType.material => ctx.material?.displayTitle ?? 'Material',
    _CType.topic    => ctx.topic?.title ?? 'Topic',
  };
  IconData get _icon => switch (ctx.type) {
    _CType.module   => Icons.folder_rounded,
    _CType.material => ctx.material?.type == 'video'
        ? Icons.play_circle_filled_rounded : Icons.picture_as_pdf_rounded,
    _CType.topic    => Icons.tag_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(color: Colors.white,
          border: const Border(top: BorderSide(color: _K.div)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 16, offset: const Offset(0, -4))]),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: _K.blueSoft, borderRadius: BorderRadius.circular(7)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_icon, size: 13, color: AppColors.primary), const SizedBox(width: 6),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 200),
                child: Text(_label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: AppColors.primary))),
          ])),
        const Spacer(),
        _Btn(icon: Icons.auto_awesome_rounded, label: canGenerate ? 'Generate Questions' : 'No content yet',
            primary: true, disabled: !canGenerate, onTap: canGenerate ? onGenerate : null),
        const SizedBox(width: 8),
        InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), onTap: onClose, borderRadius: BorderRadius.circular(6),
            child: const Padding(padding: EdgeInsets.all(7),
                child: Icon(Icons.close_rounded, size: 15, color: AppColors.textHint))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyStateWidget extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyStateWidget({required this.onCreate});
  @override
  Widget build(BuildContext context) => Container(
        color: _K.bg,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _K.div),
              boxShadow: const [
                BoxShadow(color: Color(0x08000000), blurRadius: 18, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: _K.blueSoft,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.folder_open_rounded, size: 36, color: AppColors.primary),
                ),
                const SizedBox(height: 18),
                const Text('Select a module or material', style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
                const SizedBox(height: 8),
                const Text(
                  'Use the structure panel to explore your modules, reorder them by dragging, or open a material to manage topics and content.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _K.blueSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.drag_indicator_rounded, size: 16, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Tip: drag modules in the left panel to reorder them', style: TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                OutlinedButton.icon(onPressed: onCreate,
                    icon: const Icon(Icons.add_rounded, size: 15),
                    label: const Text('New Module'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
              ],
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  MODULE PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _ModulePanelWidget extends StatelessWidget {
  final ModuleItem module;
  final List<MaterialItem> materials;
  final bool uploading;
  final double uploadProgress;
  final VoidCallback onUpload;
  final void Function(MaterialItem) onMaterialTap;
  final VoidCallback? onRename, onEditDescription, onTogglePublish, onChangePosition, onDelete, onShare;

  const _ModulePanelWidget({
    required this.module,
    required this.materials,
    required this.uploading,
    required this.uploadProgress,
    required this.onUpload,
    required this.onMaterialTap,
    this.onRename,
    this.onEditDescription,
    this.onTogglePublish,
    this.onChangePosition,
    this.onDelete,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final description = (module.description ?? '').trim();
    final hasDescription = description.isNotEmpty;
    final readyMaterials = materials.where((m) => m.status == 'ready').length;
    final processingMaterials = materials.where((m) => m.status != 'ready').length;

    return Container(
      color: _K.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ModuleHeroWidget(module: module, materialCount: materials.length),
            const SizedBox(height: 14),
            _ModuleInsightsStrip(
              materialCount: materials.length,
              readyMaterials: readyMaterials,
              processingMaterials: processingMaterials,
              sharedCount: module.sharedWithCourseIds.length,
            ),
            const SizedBox(height: 14),
            if (uploading) ...[
              _UploadProgressWidget(progress: uploadProgress),
              const SizedBox(height: 14),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1100;
                final infoCard = _CardWidget(
                  header: const _HdrWidget(
                    icon: Icons.dashboard_customize_rounded,
                    iconColor: AppColors.primary,
                    title: 'Module overview',
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _MiniInfoTile(
                              icon: Icons.layers_rounded,
                              iconBg: _K.blueSoft,
                              iconFg: AppColors.primary,
                              label: 'Position',
                              value: '#${module.orderIndex + 1}',
                              caption: 'Current order in this course',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MiniInfoTile(
                              icon: module.isPublished ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              iconBg: module.isPublished ? _K.greenSoft : _K.amberSoft,
                              iconFg: module.isPublished ? _K.green : _K.amber,
                              label: 'Visibility',
                              value: module.isPublished ? 'Live' : 'Draft',
                              caption: module.isPublished ? 'Visible to students' : 'Hidden from students',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _MiniInfoTile(
                        icon: Icons.notes_rounded,
                        iconBg: const Color(0xFFF8FAFC),
                        iconFg: AppColors.textMuted,
                        label: 'Description',
                        value: hasDescription ? description : 'No description added yet',
                        caption: hasDescription
                            ? 'Used to describe this module for instructors and learners.'
                            : 'Add a short summary to make this module easier to understand.',
                        multiline: true,
                      ),
                    ],
                  ),
                );

                final actionsCard = Column(
                  children: [
                    _CardWidget(
                      header: const _HdrWidget(
                        icon: Icons.auto_fix_high_rounded,
                        iconColor: AppColors.primary,
                        title: 'Manage module',
                      ),
                      child: Column(
                        children: [
                          _PRow(
                            icon: Icons.drive_file_rename_outline_rounded,
                            iconBg: _K.blueSoft,
                            iconFg: AppColors.primary,
                            label: 'Rename module',
                            sub: 'Update the module title shown across the course.',
                            onTap: onRename,
                          ),
                          _DivW(),
                          _PRow(
                            icon: Icons.notes_rounded,
                            iconBg: _K.blueSoft,
                            iconFg: AppColors.primary,
                            label: 'Edit description',
                            sub: hasDescription ? 'Refine the current summary and teaching context.' : 'Add a short summary for this module.',
                            onTap: onEditDescription,
                          ),
                          _DivW(),
                          _PRow(
                            icon: Icons.upload_file_rounded,
                            iconBg: AppColors.primarySoft,
                            iconFg: AppColors.primary,
                            label: 'Upload material',
                            sub: uploading ? 'Upload in progress…' : 'Add a PDF, video, or document to this module.',
                            onTap: uploading ? null : onUpload,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _CardWidget(
                      header: const _HdrWidget(
                        icon: Icons.settings_suggest_rounded,
                        iconColor: AppColors.primary,
                        title: 'Distribution & status',
                      ),
                      child: Column(
                        children: [
                          _PRow(
                            icon: module.isPublished ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            iconBg: module.isPublished ? _K.amberSoft : _K.greenSoft,
                            iconFg: module.isPublished ? _K.amber : _K.green,
                            label: module.isPublished ? 'Unpublish module' : 'Publish module',
                            sub: module.isPublished ? 'Hide this module from students.' : 'Make this module visible to students.',
                            onTap: onTogglePublish,
                          ),
                          _DivW(),
                          _PRow(
                            icon: Icons.swap_vert_rounded,
                            iconBg: _K.greenSoft,
                            iconFg: _K.green,
                            label: 'Change position',
                            sub: 'Currently #${module.orderIndex + 1} in the course structure.',
                            onTap: onChangePosition,
                          ),
                          _DivW(),
                          _PRow(
                            icon: Icons.share_rounded,
                            iconBg: const Color(0xFFF0FDF4),
                            iconFg: const Color(0xFF16A34A),
                            label: 'Share with another course',
                            sub: module.sharedWithCourseIds.isEmpty
                                ? 'Not shared with any other course.'
                                : 'Shared with ${module.sharedWithCourseIds.length} course${module.sharedWithCourseIds.length == 1 ? '' : 's'}.',
                            onTap: onShare,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _CardWidget(
                      header: const _HdrWidget(
                        icon: Icons.delete_outline_rounded,
                        iconColor: Color(0xFFEF4444),
                        title: 'Danger zone',
                      ),
                      child: _SectionNoteWidget(
                        tone: _SectionTone.danger,
                        title: 'Delete this module',
                        description: 'This permanently removes the module from the course. Only do this when you are sure the content is no longer needed.',
                        actionLabel: 'Delete module',
                        onTap: onDelete,
                      ),
                    ),
                  ],
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: infoCard),
                      const SizedBox(width: 16),
                      Expanded(flex: 7, child: actionsCard),
                    ],
                  );
                }

                return Column(
                  children: [
                    infoCard,
                    const SizedBox(height: 16),
                    actionsCard,
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _CardWidget(
              header: _HdrWidget(
                icon: Icons.folder_open_rounded,
                iconColor: AppColors.primary,
                title: 'Materials',
                badge: '${materials.length}',
                trailing: _SmBtn(
                  icon: Icons.upload_rounded,
                  label: 'Upload',
                  disabled: uploading,
                  onTap: onUpload,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'All files and learning assets attached to this module appear here.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  if (materials.isEmpty)
                    _MatEmptyWidget(onUpload: onUpload)
                  else
                    Column(
                      children: materials.asMap().entries.map(
                        (e) => Padding(
                          padding: EdgeInsets.only(bottom: e.key == materials.length - 1 ? 0 : 10),
                          child: _ModuleMaterialCard(
                            material: e.value,
                            onTap: () => onMaterialTap(e.value),
                          ),
                        ),
                      ).toList(),
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


class _HPill extends StatelessWidget {
  final String l;
  final Color c;
  const _HPill(this.l, this.c);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Text(
          l,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c),
        ),
      );
}

String _relativeDate(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);
  if (difference.inDays <= 0) return 'today';
  if (difference.inDays == 1) return '1 day ago';
  if (difference.inDays < 30) return '${difference.inDays} days ago';
  final months = (difference.inDays / 30).floor();
  if (months <= 1) return '1 month ago';
  if (months < 12) return '$months months ago';
  final years = (months / 12).floor();
  return years <= 1 ? '1 year ago' : '$years years ago';
}

class _UploadProgressWidget extends StatelessWidget {
  final double progress;
  const _UploadProgressWidget({required this.progress});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _K.div),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Uploading material…',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFE2E8F0),
                color: AppColors.primary,
                minHeight: 4,
              ),
            ),
          ],
        ),
      );
}

class _ModuleHeroWidget extends StatelessWidget {
  final ModuleItem module;
  final int materialCount;
  const _ModuleHeroWidget({required this.module, required this.materialCount});

  @override
  Widget build(BuildContext context) {
    final description = (module.description ?? '').trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF145CCB), Color(0xFF137FEC), Color(0xFF4CB5FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          final rightCard = Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Module order', style: TextStyle(fontSize: 10.5, color: Colors.white.withOpacity(0.72))),
                const SizedBox(height: 4),
                Text('#${module.orderIndex + 1}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 10),
                Text('Updated ${_relativeDate(module.updatedAt)}', style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.78))),
              ],
            ),
          );

          final body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HPill(module.isPublished ? '● Live' : '● Draft', module.isPublished ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24)),
                  const _HPill('MODULE', Colors.white70),
                  _HPill('$materialCount material${materialCount == 1 ? '' : 's'}', Colors.white70),
                  if (module.isShared) _HPill('Shared', Colors.white70),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                module.title,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1),
              ),
              const SizedBox(height: 8),
              Text(
                description.isNotEmpty
                    ? description
                    : 'This module groups related materials and learning assets inside the course structure.',
                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.82), height: 1.55),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [body, const SizedBox(height: 16), rightCard],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: body), const SizedBox(width: 16), SizedBox(width: 180, child: rightCard)],
          );
        },
      ),
    );
  }
}

class _ModuleInsightsStrip extends StatelessWidget {
  final int materialCount;
  final int readyMaterials;
  final int processingMaterials;
  final int sharedCount;

  const _ModuleInsightsStrip({required this.materialCount, required this.readyMaterials, required this.processingMaterials, required this.sharedCount});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.folder_copy_rounded, 'Materials', '$materialCount total', _K.blueSoft, AppColors.primary),
      (Icons.verified_rounded, 'Ready', '$readyMaterials available', _K.greenSoft, _K.green),
      (Icons.sync_rounded, 'Processing', '$processingMaterials pending', _K.amberSoft, _K.amber),
      (Icons.share_rounded, 'Shared', sharedCount == 0 ? 'Only in this course' : 'Shared with $sharedCount', const Color(0xFFF0FDF4), const Color(0xFF16A34A)),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _K.div),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: items[i].$4, borderRadius: BorderRadius.circular(10)),
                    child: Icon(items[i].$1, size: 18, color: items[i].$5),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].$2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                        const SizedBox(height: 2),
                        Text(items[i].$3, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (i != items.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _MiniInfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String label;
  final String value;
  final String caption;
  final bool multiline;

  const _MiniInfoTile({required this.icon, required this.iconBg, required this.iconFg, required this.label, required this.value, required this.caption, this.multiline = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _K.div),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 18, color: iconFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: multiline ? null : 1,
                  overflow: multiline ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textTitle, height: 1.4),
                ),
                const SizedBox(height: 4),
                Text(caption, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _SectionTone { normal, danger }

class _SectionNoteWidget extends StatelessWidget {
  final _SectionTone tone;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback? onTap;

  const _SectionNoteWidget({required this.tone, required this.title, required this.description, required this.actionLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDanger = tone == _SectionTone.danger;
    final bg = isDanger ? const Color(0xFFFFF5F5) : const Color(0xFFFAFBFD);
    final border = isDanger ? const Color(0xFFFECACA) : _K.div;
    final fg = isDanger ? const Color(0xFFDC2626) : AppColors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDanger ? const Color(0xFFB91C1C) : AppColors.textTitle)),
                const SizedBox(height: 6),
                Text(description, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.45)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: fg,
              side: BorderSide(color: fg),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _MatEmptyWidget extends StatelessWidget {
  final VoidCallback onUpload;
  const _MatEmptyWidget({required this.onUpload});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFBFD),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _K.div),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: _K.blueSoft, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.upload_file_outlined, size: 24, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              const Text('No materials yet', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
              const SizedBox(height: 5),
              const Text('Upload a PDF, video, or document to turn this module into usable learning content.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.5)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.upload_rounded, size: 14),
                label: const Text('Upload material'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ModuleMaterialCard extends StatelessWidget {
  final MaterialItem material;
  final VoidCallback onTap;
  const _ModuleMaterialCard({required this.material, required this.onTap});

  static const _colors = {
    'video': (Icons.play_circle_filled_rounded, Color(0xFFDBEAFE), Color(0xFF2563EB), 'Video'),
    'pdf': (Icons.picture_as_pdf_rounded, Color(0xFFFEE2E2), Color(0xFFDC2626), 'PDF'),
    'quiz': (Icons.quiz_rounded, Color(0xFFF3E8FF), Color(0xFF9333EA), 'Quiz'),
  };
  static const _status = {
    'ready': ('Ready', Color(0xFFDCFCE7), Color(0xFF16A34A)),
    'processing': ('Processing', Color(0xFFFEF3C7), Color(0xFFD97706)),
    'uploaded': ('Processing', Color(0xFFFEF3C7), Color(0xFFD97706)),
    'draft_upload': ('Uploading', Color(0xFFE0F2FE), Color(0xFF0369A1)),
    'error': ('Error', Color(0xFFFEF2F2), Color(0xFFDC2626)),
  };

  @override
  Widget build(BuildContext context) {
    final (ico, ib, ic, typeLabel) = _colors[material.type] ??
        (Icons.insert_drive_file_rounded, const Color(0xFFF1F5F9), AppColors.textMuted, material.type.toUpperCase());
    final (sl, sb, sf) = _status[material.status] ??
        (material.status, const Color(0xFFF1F5F9), AppColors.textMuted);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFD),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _K.div),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: ib, borderRadius: BorderRadius.circular(12)),
              child: Icon(ico, size: 20, color: ic),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(material.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(typeLabel, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textHint, letterSpacing: 0.4)),
                      if (material.pageCount != null) ...[
                        const SizedBox(width: 10),
                        Text('${material.pageCount} pages', style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: sb, borderRadius: BorderRadius.circular(999)),
              child: Text(sl, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: sf)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
//  MATERIAL PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _MaterialPanelWidget extends StatelessWidget {
  final ModuleItem module; final MaterialItem material;
  final List<TopicItem> topics; final bool topicsLoading;
  final List<LearningOutcome> outcomes;
  final String? downloadUrl; final bool urlLoading;
  final void Function(TopicItem) onTopicTap;
  final VoidCallback onAddTopicManual, onGenerateTopicsAI, onRefreshUrl;
  final bool previewInteractive;
  const _MaterialPanelWidget({required this.module, required this.material,
      required this.topics, required this.topicsLoading, required this.outcomes,
      required this.downloadUrl, required this.urlLoading,
      required this.onTopicTap, required this.onAddTopicManual,
      required this.onGenerateTopicsAI, required this.onRefreshUrl, required this.previewInteractive});

  @override
  Widget build(BuildContext context) {
    final mappedOutcomeIds = <String>{};
    for (final topic in topics) {
      mappedOutcomeIds.addAll(topic.linkedOutcomeIds);
      if (topic.linkedOutcomeId != null) mappedOutcomeIds.add(topic.linkedOutcomeId!);
    }

    final previewCard = _CardWidget(
      noPadding: true,
      header: _HdrWidget(
        icon: Icons.preview_rounded,
        iconColor: AppColors.primary,
        title: 'File Preview',
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (material.pageCount != null)
            _Pill(l: '${material.pageCount} pages', fg: AppColors.primary, bg: _K.blueSoft),
          const SizedBox(width: 8),
          if (downloadUrl != null && downloadUrl!.isNotEmpty) _OBtn(url: downloadUrl!),
        ]),
      ),
      child: SizedBox(
        height: 640,
        child: _FilePreviewWidget(
          material: material,
          downloadUrl: downloadUrl,
          loading: urlLoading,
          onRefresh: onRefreshUrl,
          interactive: previewInteractive,
        ),
      ),
    );

    final topicsCard = _CardWidget(
      noPadding: true,
      header: _HdrWidget(
        icon: Icons.auto_awesome_mosaic_rounded,
        iconColor: AppColors.primary,
        title: 'Topics',
        badge: topics.isNotEmpty ? '${topics.length}' : null,
        trailing: _AddTopicUnifiedBtn(onTap: onAddTopicManual),
      ),
      child: topicsLoading
          ? const SizedBox(
              height: 240,
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          : topics.isEmpty
              ? _TopicsEmptyW(onAddManual: onAddTopicManual, onGenerateAI: onGenerateTopicsAI)
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 640),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    shrinkWrap: true,
                    itemCount: topics.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) => _TopicItemW(
                      topic: topics[index],
                      index: index,
                      onTap: () => onTopicTap(topics[index]),
                    ),
                  ),
                ),
    );

    return Container(
      color: _K.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _MaterialHeroWidget(module: module, material: material),
          const SizedBox(height: 14),
          _MaterialInsightsStrip(
            topicCount: topics.length,
            readyCount: topics.where((t) => t.readiness == TopicReadiness.ready).length,
            mappedOutcomeCount: mappedOutcomeIds.length,
            totalOutcomeCount: outcomes.length,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 1180;
              if (!sideBySide) {
                return Column(children: [previewCard, const SizedBox(height: 14), topicsCard]);
              }
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 7, child: previewCard),
                const SizedBox(width: 14),
                SizedBox(width: 360, child: topicsCard),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}

class _MaterialInsightsStrip extends StatelessWidget {
  final int topicCount;
  final int readyCount;
  final int mappedOutcomeCount;
  final int totalOutcomeCount;

  const _MaterialInsightsStrip({
    required this.topicCount,
    required this.readyCount,
    required this.mappedOutcomeCount,
    required this.totalOutcomeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 10, runSpacing: 10, children: [
      _InsightPill(icon: Icons.tag_rounded, label: '$topicCount topic${topicCount == 1 ? '' : 's'}'),
      _InsightPill(icon: Icons.task_alt_rounded, label: '$readyCount ready'),
      _InsightPill(icon: Icons.flag_outlined, label: totalOutcomeCount == 0 ? 'No outcomes yet' : '$mappedOutcomeCount / $totalOutcomeCount LOs mapped'),
    ]);
  }
}

class _InsightPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InsightPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: _K.div),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: AppColors.primary),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
    ]),
  );
}

class _MatHeaderWidget extends StatelessWidget {
  final ModuleItem module; final MaterialItem material;
  const _MatHeaderWidget({required this.module, required this.material});
  static const _tc = {
    'video': (Color(0xFF2563EB), Color(0xFFDBEAFE)),
    'pdf'  : (Color(0xFFDC2626), Color(0xFFFEE2E2)),
    'image': (Color(0xFF7C3AED), Color(0xFFF3E8FF)),
    'audio': (Color(0xFF16A34A), Color(0xFFDCFCE7)),
    'quiz' : (Color(0xFF9333EA), Color(0xFFF3E8FF)),
  };
  @override
  Widget build(BuildContext context) {
    final (tcol, tbg) = _tc[material.type] ?? (AppColors.textMuted, const Color(0xFFF1F5F9));
    final (scol, sbg) = material.isReady ? (_K.green, _K.greenSoft)
        : material.isProcessing ? (_K.amber, _K.amberSoft)
        : (AppColors.dangerText, const Color(0xFFFFF1F2));
    final sl = material.isReady ? '● Ready' : material.isProcessing ? '● Processing' : '● Error';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 16, 12),
      decoration: const BoxDecoration(color: Colors.white,
          border: Border(bottom: BorderSide(color: _K.div))),
      child: Row(children: [
        _TIcon(type: material.type, size: 36), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _Pill(l: material.type.toUpperCase(), fg: tcol, bg: tbg), const SizedBox(width: 6),
            _Pill(l: sl, fg: scol, bg: sbg),
          ]),
          const SizedBox(height: 4),
          Text(material.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
          Text('In "${module.title}"', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Material Hero — mirrors _ModuleHeroWidget layout
// ─────────────────────────────────────────────────────────────────────────────
class _MaterialHeroWidget extends StatelessWidget {
  final ModuleItem module;
  final MaterialItem material;
  const _MaterialHeroWidget({required this.module, required this.material});

  static const _gradients = {
    'pdf'  : [Color(0xFF1565C0), Color(0xFF137FEC), Color(0xFF60A5FA)],
    'video': [Color(0xFF065F46), Color(0xFF059669), Color(0xFF34D399)],
    'image': [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFFA78BFA)],
    'audio': [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF5EEAD4)],
    'quiz' : [Color(0xFF5B21B6), Color(0xFF7C3AED), Color(0xFFC4B5FD)],
  };

  @override
  Widget build(BuildContext context) {
    final t = material.type.toLowerCase();
    final colors = _gradients[t] ??
        [const Color(0xFF374151), const Color(0xFF4B5563), const Color(0xFF9CA3AF)];

    final statusLabel = material.isReady || material.status == 'uploaded'
        ? '● Ready'
        : material.isProcessing
            ? '● Processing'
            : '● Processing';
    final statusColor = material.isReady || material.status == 'uploaded'
        ? const Color(0xFF4ADE80)
        : const Color(0xFFFBBF24);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Color(colors[1].value).withOpacity(0.22),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, children: [
              _HPill(statusLabel, statusColor),
              _HPill(material.type.toUpperCase(), Colors.white70),
              _HPill('In "${module.title}"', Colors.white60),
            ]),
            const SizedBox(height: 10),
            Text(
              material.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.25,
              ),
            ),
            if (material.fileName != null) ...[
              const SizedBox(height: 5),
              Text(
                material.fileName!,
                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ]),
        ),
        const SizedBox(width: 12),
        // File size / pages info box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(children: [
            Text(
              material.pageCount != null ? 'Pages' : 'Size',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              material.pageCount != null
                  ? '${material.pageCount}'
                  : material.fileSize != null
                      ? '${(material.fileSize! / 1024 / 1024).toStringAsFixed(1)}MB'
                      : '—',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
//  FILE PREVIEW
// ─────────────────────────────────────────────────────────────────────────────
enum _PK { pdf, image, video, audio, link, other }

class _FilePreviewWidget extends StatelessWidget {
  final MaterialItem material; final String? downloadUrl;
  final bool loading; final VoidCallback onRefresh;
  final bool interactive;
  const _FilePreviewWidget({required this.material, required this.downloadUrl,
      required this.loading, required this.onRefresh, required this.interactive});

  _PK get _kind {
    final t = material.type.toLowerCase(); final m = (material.mimeType ?? '').toLowerCase();
    if (t == 'video' || m.startsWith('video/')) return _PK.video;
    if (t == 'pdf'   || m == 'application/pdf') return _PK.pdf;
    if (t == 'image' || m.startsWith('image/')) return _PK.image;
    if (t == 'audio' || m.startsWith('audio/')) return _PK.audio;
    if (t == 'link') return _PK.link;
    return _PK.other;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const _LoaderW(label: 'Loading preview…');
    if (material.isProcessing && material.status != 'uploaded') {
      return const _PlaceholderW(icon: Icons.hourglass_top_rounded,
        iconColor: _K.amber, iconBg: _K.amberSoft, title: 'Processing…',
        sub: 'Your file is being processed. Preview will be available shortly.');
    }
    if (material.isError && material.status != 'uploaded') {
      return _PlaceholderW(icon: Icons.error_outline_rounded,
        iconColor: AppColors.dangerText, iconBg: _K.redSoft, title: 'Processing failed',
        sub: 'Something went wrong processing this file.',
        actionLabel: 'Retry', onAction: onRefresh);
    }
    if (downloadUrl == null || downloadUrl!.isEmpty) {
      return _PlaceholderW(icon: Icons.link_off_rounded, iconColor: AppColors.textMuted,
          iconBg: _K.bg, title: 'Preview unavailable',
          sub: 'Could not load a URL for this file.',
          actionLabel: 'Retry', onAction: onRefresh);
    }

    final url = downloadUrl!;
    return switch (_kind) {
      _PK.pdf   => _PdfPreviewWidget(url: url, material: material, interactive: interactive),
      _PK.image => _ImagePreviewWidget(url: url),
      _PK.video => _VideoPreviewWidget(url: url, material: material),
      _PK.audio => _AudioPreviewWidget(url: url, material: material),
      _PK.link  => _LinkPreviewWidget(url: url),
      _PK.other => _FallbackWidget(url: url, material: material),
    };
  }
}

class _PdfPreviewWidget extends StatefulWidget {
  final String url; final MaterialItem material;
  final bool interactive;
  const _PdfPreviewWidget({required this.url, required this.material, required this.interactive});
  @override
  State<_PdfPreviewWidget> createState() => _PdfPreviewWidgetState();
}

// Registry to avoid double-registering iframes
final _registeredPdfViews = <String>{};
final _registeredPdfIframes = <String, html.IFrameElement>{};

class _PdfPreviewWidgetState extends State<_PdfPreviewWidget> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'pdf-iframe-${widget.material.id}';
    _registerView();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePointerEvents());
  }

  void _updatePointerEvents() {
    final iframe = _registeredPdfIframes[_viewId];
    if (iframe != null) {
      iframe.style.pointerEvents = widget.interactive ? 'auto' : 'none';
      iframe.style.overflow = 'auto';
    }
  }

  @override
  void didUpdateWidget(covariant _PdfPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interactive != widget.interactive || oldWidget.url != widget.url) {
      _updatePointerEvents();
    }
  }

  void _registerView() {
    if (_registeredPdfViews.contains(_viewId)) return;
    _registeredPdfViews.add(_viewId);
    // Register the iframe as a platform view for Flutter Web
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      // ignore: avoid_web_libraries_in_flutter
      final pdfUrl = '${widget.url}#toolbar=0&navpanes=0&scrollbar=1';
      final iframe = html.IFrameElement()
        ..src = pdfUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'auto'
        ..style.backgroundColor = '#FFFFFF';
      _registeredPdfIframes[_viewId] = iframe;
      iframe.style.pointerEvents = widget.interactive ? 'auto' : 'none';
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.interactive) {
      return _PlaceholderW(
        icon: Icons.picture_as_pdf_rounded,
        iconColor: AppColors.primary,
        iconBg: _K.blueSoft,
        title: 'Preview paused',
        sub: 'The PDF preview is temporarily paused while a dialog is open.',
        actionLabel: 'Open file',
        onAction: () async {
          final uri = Uri.tryParse(widget.url);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.platformDefault);
          }
        },
      );
    }
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
      child: HtmlElementView(viewType: _viewId),
    );
  }
}

class _ImagePreviewWidget extends StatelessWidget {
  final String url; const _ImagePreviewWidget({required this.url});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(20),
    child: Container(decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(14), border: Border.all(color: _K.div)),
      child: ClipRRect(borderRadius: BorderRadius.circular(13), child: Stack(children: [
        Container(color: const Color(0xFFF8F9FB)),
        Center(child: Image.network(url, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _FallbackWidget(url: url, material: null),
            loadingBuilder: (_, child, p) => p == null ? child :
                const Center(child: CircularProgressIndicator(strokeWidth: 2)))),
        Positioned(top: 12, right: 12, child: _OBtn(url: url)),
      ]))));
}

class _VideoPreviewWidget extends StatelessWidget {
  final String url; final MaterialItem material;
  const _VideoPreviewWidget({required this.url, required this.material});
  static String _fmt(int s) {
    final h = s ~/ 3600; final m = (s % 3600) ~/ 60; final sec = s % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m ${sec}s';
  }
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _MetaStripW(material: material), const SizedBox(height: 14),
      Expanded(child: Container(
        decoration: BoxDecoration(color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(14), border: Border.all(color: _K.div)),
        child: ClipRRect(borderRadius: BorderRadius.circular(13),
            child: Stack(alignment: Alignment.center, children: [
          Container(decoration: const BoxDecoration(gradient: RadialGradient(
              colors: [Color(0xFF1A2332), Color(0xFF0D1117)]))),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 80, height: 80,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.2))),
                child: const Icon(Icons.play_arrow_rounded, size: 44, color: Colors.white)),
            const SizedBox(height: 16),
            Text(material.displayTitle, style: const TextStyle(fontSize: 16,
                fontWeight: FontWeight.w700, color: Colors.white)),
            if (material.durationSeconds != null) ...[
              const SizedBox(height: 4),
              Text(_fmt(material.durationSeconds!),
                  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.55))),
            ],
            const SizedBox(height: 22),
            ElevatedButton.icon(onPressed: () {},
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('Open Video'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.15),
                    foregroundColor: Colors.white, elevation: 0,
                    side: BorderSide(color: Colors.white.withOpacity(0.25)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)))),
          ]),
        ])))),
    ]));
}

class _AudioPreviewWidget extends StatelessWidget {
  final String url; final MaterialItem material;
  const _AudioPreviewWidget({required this.url, required this.material});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(20),
    child: Container(padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _K.div)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(
            color: _K.greenSoft, borderRadius: BorderRadius.circular(22)),
            child: const Icon(Icons.headphones_rounded, size: 40, color: _K.green)),
        const SizedBox(height: 18),
        Text(material.displayTitle, textAlign: TextAlign.center, style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
        if (material.durationSeconds != null) ...[
          const SizedBox(height: 6),
          Text('Duration: ${material.durationSeconds! ~/ 60}m ${material.durationSeconds! % 60}s',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
        const SizedBox(height: 24),
        _OBtn(url: url, big: true),
      ])));
}

class _LinkPreviewWidget extends StatelessWidget {
  final String url; const _LinkPreviewWidget({required this.url});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(20),
    child: Container(padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _K.div)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 72, height: 72, decoration: BoxDecoration(
            color: _K.blueSoft, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.link_rounded, size: 34, color: AppColors.primary)),
        const SizedBox(height: 16),
        const Text('External Link', style: TextStyle(fontSize: 17,
            fontWeight: FontWeight.w800, color: AppColors.textTitle)),
        const SizedBox(height: 8),
        Text(url, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 20), _OBtn(url: url, big: true),
      ])));
}

class _FallbackWidget extends StatelessWidget {
  final String url; final MaterialItem? material;
  const _FallbackWidget({required this.url, required this.material});
  @override
  Widget build(BuildContext context) => _PlaceholderW(icon: Icons.insert_drive_file_rounded,
      iconColor: AppColors.textMuted, iconBg: _K.bg, title: 'Preview not available',
      sub: material != null ? 'This file type (${material!.type}) cannot be previewed inline.'
          : 'Preview not available.', actionLabel: 'Open / Download', onAction: () {});
}

class _LoaderW extends StatelessWidget {
  final String label; const _LoaderW({required this.label});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const CircularProgressIndicator(strokeWidth: 2), const SizedBox(height: 12),
    Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted))]));
}

class _PlaceholderW extends StatelessWidget {
  final IconData icon; final Color iconColor, iconBg;
  final String title, sub; final String? actionLabel; final VoidCallback? onAction;
  const _PlaceholderW({required this.icon, required this.iconColor, required this.iconBg,
      required this.title, required this.sub, this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 70, height: 70,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(18)),
          child: Icon(icon, size: 32, color: iconColor)),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
      const SizedBox(height: 6),
      Text(sub, style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
          textAlign: TextAlign.center),
      if (actionLabel != null && onAction != null) ...[
        const SizedBox(height: 20),
        ElevatedButton.icon(onPressed: onAction,
            icon: const Icon(Icons.open_in_new_rounded, size: 14), label: Text(actionLabel!)),
      ],
    ])));
}

class _MetaStripW extends StatelessWidget {
  final MaterialItem material; const _MetaStripW({required this.material});
  static String _fmt(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String)>[];
    if (material.fileSize != null) items.add((Icons.storage_rounded, _fmt(material.fileSize!)));
    if (material.pageCount != null) items.add((Icons.menu_book_rounded, '${material.pageCount} pages'));
    if (material.durationSeconds != null) { final s = material.durationSeconds!;
      items.add((Icons.timer_rounded, '${s ~/ 60}m ${s % 60}s')); }
    final d = material.uploadedAt;
    items.add((Icons.calendar_today_rounded, 'Uploaded ${d.day}/${d.month}/${d.year}'));
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 14, runSpacing: 5, children: items.map((it) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(it.$1, size: 12, color: AppColors.textHint), const SizedBox(width: 4),
          Text(it.$2, style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
        ])).toList());
  }
}

class _OBtn extends StatelessWidget {
  final String url; final bool big; const _OBtn({required this.url, this.big = false});

  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (big) {
      return ElevatedButton.icon(onPressed: _open,
        icon: const Icon(Icons.open_in_new_rounded, size: 14), label: const Text('Open'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
            foregroundColor: Colors.white, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
    }
    return Material(color: AppColors.primary, borderRadius: BorderRadius.circular(7),
        child: InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), onTap: _open, borderRadius: BorderRadius.circular(7),
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.open_in_new_rounded, size: 12, color: Colors.white),
                  SizedBox(width: 5),
                  Text('Open', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ]))));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOPICS SIDEBAR
// ─────────────────────────────────────────────────────────────────────────────
class _TopicsSidebarWidget extends StatelessWidget {
  final List<TopicItem> topics; final bool loading;
  final void Function(TopicItem) onTopicTap;
  final VoidCallback onAddManual, onGenerateAI;
  const _TopicsSidebarWidget({required this.topics, required this.loading,
      required this.onTopicTap, required this.onAddManual, required this.onGenerateAI});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // header
      Container(padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _K.div))),
          child: Row(children: [
            Container(width: 24, height: 24, decoration: BoxDecoration(
                color: AppColors.primarySoft, borderRadius: BorderRadius.circular(7)),
                alignment: Alignment.center,
                child: const Icon(Icons.tag_rounded, size: 13, color: AppColors.primary)),
            const SizedBox(width: 8),
            const Text('Topics', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
            if (!loading && topics.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                  child: Text('${topics.length}', style: const TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primary))),
            ],
            const Spacer(),
            if (loading) const SizedBox(width: 13, height: 13,
                child: CircularProgressIndicator(strokeWidth: 1.5)),
          ])),

      // add buttons
      Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _K.div))),
        child: Row(children: [
          Expanded(child: _AddTopicBtnW(icon: Icons.edit_rounded, label: 'Manual',
              onTap: onAddManual, color: AppColors.primary, bg: _K.blueSoft)),
          const SizedBox(width: 6),
          Expanded(child: _AddTopicBtnW(icon: Icons.auto_awesome_rounded, label: 'AI',
              onTap: onGenerateAI, color: AppColors.primary, bg: AppColors.primarySoft)),
        ]),
      ),

      // list
      Expanded(child: loading
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(strokeWidth: 2), SizedBox(height: 8),
              Text('Loading topics…', style: TextStyle(fontSize: 13, color: AppColors.textMuted))]))
          : topics.isEmpty
              ? _TopicsEmptyW(onAddManual: onAddManual, onGenerateAI: onGenerateAI)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: topics.length,
                  itemBuilder: (_, i) => _TopicItemW(
                      topic: topics[i], index: i, onTap: () => onTopicTap(topics[i])))),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Unified "Add Topic" button — opens a tabbed dialog (Manual | AI)
// ─────────────────────────────────────────────────────────────────────────────
class _AddTopicUnifiedBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTopicUnifiedBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A137FEC),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 16, color: Colors.white),
              SizedBox(width: 5),
              Text(
                'Add Topic',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;
  final VoidCallback onTap;
  const _GhostActionButton({required this.icon, required this.label, required this.fg, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
          ]),
        ),
      ),
    );
  }
}


enum _TopicCreateMode { manual, ai }

class _TopicDialogResult {
  final String title;
  final _TopicCreateMode mode;
  final List<int> learningOutcomeIds;

  const _TopicDialogResult.manual(this.title, {this.learningOutcomeIds = const []})
      : mode = _TopicCreateMode.manual;
  const _TopicDialogResult.ai()
      : mode = _TopicCreateMode.ai,
        title = '',
        learningOutcomeIds = const [];
}

class _AddTopicDialogV2 extends StatefulWidget {
  final List<LearningOutcome> outcomes;
  const _AddTopicDialogV2({super.key, this.outcomes = const []});

  @override
  State<_AddTopicDialogV2> createState() => _AddTopicDialogV2State();
}

class _AddTopicDialogV2State extends State<_AddTopicDialogV2>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _titleCtrl = TextEditingController();
  bool _submitted = false;
  final Set<int> _selectedOutcomeIds = {};

  bool get _isManual => _tabController.index == 0;

  String? get _titleError {
    if (!_submitted) return null;
    if (_titleCtrl.text.trim().isEmpty) return 'Topic name is required';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isManual) {
      setState(() => _submitted = true);
      final title = _titleCtrl.text.trim();
      if (title.isEmpty) return;
      Navigator.pop(context, _TopicDialogResult.manual(title, learningOutcomeIds: _selectedOutcomeIds.toList()));
      return;
    }
    Navigator.pop(context, const _TopicDialogResult.ai());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 42,
                  spreadRadius: 2,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: _dialogTabs(),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _isManual ? _manualBody() : _aiBody(),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _K.div)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: _K.div),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: Icon(
                          _isManual ? Icons.add_rounded : Icons.auto_awesome_rounded,
                          size: 16,
                        ),
                        label: Text(_isManual ? 'Create Topic' : 'Generate with AI'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          backgroundColor: _isManual ? AppColors.primary : AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _K.div))),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.tag_rounded, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add Topic', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
            SizedBox(height: 2),
            Text('Create a clear topic manually or let AI structure it for you.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ]),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, size: 18),
          splashRadius: 20,
        ),
      ]),
    );
  }

  Widget _dialogTabs() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Color(0x12000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        labelPadding: EdgeInsets.zero,
        tabs: [
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.edit_rounded, size: 14,
                color: _isManual ? AppColors.primary : AppColors.textHint),
            const SizedBox(width: 6),
            Text('Manual', style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700,
                color: _isManual ? AppColors.primary : AppColors.textMuted)),
          ])),
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.auto_awesome_rounded, size: 14,
                color: !_isManual ? AppColors.primary : AppColors.textHint),
            const SizedBox(width: 6),
            Text('AI Generate', style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700,
                color: !_isManual ? AppColors.primary : AppColors.textMuted)),
          ])),
        ],
      ),
    );
  }

  Widget _manualBody() {
    final outcomes = widget.outcomes;
    return Column(
      key: const ValueKey('manual'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Topic name', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        TextField(
          controller: _titleCtrl,
          autofocus: true,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'e.g. Introduction to Robotics',
            errorText: _titleError,
            prefixIcon: const Icon(Icons.tag_rounded, size: 16, color: AppColors.primary),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _K.div)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _K.div)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.4)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        if (outcomes.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(children: [
            const Text('Link to Learning Outcomes',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            const SizedBox(width: 6),
            Text('(optional)',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted.withOpacity(0.7))),
          ]),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _K.div),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: outcomes.length,
                itemBuilder: (_, i) {
                  final lo = outcomes[i];
                  final selected = _selectedOutcomeIds.contains(lo.id);
                  Color dotColor;
                  switch (lo.difficulty) {
                    case OutcomeDifficulty.intermediate: dotColor = const Color(0xFFD97706); break;
                    case OutcomeDifficulty.advanced: dotColor = const Color(0xFFDC2626); break;
                    default: dotColor = const Color(0xFF16A34A);
                  }
                  return InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedOutcomeIds.remove(lo.id);
                      } else {
                        _selectedOutcomeIds.add(lo.id);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary.withOpacity(0.06) : Colors.transparent,
                        border: i < outcomes.length - 1
                            ? const Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))
                            : null,
                      ),
                      child: Row(children: [
                        Container(
                          width: 16, height: 16,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: selected ? AppColors.primary : const Color(0xFFCBD5E1),
                              width: 1.5,
                            ),
                          ),
                          child: selected
                              ? const Icon(Icons.check, size: 11, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 7, height: 7,
                          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.badgeBlueBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(lo.code,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.badgeBlueFg)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(lo.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: selected ? AppColors.textTitle : AppColors.textMuted,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            ))),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_selectedOutcomeIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${_selectedOutcomeIds.length} outcome${_selectedOutcomeIds.length == 1 ? '' : 's'} linked',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _K.blueSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _K.blueMid),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Use clear topic names so question generation and analytics stay well organized.',
              style: TextStyle(fontSize: 13, height: 1.5,
                  color: AppColors.primary, fontWeight: FontWeight.w500),
            )),
          ]),
        ),
      ],
    );
  }

  Widget _aiBody() {
    return Column(
      key: const ValueKey('ai'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x33137FEC)),
          ),
          child: Column(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(height: 12),
            const Text('Generate Topics with AI', style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
            const SizedBox(height: 6),
            const Text(
              'AI will analyze the selected material and extract suggested topics automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.textMuted),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _K.div),
          ),
          child: const Row(children: [
            Icon(Icons.bolt_rounded, size: 15, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(child: Text(
              'You can review and refine the generated topics later.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            )),
          ]),
        ),
      ],
    );
  }
}



bool _isDangerActionColor(Color color) => color.red >= 180 && color.green <= 120;

class _PreferencesDialogShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final Widget? leading;

  const _PreferencesDialogShell({
    required this.title,
    required this.child,
    this.subtitle,
    this.maxWidth = 620,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 20),
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textTitle,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.45,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool multiline;
  final bool autofocus;

  const _DialogTextField({
    required this.controller,
    required this.hintText,
    this.multiline = false,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: multiline ? 104 : 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: multiline ? 14 : 0,
      ),
      alignment: multiline ? Alignment.topLeft : Alignment.centerLeft,
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        minLines: multiline ? 4 : 1,
        maxLines: multiline ? 5 : 1,
        style: AppText.input,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppText.hint,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _DialogActions extends StatelessWidget {
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;
  final AppButtonVariant confirmVariant;

  const _DialogActions({
    this.cancelLabel = 'Cancel',
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.confirmVariant = AppButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: cancelLabel,
            onTap: onCancel,
            variant: AppButtonVariant.soft,
            fullWidth: true,
            height: 40,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppButton(
            label: confirmLabel,
            onTap: onConfirm,
            variant: confirmVariant,
            fullWidth: true,
            height: 40,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ShareModuleDialog — lets the instructor choose the target course
// ─────────────────────────────────────────────────────────────────────────────
final _shareTargetCoursesProvider = FutureProvider.family<List<MyCourseItem>, int>((ref, currentCourseId) async {
  final res = await ref.read(coursesApiProvider).myCourses();
  final items = [...res.items]
    ..removeWhere((course) => course.id == currentCourseId)
    ..sort((a, b) => a.safeTitle.toLowerCase().compareTo(b.safeTitle.toLowerCase()));
  return items;
});

class _ShareModuleDialog extends ConsumerStatefulWidget {
  final ModuleItem module;
  final int currentCourseId;
  const _ShareModuleDialog({required this.module, required this.currentCourseId, super.key});

  @override
  ConsumerState<_ShareModuleDialog> createState() => _ShareModuleDialogState();
}

class _ShareModuleDialogState extends ConsumerState<_ShareModuleDialog> {
  MyCourseItem? _selectedCourse;

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(_shareTargetCoursesProvider(widget.currentCourseId));
    return _PreferencesDialogShell(
      title: 'Share with Another Course',
      subtitle: 'Choose which course should receive a copied module',
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.copy_all_rounded, size: 18, color: Color(0xFF7C3AED)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.folder_rounded, size: 18, color: Color(0xFF137FEC)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.module.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
                  if (widget.module.description != null && widget.module.description!.isNotEmpty)
                    Text(widget.module.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          coursesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Text('Could not load your courses: $error', style: const TextStyle(fontSize: 13, color: Color(0xFF9F1239))),
            ),
            data: (courses) {
              if (courses.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text('No other instructor courses are available for sharing yet.', style: TextStyle(fontSize: 13, color: Color(0xFF92400E))),
                );
              }

              _selectedCourse ??= courses.first;
              final currentValue = courses.contains(_selectedCourse) ? _selectedCourse! : courses.first;
              return AppModernDropdown<MyCourseItem>(
                label: 'Target course',
                value: currentValue,
                items: [
                  for (final course in courses)
                    DropdownMenuItem<MyCourseItem>(
                      value: course,
                      child: Text(course.safeTitle, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() => _selectedCourse = value),
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Expanded(child: Text(
                'This creates an independent copy in the selected course using the current backend copy endpoint.',
                style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF92400E)),
              )),
            ]),
          ),
          const SizedBox(height: 20),
          _DialogActions(
            onCancel: () => Navigator.pop(context),
            onConfirm: _selectedCourse == null ? null : () => Navigator.pop(context, _selectedCourse),
            confirmLabel: 'Copy Module',
          ),
        ],
      ),
    );
  }
}

class _DescriptionDialog extends StatelessWidget {
  final TextEditingController ctrl;
  const _DescriptionDialog({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return _PreferencesDialogShell(
      title: 'Edit Description',
      subtitle: 'Update the module description shown in preferences and sharing flows.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DialogTextField(
            controller: ctrl,
            hintText: 'Write a short helpful description',
            multiline: true,
          ),
          const SizedBox(height: 16),
          _DialogActions(
            onCancel: () => Navigator.pop(context, false),
            onConfirm: () => Navigator.pop(context, true),
            confirmLabel: 'Save',
          ),
        ],
      ),
    );
  }
}

class _ChangeModulePositionDialog extends StatefulWidget {
  final ModuleItem module;
  final List<ModuleItem> modules;
  const _ChangeModulePositionDialog({required this.module, required this.modules});

  @override
  State<_ChangeModulePositionDialog> createState() => _ChangeModulePositionDialogState();
}

class _ChangeModulePositionDialogState extends State<_ChangeModulePositionDialog> {
  late int _selectedPosition = widget.module.orderIndex + 1;

  @override
  Widget build(BuildContext context) {
    return _PreferencesDialogShell(
      title: 'Change Position',
      subtitle: 'Move "${widget.module.title}" to a new order inside this course.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppModernDropdown<int>(
            label: 'Position',
            value: _selectedPosition,
            items: [
              for (var i = 0; i < widget.modules.length; i++)
                DropdownMenuItem<int>(
                  value: i + 1,
                  child: Text('#${i + 1}'),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selectedPosition = value);
            },
          ),
          const SizedBox(height: 16),
          _DialogActions(
            onCancel: () => Navigator.pop(context),
            onConfirm: () => Navigator.pop(context, _selectedPosition),
            confirmLabel: 'Save',
          ),
        ],
      ),
    );
  }
}

class _ManualTabContent extends StatelessWidget {
  final TextEditingController ctrl;
  final String? error;
  const _ManualTabContent({required this.ctrl, this.error, super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink(); // unused, kept for compat
}

class _AITabContent extends StatelessWidget {
  const _AITabContent({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink(); // unused, kept for compat
}


class _AddTopicBtnW extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  final Color color, bg;
  const _AddTopicBtnW({required this.icon, required this.label, required this.onTap,
      required this.color, required this.bg});
  @override
  Widget build(BuildContext context) => InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), onTap: onTap,
      borderRadius: BorderRadius.circular(7), child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 13, color: color), const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ])));
}

class _TopicsEmptyW extends StatelessWidget {
  final VoidCallback onAddManual, onGenerateAI;
  const _TopicsEmptyW({required this.onAddManual, required this.onGenerateAI});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.tag_rounded, size: 22, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          const Text('No topics yet',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
          const SizedBox(height: 6),
          const Text(
            'Use the "Add Topic" button above\nto create topics manually or with AI.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.6),
          ),
        ],
      ),
    ),
  );
}

class _TopicItemW extends StatelessWidget {
  final TopicItem topic; final int index; final VoidCallback onTap;
  const _TopicItemW({required this.topic, required this.index, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final readiness = _topicReadinessMeta(topic.readiness);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8ECF2)),
            boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF)]),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text('${index + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(topic.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
              const SizedBox(height: 7),
              Wrap(spacing: 6, runSpacing: 6, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: readiness.bg, borderRadius: BorderRadius.circular(999)),
                  child: Text(readiness.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: readiness.fg)),
                ),
                if (topic.estimatedDurationMinutes != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(999)),
                    child: Text('~${topic.estimatedDurationMinutes} min', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                  ),
                if (topic.learningOutcomeIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(999)),
                    child: Text('${topic.learningOutcomeIds.length} LO${topic.learningOutcomeIds.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
              ]),
            ])),
            const SizedBox(width: 8),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.textHint),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOPIC DRILL-DOWN PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _TopicPanelWidget extends StatelessWidget {
  final ModuleItem module;
  final MaterialItem material;
  final TopicItem topic;
  final List<TopicItem> allMaterialTopics;
  final List<LearningOutcome> outcomes;
  final bool canPop;
  final VoidCallback onBack, onGenerate, onAddManualQuestion, onEditTopic, onAddSubtopic;
  final ValueChanged<TopicItem> onOpenSubtopic;

  const _TopicPanelWidget({
    required this.module,
    required this.material,
    required this.topic,
    required this.allMaterialTopics,
    required this.outcomes,
    required this.canPop,
    required this.onBack,
    required this.onGenerate,
    required this.onAddManualQuestion,
    required this.onEditTopic,
    required this.onAddSubtopic,
    required this.onOpenSubtopic,
  });

  @override
  Widget build(BuildContext context) {
    final mappedOutcomes = outcomes
        .where((o) => topic.linkedOutcomeIds.contains(o.id.toString()) || topic.linkedOutcomeId == o.id.toString())
        .toList();

    final readinessMeta = _topicReadinessMeta(topic.readiness);
    final difficultyMeta = _topicDifficultyMeta(topic.difficulty);

    final subtopics = allMaterialTopics
        .where((t) => t.parentTopicId == topic.id)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));


    final actionCards = [
      _TopicActionData(
        icon: Icons.auto_awesome_rounded,
        title: 'Generate questions',
        subtitle: 'Open scoped AI generation with this topic as the anchor.',
        accent: AppColors.primary,
        softColor: AppColors.primarySoft,
        onTap: onGenerate,
      ),
      _TopicActionData(
        icon: Icons.edit_note_rounded,
        title: 'Draft manual question',
        subtitle: 'Create a hand-authored question tied directly to this topic.',
        accent: _K.blue,
        softColor: _K.blueSoft,
        onTap: onAddManualQuestion,
      ),
      _TopicActionData(
        icon: Icons.tune_rounded,
        title: 'Refine topic setup',
        subtitle: 'Update title, mappings, notes, and delivery status.',
        accent: _K.green,
        softColor: _K.greenSoft,
        onTap: onEditTopic,
      ),
    ];

    final timeline = [
      const _TimelineEntry(
        icon: Icons.add_task_rounded,
        title: 'Topic created',
        subtitle: 'Structured under this material and ready for instructor refinement.',
      ),
      _TimelineEntry(
        icon: Icons.flag_outlined,
        title: mappedOutcomes.isEmpty ? 'Outcome mapping pending' : 'Outcome alignment in place',
        subtitle: mappedOutcomes.isEmpty
            ? 'Use Manage to connect this topic to one or more course outcomes.'
            : '${mappedOutcomes.length} mapped outcome(s) are already linked to this topic.',
      ),
      _TimelineEntry(
        icon: topic.readiness == TopicReadiness.ready ? Icons.rocket_launch_rounded : Icons.rule_folder_outlined,
        title: topic.readiness == TopicReadiness.ready ? 'Delivery-ready topic' : 'Preparation still in progress',
        subtitle: topic.readiness == TopicReadiness.ready
            ? 'This topic can move straight into assessment and delivery workflows.'
            : 'Keep refining content, notes, and alignment before live delivery.',
      ),
    ];

    return Container(
      color: _K.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: _K.div)),
            ),
            child: Row(
              children: [
                if (canPop)
                  InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
                    onTap: onBack,
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _K.bg,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: _K.div),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_back_ios_new_rounded, size: 11, color: AppColors.textMuted),
                          const SizedBox(width: 5),
                          Text(
                            material.displayTitle,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (canPop) const SizedBox(width: 10),
                const Icon(Icons.tag_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    topic.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTitle,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onEditTopic,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Manage'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopicHeroCard(
                    module: module,
                    material: material,
                    topic: topic,
                    mappedOutcomesCount: mappedOutcomes.length,
                    readinessMeta: readinessMeta,
                    difficultyMeta: difficultyMeta,
                    onManage: onEditTopic,
                  ),
                  const SizedBox(height: 18),
                  _TopicInsightsGrid(
                    topic: topic,
                    mappedOutcomesCount: mappedOutcomes.length,
                    readinessMeta: readinessMeta,
                    difficultyMeta: difficultyMeta,
                  ),
                  const SizedBox(height: 18),
                  _TopicSmartActionsCard(actions: actionCards),
                  const SizedBox(height: 18),
                  if (topic.description?.isNotEmpty ?? false) ...[
                    _CardWidget(
                      header: const _HdrWidget(
                        icon: Icons.description_outlined,
                        iconColor: AppColors.primary,
                        title: 'Topic Brief',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Text(
                          topic.description!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _CardWidget(
                    header: const _HdrWidget(
                      icon: Icons.flag_outlined,
                      iconColor: AppColors.primary,
                      title: 'Learning Outcome Alignment',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: mappedOutcomes.isEmpty
                          ? const Text(
                              'This topic is not mapped yet. Use Manage to align it to one or more course outcomes.',
                              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: mappedOutcomes
                                  .map(
                                    (lo) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _K.blueSoft,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: _K.blueMid),
                                      ),
                                      child: Text(
                                        '${lo.code} • ${lo.description}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _CardWidget(
                    header: const _HdrWidget(
                      icon: Icons.sticky_note_2_outlined,
                      iconColor: AppColors.primary,
                      title: 'Instructor Notes',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: Text(
                        (topic.instructorNotes?.trim().isNotEmpty ?? false)
                            ? topic.instructorNotes!.trim()
                            : 'No notes yet. Use Manage to add delivery notes, examples, or assessment guidance.',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TopicSubtopicsCard(
                    topic: topic,
                    subtopics: subtopics,
                    onAddSubtopic: onAddSubtopic,
                    onOpenSubtopic: onOpenSubtopic,
                  ),
                  const SizedBox(height: 16),
                  _TopicTimelineCard(entries: timeline),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class _TopicSubtopicsCard extends StatelessWidget {
  final TopicItem topic;
  final List<TopicItem> subtopics;
  final VoidCallback onAddSubtopic;
  final ValueChanged<TopicItem> onOpenSubtopic;

  const _TopicSubtopicsCard({
    required this.topic,
    required this.subtopics,
    required this.onAddSubtopic,
    required this.onOpenSubtopic,
  });

  @override
  Widget build(BuildContext context) {
    return _CardWidget(
      header: _HdrWidget(
        icon: Icons.account_tree_outlined,
        iconColor: AppColors.primary,
        title: 'Subtopics',
        trailing: ElevatedButton.icon(
          onPressed: onAddSubtopic,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add Subtopic'),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: subtopics.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No subtopics yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTitle,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Break "${topic.title}" into smaller teaching units so questions and notes stay organized.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: onAddSubtopic,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Create first subtopic'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  for (final subtopic in subtopics) ...[
                    InkWell(
                      hoverColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onOpenSubtopic(subtopic),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF3FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.subdirectory_arrow_right_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subtopic.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textTitle,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${subtopic.difficulty.label} • ${subtopic.readiness.label}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
      ),
    );
  }
}

class _TopicHeroCard extends StatelessWidget {
  final ModuleItem module;
  final MaterialItem material;
  final TopicItem topic;
  final int mappedOutcomesCount;
  final _TopicMeta readinessMeta;
  final _TopicMeta difficultyMeta;
  final VoidCallback onManage;

  const _TopicHeroCard({
    required this.module,
    required this.material,
    required this.topic,
    required this.mappedOutcomesCount,
    required this.readinessMeta,
    required this.difficultyMeta,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final created = '${topic.createdAt.day}/${topic.createdAt.month}/${topic.createdAt.year}';
    final statusChips = [
      const _TopicStatusChip(icon: Icons.sell_outlined, label: 'Topic', fg: AppColors.primary, bg: AppColors.primarySoft),
      if (topic.isRequired)
        const _TopicStatusChip(icon: Icons.check_circle_outline_rounded, label: 'Required', fg: _K.blue, bg: _K.blueSoft),
      _TopicStatusChip(icon: readinessMeta.icon, label: readinessMeta.label, fg: readinessMeta.fg, bg: readinessMeta.bg),
      _TopicStatusChip(icon: difficultyMeta.icon, label: difficultyMeta.label, fg: difficultyMeta.fg, bg: difficultyMeta.bg),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A1D4ED8),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: statusChips),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.14)),
                  ),
                  child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _TopicBreadcrumb(icon: Icons.folder_outlined, text: module.title),
                          _TopicBreadcrumb(icon: Icons.article_outlined, text: material.displayTitle),
                          _TopicBreadcrumb(icon: Icons.calendar_today_outlined, text: 'Created $created'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: onManage,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF111827),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _HeroStat(
                    label: 'Mapped outcomes',
                    value: mappedOutcomesCount == 0 ? 'Unmapped' : '$mappedOutcomesCount linked',
                    helper: mappedOutcomesCount == 0 ? 'Needs alignment' : 'Aligned with course goals',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeroStat(
                    label: 'Question workflow',
                    value: topic.readiness == TopicReadiness.ready ? 'Generation-ready' : 'Preparation mode',
                    helper: topic.readiness == TopicReadiness.ready ? 'Safe to build assessment coverage' : 'Refine topic first',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeroStat(
                    label: 'Topic type',
                    value: topic.source == TopicSource.ai ? 'AI-assisted' : 'Instructor-led',
                    helper: topic.source == TopicSource.ai ? 'Generated from material context' : 'Created manually',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicInsightsGrid extends StatelessWidget {
  final TopicItem topic;
  final int mappedOutcomesCount;
  final _TopicMeta readinessMeta;
  final _TopicMeta difficultyMeta;

  const _TopicInsightsGrid({
    required this.topic,
    required this.mappedOutcomesCount,
    required this.readinessMeta,
    required this.difficultyMeta,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _TopicInsightData(
        title: 'Delivery status',
        value: readinessMeta.label,
        caption: topic.readiness == TopicReadiness.ready
            ? 'Ready for live teaching'
            : topic.readiness == TopicReadiness.review
                ? 'Needs final QA pass'
                : 'Still being prepared',
        icon: readinessMeta.icon,
        accent: readinessMeta.fg,
        softColor: readinessMeta.bg,
      ),
      _TopicInsightData(
        title: 'Difficulty',
        value: difficultyMeta.label,
        caption: topic.difficulty == TopicDifficulty.beginner
            ? 'Accessible introduction'
            : topic.difficulty == TopicDifficulty.intermediate
                ? 'Balanced depth'
                : 'Advanced treatment',
        icon: difficultyMeta.icon,
        accent: difficultyMeta.fg,
        softColor: difficultyMeta.bg,
      ),
      _TopicInsightData(
        title: 'Outcome coverage',
        value: mappedOutcomesCount == 0 ? 'Pending' : '$mappedOutcomesCount linked',
        caption: mappedOutcomesCount == 0
            ? 'No outcome alignment yet'
            : 'Connected to measurable outcomes',
        icon: Icons.flag_outlined,
        accent: _K.blue,
        softColor: _K.blueSoft,
      ),
      _TopicInsightData(
        title: 'Instructor notes',
        value: (topic.instructorNotes?.trim().isNotEmpty ?? false) ? 'Available' : 'Missing',
        caption: (topic.instructorNotes?.trim().isNotEmpty ?? false)
            ? 'Delivery guidance has been added'
            : 'Add notes for examples and pacing',
        icon: Icons.sticky_note_2_outlined,
        accent: AppColors.primary,
        softColor: AppColors.primarySoft,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100
            ? 4
            : constraints.maxWidth > 760
                ? 2
                : 1;
        final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 14) / crossAxisCount;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: cards
              .map((card) => SizedBox(
                    width: itemWidth,
                    child: _TopicInsightCard(data: card),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _TopicInsightCard extends StatelessWidget {
  final _TopicInsightData data;

  const _TopicInsightCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _CardWidget(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: data.softColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(data.icon, color: data.accent, size: 20),
            ),
            const SizedBox(height: 14),
            Text(
              data.title,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              data.value,
              style: const TextStyle(fontSize: 16, color: AppColors.textTitle, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              data.caption,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicSmartActionsCard extends StatelessWidget {
  final List<_TopicActionData> actions;

  const _TopicSmartActionsCard({required this.actions});

  @override
  Widget build(BuildContext context) {
    return _CardWidget(
      header: const _HdrWidget(
        icon: Icons.bolt_rounded,
        iconColor: AppColors.primary,
        title: 'Smart Actions',
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          children: actions
              .map(
                (action) => Padding(
                  padding: EdgeInsets.only(bottom: action == actions.last ? 0 : 12),
                  child: _TopicActionTile(data: action),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _TopicActionTile extends StatelessWidget {
  final _TopicActionData data;

  const _TopicActionTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: data.softColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(data.icon, color: data.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textTitle),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.subtitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_outward_rounded, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _TopicTimelineCard extends StatelessWidget {
  final List<_TimelineEntry> entries;

  const _TopicTimelineCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return _CardWidget(
      header: const _HdrWidget(
        icon: Icons.timeline_rounded,
        iconColor: AppColors.primary,
        title: 'Delivery Timeline',
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
        child: Column(
          children: List.generate(entries.length, (index) {
            final entry = entries[index];
            final isLast = index == entries.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(entry.icon, color: AppColors.primary, size: 16),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 42,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          color: const Color(0xFFE2E8F0),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textTitle),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.subtitle,
                          style: const TextStyle(fontSize: 12.3, color: AppColors.textMuted, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _TopicStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;

  const _TopicStatusChip({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(bg == Colors.white ? 1 : 0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg, letterSpacing: .2),
          ),
        ],
      ),
    );
  }
}

class _TopicBreadcrumb extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TopicBreadcrumb({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white70),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 12.5, color: Colors.white70, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final String helper;

  const _HeroStat({
    required this.label,
    required this.value,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(helper, style: const TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.4)),
        ],
      ),
    );
  }
}

class _TopicMeta {
  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;

  const _TopicMeta({
    required this.label,
    required this.icon,
    required this.fg,
    required this.bg,
  });
}

class _TopicInsightData {
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color accent;
  final Color softColor;

  const _TopicInsightData({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.accent,
    required this.softColor,
  });
}

class _TopicActionData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color softColor;
  final VoidCallback onTap;

  const _TopicActionData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.softColor,
    required this.onTap,
  });
}

class _TimelineEntry {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TimelineEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

_TopicMeta _topicReadinessMeta(TopicReadiness readiness) {
  switch (readiness) {
    case TopicReadiness.ready:
      return const _TopicMeta(
        label: 'Ready',
        icon: Icons.check_circle_rounded,
        fg: _K.green,
        bg: _K.greenSoft,
      );
    case TopicReadiness.review:
      return const _TopicMeta(
        label: 'Needs Review',
        icon: Icons.pending_actions_rounded,
        fg: _K.amber,
        bg: _K.amberSoft,
      );
    case TopicReadiness.draft:
      return const _TopicMeta(
        label: 'Draft',
        icon: Icons.edit_note_rounded,
        fg: AppColors.textMuted,
        bg: Color(0xFFF1F5F9),
      );
  }
}

_TopicMeta _topicDifficultyMeta(TopicDifficulty difficulty) {
  switch (difficulty) {
    case TopicDifficulty.beginner:
      return const _TopicMeta(
        label: 'Beginner',
        icon: Icons.wb_sunny_outlined,
        fg: _K.blue,
        bg: _K.blueSoft,
      );
    case TopicDifficulty.intermediate:
      return const _TopicMeta(
        label: 'Intermediate',
        icon: Icons.stacked_bar_chart_rounded,
        fg: _K.amber,
        bg: _K.amberSoft,
      );
    case TopicDifficulty.advanced:
      return const _TopicMeta(
        label: 'Advanced',
        icon: Icons.local_fire_department_outlined,
        fg: Color(0xFFDC2626),
        bg: Color(0xFFFEF2F2),
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DIALOGS
// ─────────────────────────────────────────────────────────────────────────────
class _ModuleDialogWidget extends StatelessWidget {
  final TextEditingController titleCtrl, descCtrl;
  const _ModuleDialogWidget({required this.titleCtrl, required this.descCtrl});
  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: const Row(children: [Icon(Icons.add_box_outlined, size: 18, color: AppColors.primary),
        SizedBox(width: 8), Text('New Module', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))]),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: titleCtrl, autofocus: true, decoration: InputDecoration(
          hintText: 'e.g. Lecture 1: Introduction', labelText: 'Title *',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
      const SizedBox(height: 12),
      TextField(controller: descCtrl, maxLines: 2, decoration: InputDecoration(
          hintText: 'Optional description', labelText: 'Description',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
          onPressed: () { if (titleCtrl.text.trim().isEmpty) return; Navigator.pop(context, true); },
          child: const Text('Create')),
    ]);
}

class _AddTopicDialogWidget extends StatefulWidget {
  final String moduleTitle;
  final TextEditingController titleCtrl, descCtrl;
  final ValueChanged<TopicDifficulty> onDifficultyChanged;
  const _AddTopicDialogWidget({required this.moduleTitle, required this.titleCtrl,
      required this.descCtrl, required this.onDifficultyChanged});
  @override
  State<_AddTopicDialogWidget> createState() => _AddTopicDialogWidgetState();
}

class _AddTopicDialogWidgetState extends State<_AddTopicDialogWidget> {
  TopicDifficulty _diff = TopicDifficulty.beginner;

  static const _diffColors = {
    TopicDifficulty.beginner:     (Color(0xFF16A34A), Color(0xFFDCFCE7)),
    TopicDifficulty.intermediate: (Color(0xFFD97706), Color(0xFFFEF3C7)),
    TopicDifficulty.advanced:     (Color(0xFFDC2626), Color(0xFFFEE2E2)),
  };

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(Icons.tag_rounded, size: 17, color: AppColors.primary), SizedBox(width: 8),
          Text('Add Topic', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))]),
      const SizedBox(height: 3),
      Text('in "${widget.moduleTitle}"', style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w400)),
    ]),
    content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.fromLTRB(12, 10, 12, 10), margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Color(0x33137FEC))),
          child: const Row(children: [Icon(Icons.auto_awesome_rounded, size: 15, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(child: Text('Tip: Use AI to auto-generate topics from your PDF.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.w500, height: 1.4)))])),
      TextField(controller: widget.titleCtrl, autofocus: true, decoration: InputDecoration(
          hintText: 'e.g. Introduction to Cryptography', labelText: 'Topic Title *',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
      const SizedBox(height: 12),
      TextField(controller: widget.descCtrl, maxLines: 2, decoration: InputDecoration(
          hintText: 'Optional description…', labelText: 'Description',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
      const SizedBox(height: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Difficulty', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        Row(children: TopicDifficulty.values.map((d) {
          final (fg, bg) = _diffColors[d]!;
          final sel = _diff == d;
          final isLast = d == TopicDifficulty.advanced;
          return Expanded(child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 8),
            child: GestureDetector(
              onTap: () { setState(() => _diff = d); widget.onDifficultyChanged(d); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? bg : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? fg : const Color(0xFFE2E8F0), width: sel ? 1.5 : 1),
                ),
                child: Center(child: Text(d.label,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: sel ? fg : AppColors.textMuted))),
              ),
            ),
          ));
        }).toList()),
      ]),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
          onPressed: () {
            if (widget.titleCtrl.text.trim().isEmpty) return;
            Navigator.pop(context, {'difficulty': _diff});
          },
          child: const Text('Add Topic')),
    ]);
}

class _SimpleDialog extends StatelessWidget {
  final String title, confirm; final TextEditingController ctrl; final Color confirmColor;
  const _SimpleDialog({required this.title, required this.ctrl, required this.confirm, required this.confirmColor});
  @override
  Widget build(BuildContext context) => _PreferencesDialogShell(
    title: title,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DialogTextField(
          controller: ctrl,
          hintText: 'Enter value',
          autofocus: true,
        ),
        const SizedBox(height: 16),
        _DialogActions(
          onCancel: () => Navigator.pop(context, false),
          onConfirm: () => Navigator.pop(context, true),
          confirmLabel: confirm,
          confirmVariant: _isDangerActionColor(confirmColor) ? AppButtonVariant.danger : AppButtonVariant.primary,
        ),
      ],
    ),
  );
}

class _ConfirmDialogWidget extends StatelessWidget {
  final String title, body, confirm; final Color confirmColor;
  const _ConfirmDialogWidget({required this.title, required this.body, required this.confirm, required this.confirmColor});
  @override
  Widget build(BuildContext context) => _PreferencesDialogShell(
    title: title,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(body, style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textMuted)),
        const SizedBox(height: 16),
        _DialogActions(
          onCancel: () => Navigator.pop(context, false),
          onConfirm: () => Navigator.pop(context, true),
          confirmLabel: confirm,
          confirmVariant: _isDangerActionColor(confirmColor) ? AppButtonVariant.danger : AppButtonVariant.primary,
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED MICRO WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
//  Module Actions Grid — replaces the vertical list with a 2-col card grid
// ─────────────────────────────────────────────────────────────────────────────
class _ModuleActionsGrid extends StatelessWidget {
  final ModuleItem module;
  final bool uploading;
  final VoidCallback? onRename, onTogglePublish, onUpload, onShare, onDelete;

  const _ModuleActionsGrid({
    required this.module,
    required this.uploading,
    this.onRename,
    this.onTogglePublish,
    this.onUpload,
    this.onShare,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPublished = module.isPublished;

    final actions = [
      _ActionCardData(
        icon: Icons.drive_file_rename_outline_rounded,
        iconColor: AppColors.primary,
        iconBg: _K.blueSoft,
        label: 'Rename',
        onTap: onRename,
      ),
      _ActionCardData(
        icon: isPublished ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        iconColor: isPublished ? _K.amber : _K.green,
        iconBg: isPublished ? _K.amberSoft : _K.greenSoft,
        label: isPublished ? 'Unpublish' : 'Publish',
        onTap: onTogglePublish,
      ),
      _ActionCardData(
        icon: Icons.upload_file_rounded,
        iconColor: AppColors.primary,
        iconBg: AppColors.primarySoft,
        label: 'Upload',
        onTap: uploading ? null : onUpload,
      ),
      const _ActionCardData(
        icon: Icons.swap_vert_rounded,
        iconColor: _K.green,
        iconBg: _K.greenSoft,
        label: 'Reorder',
      ),
      _ActionCardData(
        icon: Icons.share_rounded,
        iconColor: const Color(0xFF0EA5E9),
        iconBg: const Color(0xFFE0F2FE),
        label: 'Share',
        onTap: onShare,
      ),
      _ActionCardData(
        icon: Icons.delete_outline_rounded,
        iconColor: const Color(0xFFEF4444),
        iconBg: const Color(0xFFFEE2E2),
        label: 'Delete',
        onTap: onDelete,
        danger: true,
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      // 3 columns on wide, 2 on narrow
      final cols = c.maxWidth > 600 ? 3 : 2;
      const gap = 10.0;
      final cardW = (c.maxWidth - gap * (cols - 1)) / cols;

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: actions
            .map((a) => SizedBox(width: cardW, child: _ActionCard(data: a)))
            .toList(),
      );
    });
  }
}

class _ActionCardData {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  const _ActionCardData({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    this.onTap,
    this.danger = false,
  });
}

class _ActionCard extends StatefulWidget {
  final _ActionCardData data;
  const _ActionCard({required this.data});

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final disabled = d.onTap == null;
    final hoverBorderColor = d.danger
        ? const Color(0xFFFCA5A5)
        : d.iconColor.withOpacity(0.3);
    final hoverBg = d.danger
        ? const Color(0xFFFFF5F5)
        : d.iconColor.withOpacity(0.04);

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) { if (!disabled) setState(() => _hovered = true); },
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: d.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            color: _hovered ? hoverBg : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? hoverBorderColor : _K.div,
              width: _hovered ? 1.5 : 1.0,
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: d.iconColor.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 3))]
                : [const BoxShadow(color: Color(0x07000000), blurRadius: 4, offset: Offset(0, 1))],
          ),
          child: Opacity(
            opacity: disabled ? 0.4 : 1.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _hovered
                        ? d.iconColor.withOpacity(0.15)
                        : d.iconBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Icon(d.icon, size: 17, color: d.iconColor),
                ),
                const SizedBox(height: 10),
                Text(
                  d.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: d.danger
                        ? const Color(0xFFDC2626)
                        : (_hovered ? d.iconColor : AppColors.textTitle),
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

class _CardWidget extends StatelessWidget {
  final Widget child; final _HdrWidget? header; final bool noPadding;
  const _CardWidget({required this.child, this.header, this.noPadding = false});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _K.div), boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 8, offset: Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (header != null) ...[header!, const Divider(height: 1, color: _K.div)],
      child,
    ]));
}

class _HdrWidget extends StatelessWidget {
  final IconData icon; final Color iconColor; final String title;
  final String? badge; final Widget? trailing;
  const _HdrWidget({required this.icon, required this.iconColor, required this.title,
      this.badge, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
    child: Row(children: [
      Icon(icon, size: 14, color: iconColor), const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
      if (badge != null) ...[const SizedBox(width: 7),
        Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: _K.blueSoft, borderRadius: BorderRadius.circular(10)),
            child: Text(badge!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)))],
      const Spacer(), if (trailing != null) trailing!,
    ]));
}

class _SmBtn extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final bool disabled;
  const _SmBtn({required this.icon, required this.label, required this.onTap, this.disabled = false});
  @override
  Widget build(BuildContext context) => InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), onTap: disabled ? null : onTap,
    borderRadius: BorderRadius.circular(7), child: Opacity(opacity: disabled ? 0.4 : 1.0,
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: _K.blueSoft, borderRadius: BorderRadius.circular(7)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: AppColors.primary), const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ]))));
}

class _Pill extends StatelessWidget {
  final String l; final Color fg, bg; const _Pill({required this.l, required this.fg, required this.bg});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(l, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg, letterSpacing: 0.1)));
}

class _PRow extends StatefulWidget {
  final IconData icon; final Color iconBg, iconFg;
  final String label, sub; final VoidCallback? onTap; final bool danger;
  const _PRow({required this.icon, required this.iconBg, required this.iconFg,
      required this.label, required this.sub, this.onTap, this.danger = false});
  @override
  State<_PRow> createState() => _PRowState();
}

class _PRowState extends State<_PRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    final textColor = widget.danger ? const Color(0xFFDC2626) : AppColors.textTitle;
    final iconColor = disabled ? AppColors.textHint : widget.iconFg;

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) { if (!disabled) setState(() => _hovered = true); },
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: Colors.transparent,
          padding: const EdgeInsets.fromLTRB(18, 11, 16, 11),
          child: Opacity(
            opacity: disabled ? 0.4 : 1.0,
            child: Row(children: [
              // Small icon — not a big chunky box
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: _hovered && !disabled
                      ? widget.iconFg.withOpacity(0.12)
                      : widget.iconBg.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Icon(widget.icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.label, style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _hovered && !disabled && !widget.danger
                      ? AppColors.primary
                      : textColor,
                )),
                const SizedBox(height: 1),
                Text(widget.sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ])),
              // Arrow only visible on hover
              AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: _hovered && !disabled ? 1.0 : 0.0,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: widget.danger
                      ? const Color(0xFFDC2626)
                      : AppColors.primary,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DivW extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: _K.div, indent: 16, endIndent: 16);
}

class _MRowW extends StatelessWidget {
  final IconData icon; final String label, value; final bool isLast;
  const _MRowW({required this.icon, required this.label, required this.value, this.isLast = false});
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: Row(children: [
      Icon(icon, size: 13, color: AppColors.textHint), const SizedBox(width: 8),
      SizedBox(width: 110, child: Text(label, style: const TextStyle(
          fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500))),
      Expanded(child: Text(value, style: const TextStyle(
          fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textTitle))),
    ])),
    if (!isLast) const Divider(height: 1, color: _K.div, indent: 16, endIndent: 16),
  ]);
}

class _TIcon extends StatelessWidget {
  final String type; final double size; const _TIcon({required this.type, this.size = 40});
  static const _m = {
    'video': (Icons.play_circle_filled_rounded, Color(0xFFDBEAFE), Color(0xFF2563EB)),
    'pdf'  : (Icons.picture_as_pdf_rounded,     Color(0xFFFEE2E2), Color(0xFFDC2626)),
    'quiz' : (Icons.quiz_rounded,                Color(0xFFF3E8FF), Color(0xFF9333EA)),
  };
  @override
  Widget build(BuildContext context) {
    final (ico, bg, fg) = _m[type] ??
        (Icons.insert_drive_file_rounded, const Color(0xFFF1F5F9), AppColors.textMuted);
    return Container(width: size, height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
        child: Icon(ico, size: size * 0.48, color: fg));
  }
}

class _Dot extends StatelessWidget {
  final String status; const _Dot({required this.status});
  @override
  Widget build(BuildContext context) {
    final c = switch (status) {
      'ready'       => _K.green,
      'processing'  => _K.amber,
      'uploaded'    => _K.amber,
      'draft_upload'=> const Color(0xFF0369A1),
      'error'       => AppColors.dangerText,
      _             => AppColors.textHint,
    };
    return Container(width: 6, height: 6, margin: const EdgeInsets.only(left: 5),
        decoration: BoxDecoration(color: c, shape: BoxShape.circle));
  }
}

class _IBtn extends StatelessWidget {
  final IconData icon; final String tooltip; final VoidCallback onTap;
  const _IBtn({required this.icon, required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(message: tooltip, child: InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), onTap: onTap,
      borderRadius: BorderRadius.circular(6), child: Padding(padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 14, color: AppColors.textHint))));
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final bool disabled;
  final VoidCallback? onTap;

  const _Btn({
    required this.icon,
    required this.label,
    this.primary = false,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = disabled
        ? AppColors.textHint
        : (primary ? Colors.white : AppColors.textTitle);
    final bg = disabled
        ? const Color(0xFFE5E7EB)
        : (primary ? AppColors.primary : Colors.transparent);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: primary || disabled
              ? null
              : BoxDecoration(
                  border: Border.all(color: _K.div),
                  borderRadius: BorderRadius.circular(8),
                ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
