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
import '../../../../../core/theme/app_theme.dart';
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

// ── Extracted sub-widgets ────────────────────────────────────────────────────
import 'materials/materials_context.dart';
import 'materials/footer_widget.dart';
import 'materials/panels/empty_state_panel.dart';
import 'materials/dialogs/confirm_delete_dialog.dart';
import 'materials/dialogs/change_position_dialog.dart';
import 'materials/dialogs/rename_module_dialog.dart';
import 'materials/dialogs/edit_description_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Internal aliases — map old private names to the new public classes so the
//  rest of this file compiles without touching every call-site.
// ─────────────────────────────────────────────────────────────────────────────
typedef _K                        = MatK;
typedef _CType                    = MatCType;
typedef _Ctx                      = MatCtx;
typedef _FooterWidget             = MatFooterWidget;
typedef _EmptyStateWidget         = MatEmptyStatePanel;
typedef _ConfirmDialogWidget      = MatConfirmDeleteDialog;
typedef _ChangeModulePositionDialog = MatChangePositionDialog;
typedef _SimpleDialog             = MatRenameModuleDialog;
typedef _DescriptionDialog        = MatEditDescriptionDialog;

// ─────────────────────────────────────────────────────────────────────────────
//  Public types that add_topic_dialog.dart re-exports
// ─────────────────────────────────────────────────────────────────────────────
enum TopicCreateMode { manual, ai }

class TopicDialogResult {
  final String title;
  final TopicCreateMode mode;
  final List<int> learningOutcomeIds;
  const TopicDialogResult({
    required this.title,
    required this.mode,
    this.learningOutcomeIds = const [],
  });
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
        ],),
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
    ],);
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

    final result = await _showManagedDialog<TopicDialogResult>(
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
          title: 'Subtopic added', message: '"${topic.title}" created.',);
    }
  }

  // ── Create / copy module dialog ──────────────────────────────────────────
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

      if (!mounted) return;
      if (m != null) {
        AppToast.success(context,
            title: 'Module created', message: '"${m.title}" added.',);
      }
    } else {
      final sourceModule   = result.existing!;
      final sourceCourseId = result.sourceCourseId!;

      final copied = await notifier.copyModule(
        sourceCourseId: sourceCourseId,
        moduleId:       sourceModule.id,
        targetCourseId: widget.course.id,
      );

      if (!mounted) return;
      if (copied != null) {
        AppToast.success(
          context,
          title: 'Module copied',
          message: '"${sourceModule.title}" has been copied into this course.',
        );
      } else {
        AppToast.error(
          context,
          title: 'Copy failed',
          message: 'Could not copy "${sourceModule.title}". Please try again.',
        );
      }
    }
  }

  Future<void> _showUploadSheet(ModuleItem module) async {
    final results = await _showManagedDialog<List<UploadSheetResult>>(
        barrierColor: Colors.black.withOpacity(0.35),
        builder: (_) => UploadMaterialSheet(moduleTitle: module.title),);
    if (results == null || results.isEmpty || !mounted) return;
    int ok = 0;
    for (final r in results) {
      if (!mounted) break;
      final success = await ref.read(courseDetailsControllerProvider(widget.course.id).notifier)
          .uploadMaterial(moduleId: module.id, bytes: r.bytes,
              filename: r.filename, contentType: r.contentType, title: r.title,);
      if (success) ok++;
    }
    if (mounted && ok > 0) {
      AppToast.success(context, title: 'Uploaded',
          message: ok == 1 ? '"${results.first.title}" is ready.' : '$ok files uploaded.',);
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
          message: 'Could not copy module. Please try again.',);
    }
  }

  Future<void> _showRenameDialog(ModuleItem m) async {
    final c = TextEditingController(text: m.title);
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => _SimpleDialog(
        controller: c,
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
      builder: (_) => _DescriptionDialog(controller: c),
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
        builder: (_) => _ConfirmDialogWidget(
            title: 'Delete Module',
            body: 'Delete "${m.title}"? This will also remove all its materials.',),);
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
    final result = await _showManagedDialog<TopicDialogResult>(
      barrierColor: Colors.black.withOpacity(0.42),
      builder: (_) => _AddTopicDialogV2(outcomes: outcomes),
    );

    if (result == null || !mounted) return;

    if (result.mode == TopicCreateMode.ai) {
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
      ),);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Private helper widgets (still live here — not yet extracted)
// ─────────────────────────────────────────────────────────────────────────────

class _TopicStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;
  const _TopicStatusChip({required this.icon, required this.label, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

class _CardWidget extends StatelessWidget {
  final Widget child;
  const _CardWidget({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

class _AddTopicDialogV2 extends StatefulWidget {
  final List<LearningOutcomeItem> outcomes;
  const _AddTopicDialogV2({required this.outcomes});

  @override
  State<_AddTopicDialogV2> createState() => _AddTopicDialogV2State();
}

class _AddTopicDialogV2State extends State<_AddTopicDialogV2> {
  final _ctrl = TextEditingController();
  TopicCreateMode _mode = TopicCreateMode.manual;
  final Set<int> _selectedIds = {};

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Topic', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
              const SizedBox(height: 16),
              Row(
                children: TopicCreateMode.values.map((m) {
                  final sel = _mode == m;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _mode = m),
                      child: Container(
                        margin: EdgeInsets.only(right: m == TopicCreateMode.manual ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            m == TopicCreateMode.manual ? 'Manual' : 'AI Generate',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              if (_mode == TopicCreateMode.manual) ...[
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Topic title',
                    hintText: 'e.g. Introduction to Recursion',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (widget.outcomes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('Link outcomes (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.outcomes.map((lo) {
                      final sel = _selectedIds.contains(lo.id);
                      return FilterChip(
                        selected: sel,
                        label: Text('${lo.code} • ${lo.title}'),
                        onSelected: (v) => setState(() => v ? _selectedIds.add(lo.id) : _selectedIds.remove(lo.id)),
                        selectedColor: const Color(0xFFE0ECFF),
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(fontSize: 12, color: sel ? AppColors.primary : AppColors.textTitle, fontWeight: FontWeight.w600),
                        side: BorderSide(color: sel ? MatK.blue : const Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      );
                    }).toList(),
                  ),
                ],
              ] else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: Color(0xFF16A34A), size: 16),
                      SizedBox(width: 8),
                      Expanded(child: Text('AI will analyse the uploaded material and generate topics automatically.', style: TextStyle(fontSize: 13, color: Color(0xFF15803D)))),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: MatK.div),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(
                        context,
                        TopicDialogResult(
                          title: _ctrl.text,
                          mode: _mode,
                          learningOutcomeIds: _selectedIds.toList(),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(_mode == TopicCreateMode.manual ? 'Add Topic' : 'Generate'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareModuleDialog extends ConsumerStatefulWidget {
  final ModuleItem module;
  final int currentCourseId;
  const _ShareModuleDialog({required this.module, required this.currentCourseId});

  @override
  ConsumerState<_ShareModuleDialog> createState() => _ShareModuleDialogState();
}

class _ShareModuleDialogState extends ConsumerState<_ShareModuleDialog> {
  MyCourseItem? _selected;

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(myCoursesProvider);

    final otherCourses = courses.when(
      data: (list) => list.where((c) => c.id != widget.currentCourseId).toList(),
      loading: () => <MyCourseItem>[],
      error: (_, __) => <MyCourseItem>[],
    );

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Copy Module to Another Course',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textTitle),),
              const SizedBox(height: 6),
              Text('Copying "${widget.module.title}" — choose a destination course.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),),
              const SizedBox(height: 16),
              if (courses.isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
              else if (otherCourses.isEmpty)
                const Text('No other courses available.', style: TextStyle(color: AppColors.textMuted))
              else
                DropdownButtonFormField<MyCourseItem>(
                  value: _selected,
                  hint: const Text('Select a course'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  items: otherCourses.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.safeTitle, overflow: TextOverflow.ellipsis),
                  ),).toList(),
                  onChanged: (v) => setState(() => _selected = v),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: MatK.div),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: _selected == null ? null : () => Navigator.pop(context, _selected),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Copy Module'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Stub widgets — _SidebarWidget, _ModulePanelWidget, _MaterialPanelWidget,
//  _TopicPanelWidget are defined in their own files and imported via the
//  panels/ directory. They are referenced here by name only.
// ─────────────────────────────────────────────────────────────────────────────
