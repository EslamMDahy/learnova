import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/storage/key_value_store_factory.dart';
import '../../../../../core/ui/pdf_preview_view.dart';
import '../../../../../core/ui/toast.dart';
import '../../../../../shared/widgets/app_ui_components.dart';
import '../../../data/courses_models.dart';
import '../../../data/courses_providers.dart';
import '../../../data/modules_models.dart';
import '../../../data/materials_models.dart';
import '../../../data/topics_models.dart';
import '../../../data/learning_outcomes_models.dart';
import '../../../data/modules_materials_providers.dart';
import '../../controllers/course_details_controller.dart';
import '../../controllers/course_details_state.dart';
import '../add_question_sheet.dart';
import '../course_outcomes_panel.dart';
import '../upload_material_sheet.dart';

import '../generate_questions_dialog.dart';
import '../question_bank/question_bank_authoring_flow.dart';
import '../module_selector_sheet.dart';

part 'materials_tab_sidebar.dart';
part 'materials_tab_material_panel.dart';
part 'materials_tab_topics.dart';
part 'materials_tab_dialogs.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Color palette
// ─────────────────────────────────────────────────────────────────────────────
class _K {
  _K._();
  static const amber      = Color(0xFFD97706);
  static const amberSoft  = Color(0xFFFFFBEB);
  static Color get green => AppColors.successText;
  static Color get greenSoft => AppColors.successBg;
  static const redSoft    = Color(0xFFFFF1F2);
  static const blue       = Color(0xFF2563EB);
  static Color get blueSoft => AppColors.primarySoft;
  static Color get blueMid => AppColors.badgeBlueBg;
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


class _TreeSelectionState {
  final Set<int> moduleIds;
  final Set<int> materialIds;
  final Set<int> topicIds;

  const _TreeSelectionState({
    this.moduleIds = const <int>{},
    this.materialIds = const <int>{},
    this.topicIds = const <int>{},
  });

  static const empty = _TreeSelectionState();

  bool get isEmpty => topicIds.isEmpty;
  int get totalCount => topicIds.length;

  _TreeSelectionState copyWith({
    Set<int>? moduleIds,
    Set<int>? materialIds,
    Set<int>? topicIds,
  }) {
    return _TreeSelectionState(
      moduleIds: moduleIds ?? this.moduleIds,
      materialIds: materialIds ?? this.materialIds,
      topicIds: topicIds ?? this.topicIds,
    );
  }

  _TreeSelectionState clear() => empty;
}

class CourseMaterialsTab extends ConsumerStatefulWidget {
  final MyCourseItem course;
  const CourseMaterialsTab({super.key, required this.course});
  @override
  ConsumerState<CourseMaterialsTab> createState() => _CourseMaterialsTabState();
}

class _CourseMaterialsTabState extends ConsumerState<CourseMaterialsTab>
    with AutomaticKeepAliveClientMixin {
  final Set<int>    _expanded = {};
  final Set<int>    _expandedMaterialIds = {};
  final Set<int>    _expandedTopicIds = {};
  _Ctx?             _sel;
  final List<_Ctx>  _stack   = [];
  final ScrollController _scroll = ScrollController();
  late final _session = createSessionStore();
  bool _restored = false;
  bool _dialogOpen = false;
  int? _draggingModuleId;
  bool _selectionMode = false;
  _TreeSelectionState _treeSelection = _TreeSelectionState.empty;
  bool _hideFooterForActive = false;
  bool _showQuestionAuthoring = false;
  Set<int> _authoringModuleIds = const <int>{};
  Set<int> _authoringMaterialIds = const <int>{};
  Set<int> _authoringTopicIds = const <int>{};
  QuestionAuthoringLaunchContext? _authoringLaunchContext;

  @override
  bool get wantKeepAlive => true;

  String get _uiStateKey => 'course:${widget.course.id}:materials_ui';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_persistUiState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(courseDetailsControllerProvider(widget.course.id).notifier)
          .loadModules();
    });
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

  Set<int> _intSetFromJson(Object? value) {
    return ((value as List?) ?? const <dynamic>[])
        .whereType<num>()
        .map((num item) => item.toInt())
        .toSet();
  }

  QuestionAuthoringScopeKind? _authoringKindFromName(Object? value) {
    final String? name = value?.toString();
    if (name == null) return null;
    for (final QuestionAuthoringScopeKind kind in QuestionAuthoringScopeKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }

  Map<String, dynamic>? _authoringLaunchContextToJson(
    QuestionAuthoringLaunchContext? launchContext,
  ) {
    if (launchContext == null) return null;
    return <String, dynamic>{
      'kind': launchContext.kind.name,
      'title': launchContext.title,
      'subtitle': launchContext.subtitle,
      'selectedModuleId': launchContext.selectedModuleId,
      'selectedMaterialId': launchContext.selectedMaterialId,
      'selectedTopicId': launchContext.selectedTopicId,
      'selectedModuleIds': launchContext.selectedModuleIds.toList(),
      'selectedMaterialIds': launchContext.selectedMaterialIds.toList(),
      'selectedTopicIds': launchContext.selectedTopicIds.toList(),
    };
  }

  QuestionAuthoringLaunchContext? _authoringLaunchContextFromJson(Object? value) {
    if (value is! Map) return null;
    final QuestionAuthoringScopeKind? kind = _authoringKindFromName(value['kind']);
    if (kind == null) return null;
    final String title = (value['title']?.toString() ?? '').trim();
    final String subtitle = (value['subtitle']?.toString() ?? '').trim();
    return QuestionAuthoringLaunchContext(
      kind: kind,
      title: title.isEmpty ? 'Selected content' : title,
      subtitle: subtitle.isEmpty ? 'Question workspace restored from materials.' : subtitle,
      selectedModuleId: (value['selectedModuleId'] as num?)?.toInt(),
      selectedMaterialId: (value['selectedMaterialId'] as num?)?.toInt(),
      selectedTopicId: (value['selectedTopicId'] as num?)?.toInt(),
      selectedModuleIds: _intSetFromJson(value['selectedModuleIds']),
      selectedMaterialIds: _intSetFromJson(value['selectedMaterialIds']),
      selectedTopicIds: _intSetFromJson(value['selectedTopicIds']),
    );
  }


  void _persistUiState() {
    final sel = _sel;
    final active = _active;
    final payload = <String, dynamic>{
      'expanded': _expanded.toList(),
      'expandedMaterials': _expandedMaterialIds.toList(),
      'expandedTopics': _expandedTopicIds.toList(),
      'scrollOffset': _scroll.hasClients ? _scroll.offset : 0.0,
      'selectedType': sel?.type.name,
      'selectedModuleId': sel?.module?.id,
      'selectedMaterialId': sel?.material?.id,
      'selectedTopicId': sel?.topic?.id,
      'activeTopicId': active?.type == _CType.topic ? active?.topic?.id : null,
      'questionAuthoringOpen': _showQuestionAuthoring,
      'authoringModuleIds': _authoringModuleIds.toList(),
      'authoringMaterialIds': _authoringMaterialIds.toList(),
      'authoringTopicIds': _authoringTopicIds.toList(),
      'authoringLaunchContext': _authoringLaunchContextToJson(_authoringLaunchContext),
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
      final expanded = ((map['expanded'] as List?) ?? [])
          .map((e) => (e as num).toInt())
          .toSet();
      final expandedMaterials = ((map['expandedMaterials'] as List?) ?? [])
          .map((e) => (e as num).toInt())
          .toSet();
      final expandedTopics = ((map['expandedTopics'] as List?) ?? [])
          .map((e) => (e as num).toInt())
          .toSet();
      final selectedType = map['selectedType']?.toString();
      final selectedModuleId = (map['selectedModuleId'] as num?)?.toInt();
      final selectedMaterialId = (map['selectedMaterialId'] as num?)?.toInt();
      final selectedTopicId = (map['selectedTopicId'] as num?)?.toInt();
      final activeTopicId = (map['activeTopicId'] as num?)?.toInt();
      final storedOffset = (map['scrollOffset'] as num?)?.toDouble() ?? 0.0;
      final bool restoreAuthoring = map['questionAuthoringOpen'] == true;
      final Set<int> authoringModuleIds = _intSetFromJson(map['authoringModuleIds']);
      final Set<int> authoringMaterialIds = _intSetFromJson(map['authoringMaterialIds']);
      final Set<int> authoringTopicIds = _intSetFromJson(map['authoringTopicIds']);
      final QuestionAuthoringLaunchContext? restoredLaunchContext =
          _authoringLaunchContextFromJson(map['authoringLaunchContext']);

      if (restoreAuthoring) {
        _showQuestionAuthoring = true;
        _hideFooterForActive = true;
        _authoringModuleIds = authoringModuleIds;
        _authoringMaterialIds = authoringMaterialIds;
        _authoringTopicIds = authoringTopicIds;
        _authoringLaunchContext = restoredLaunchContext;
      }

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
      _expandedMaterialIds
        ..clear()
        ..addAll(expandedMaterials);
      _expandedTopicIds
        ..clear()
        ..addAll(expandedTopics);

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
              ensureCourseLearningOutcomesLoaded(ref, widget.course.id);
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

    if (_showQuestionAuthoring) {
      return QuestionBankAuthoringFlow(
        course: widget.course,
        initialModuleIds: _authoringModuleIds,
        initialMaterialIds: _authoringMaterialIds,
        initialTopicIds: _authoringTopicIds,
        embedded: true,
        launchContext: _authoringLaunchContext,
        onClose: _closeQuestionAuthoring,
      );
    }

    final active = _active ?? _sel;
    final hasTreeSelection = _selectionMode && !_treeSelection.isEmpty;
    final footerCtx = hasTreeSelection ? (_footerCtxFromSelection(st) ?? active) : active;
    final showFooter = hasTreeSelection
        ? footerCtx != null
        : (footerCtx != null && !_hideFooterForActive);
    Widget sidebar({required double width}) => _SidebarWidget(
          width: width,
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
              .loadModules(force: true),
          selectionMode: _selectionMode,
          treeSelection: _treeSelection,
          onToggleSelectionMode: _toggleSelectionMode,
          onClearSelection: _clearTreeSelection,
          onModuleCheckChanged: (module, value) => _setModuleChecked(module, st, value),
          onMaterialCheckChanged: (module, material, value) => _setMaterialChecked(module, material, st, value),
          onTopicCheckChanged: (module, material, topic, value) =>
              _setTopicChecked(module, material, topic, st, value),
          expandedMaterialIds: _expandedMaterialIds,
          expandedTopicIds: _expandedTopicIds,
          onToggleMaterialExpanded: _toggleMaterialExpanded,
          onToggleTopicExpanded: _toggleTopicExpanded,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 820;
        final compact = constraints.maxWidth < 1120;
        final sidebarWidth = narrow
            ? double.infinity
            : compact
                ? 232.0
                : 268.0;
        final sidebarHeight = constraints.maxHeight < 640 ? 212.0 : 286.0;

        return Column(children: [
          Expanded(
            child: narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: sidebarHeight,
                        child: sidebar(width: sidebarWidth),
                      ),
                      const Divider(height: 1, thickness: 1, color: _K.div),
                      Expanded(child: _buildPanel(st)),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sidebar(width: sidebarWidth),
                      Expanded(child: _buildPanel(st)),
                    ],
                  ),
          ),
          if (showFooter)
            _FooterWidget(
              ctx: footerCtx,
              uploading: st.uploading,
              canGenerate: _canGenerate(footerCtx, st),
              selectionCount: hasTreeSelection ? _treeSelection.totalCount : null,
              onUpload: () { final m = footerCtx.module; if (m != null) _showUploadSheet(m); },
              onGenerate: () => _openQuestionAuthoringFromSelection(footerCtx),
              onClose: () => setState(() {
                if (_selectionMode && !_treeSelection.isEmpty) {
                  _treeSelection = _treeSelection.clear();
                  _hideFooterForActive = false;
                } else {
                  _hideFooterForActive = true;
                }
                _persistUiState();
              }),
            ),
        ],);
      },
    );
  }

  _Ctx? _footerCtxFromSelection(CourseDetailsState st) {
    if (_treeSelection.moduleIds.isNotEmpty) {
      for (final module in st.modules) {
        if (_treeSelection.moduleIds.contains(module.id)) {
          return _Ctx.module(module);
        }
      }
    }

    if (_treeSelection.materialIds.isNotEmpty) {
      for (final module in st.modules) {
        final materials = st.materials[module.id] ?? const <MaterialItem>[];
        for (final material in materials) {
          if (_treeSelection.materialIds.contains(material.id)) {
            return _Ctx.material(module, material);
          }
        }
      }
    }

    if (_treeSelection.topicIds.isNotEmpty) {
      for (final module in st.modules) {
        final topics = st.topics[module.id] ?? const <TopicItem>[];
        for (final topic in topics) {
          if (_treeSelection.topicIds.contains(topic.id)) {
            final materials = st.materials[module.id] ?? const <MaterialItem>[];
            for (final material in materials) {
              if (material.id == topic.materialId) {
                return _Ctx.topic(module, material, topic);
              }
            }
          }
        }
      }
    }

    return null;
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


  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _hideFooterForActive = false;
      if (!_selectionMode) {
        _treeSelection = _treeSelection.clear();
      }
    });
  }

  void _clearTreeSelection() {
    if (_treeSelection.isEmpty) return;
    setState(() {
      _treeSelection = _treeSelection.clear();
      _selectionMode = false;
      _hideFooterForActive = false;
    });
  }

  List<MaterialItem> _materialsForModule(CourseDetailsState st, int moduleId) {
    return st.materials[moduleId] ?? const <MaterialItem>[];
  }

  List<TopicItem> _topicsForMaterial(CourseDetailsState st, int moduleId, int materialId) {
    final items = st.topics[moduleId] ?? const <TopicItem>[];
    return items.where((t) => t.materialId == materialId).toList();
  }

  List<TopicItem> _childTopics(List<TopicItem> topics, int parentTopicId) {
    final items = topics.where((t) => t.parentTopicId == parentTopicId).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return items;
  }


  Set<int> _selectableTopicIdsForTopic(List<TopicItem> materialTopics, TopicItem topic) {
    final children = _childTopics(materialTopics, topic.id);
    if (children.isEmpty) {
      return <int>{topic.id};
    }

    final ids = <int>{};
    for (final child in children) {
      ids.addAll(_selectableTopicIdsForTopic(materialTopics, child));
    }
    return ids;
  }

  Set<int> _selectableTopicIdsForMaterial(
    CourseDetailsState st,
    int moduleId,
    int materialId,
  ) {
    final materialTopics = _topicsForMaterial(st, moduleId, materialId);
    final roots = materialTopics.where((topic) => topic.parentTopicId == null).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final ids = <int>{};
    for (final root in roots) {
      ids.addAll(_selectableTopicIdsForTopic(materialTopics, root));
    }
    return ids;
  }

  Set<int> _selectableTopicIdsForModule(CourseDetailsState st, int moduleId) {
    final ids = <int>{};
    for (final material in _materialsForModule(st, moduleId)) {
      ids.addAll(_selectableTopicIdsForMaterial(st, moduleId, material.id));
    }
    return ids;
  }

  Set<int> _allSelectableTopicIds(CourseDetailsState st) {
    final ids = <int>{};
    for (final module in st.modules) {
      ids.addAll(_selectableTopicIdsForModule(st, module.id));
    }
    return ids;
  }

  _TreeSelectionState _normalizeTreeSelection(
    CourseDetailsState st, {
    required Set<int> moduleIds,
    required Set<int> materialIds,
    required Set<int> topicIds,
  }) {
    final nextTopics = topicIds.intersection(_allSelectableTopicIds(st));
    final nextMaterials = <int>{};
    final nextModules = <int>{};

    for (final module in st.modules) {
      final materials = _materialsForModule(st, module.id);
      var selectableMaterialsCount = 0;
      var selectedMaterialsCount = 0;

      for (final material in materials) {
        final selectableTopicIds = _selectableTopicIdsForMaterial(st, module.id, material.id);
        if (selectableTopicIds.isEmpty) continue;
        selectableMaterialsCount++;

        if (nextTopics.containsAll(selectableTopicIds)) {
          nextMaterials.add(material.id);
          selectedMaterialsCount++;
        }
      }

      if (selectableMaterialsCount > 0 && selectedMaterialsCount == selectableMaterialsCount) {
        nextModules.add(module.id);
      }
    }

    return _TreeSelectionState(
      moduleIds: nextModules,
      materialIds: nextMaterials,
      topicIds: nextTopics,
    );
  }

  void _toggleMaterialExpanded(MaterialItem material) {
    setState(() {
      if (!_expandedMaterialIds.add(material.id)) {
        _expandedMaterialIds.remove(material.id);
      }
      _persistUiState();
    });
  }

  void _toggleTopicExpanded(TopicItem topic) {
    setState(() {
      if (!_expandedTopicIds.add(topic.id)) {
        _expandedTopicIds.remove(topic.id);
      }
      _persistUiState();
    });
  }

  void _setModuleChecked(ModuleItem module, CourseDetailsState st, bool checked) {
    final selectableTopicIds = _selectableTopicIdsForModule(st, module.id);
    if (selectableTopicIds.isEmpty) return;

    setState(() {
      final nextTopics = {..._treeSelection.topicIds};
      if (checked) {
        nextTopics.addAll(selectableTopicIds);
      } else {
        nextTopics.removeAll(selectableTopicIds);
      }

      _treeSelection = _normalizeTreeSelection(
        st,
        moduleIds: const <int>{},
        materialIds: const <int>{},
        topicIds: nextTopics,
      );
    });
  }

  void _setMaterialChecked(ModuleItem module, MaterialItem material, CourseDetailsState st, bool checked) {
    final selectableTopicIds = _selectableTopicIdsForMaterial(st, module.id, material.id);
    if (selectableTopicIds.isEmpty) return;

    setState(() {
      final nextTopics = {..._treeSelection.topicIds};
      if (checked) {
        nextTopics.addAll(selectableTopicIds);
      } else {
        nextTopics.removeAll(selectableTopicIds);
      }

      _treeSelection = _normalizeTreeSelection(
        st,
        moduleIds: const <int>{},
        materialIds: const <int>{},
        topicIds: nextTopics,
      );
    });
  }

  void _setTopicChecked(
    ModuleItem module,
    MaterialItem material,
    TopicItem topic,
    CourseDetailsState st,
    bool checked,
  ) {
    final allTopics = _topicsForMaterial(st, module.id, material.id);
    final selectableTopicIds = _selectableTopicIdsForTopic(allTopics, topic);
    if (selectableTopicIds.isEmpty) return;

    setState(() {
      final nextTopics = {..._treeSelection.topicIds};
      if (checked) {
        nextTopics.addAll(selectableTopicIds);
      } else {
        nextTopics.removeAll(selectableTopicIds);
      }

      _treeSelection = _normalizeTreeSelection(
        st,
        moduleIds: const <int>{},
        materialIds: const <int>{},
        topicIds: nextTopics,
      );
    });
  }

  // ── Tap handlers ────────────────────────────────────────────────────────
  void _tapModule(ModuleItem m, CourseDetailsState st) {
    setState(() {
      final alreadySel = _active?.type == _CType.module && _active?.module?.id == m.id;
      if (_expanded.contains(m.id) && alreadySel) {
        _expanded.remove(m.id); _sel = null; _stack.clear();
        _hideFooterForActive = false;
        _persistUiState();
      } else {
        _expanded.add(m.id); _sel = _Ctx.module(m); _stack.clear();
        _hideFooterForActive = false;
        if (!st.materials.containsKey(m.id)) {
          ref.read(courseDetailsControllerProvider(widget.course.id).notifier).loadMaterials(m.id);
        }
        _persistUiState();
      }
    });
  }

  void _tapMaterial(ModuleItem m, MaterialItem mat) {
    setState(() {
      _expanded.add(m.id);
      _expandedMaterialIds.add(mat.id);
      _sel = _Ctx.material(m, mat);
      _stack.clear();
      _hideFooterForActive = false;
    });
    _persistUiState();
    final notifier = ref.read(courseDetailsControllerProvider(widget.course.id).notifier);
    notifier.loadTopics(m.id);
    notifier.fetchDownloadUrl(moduleId: m.id, materialId: mat.id);
    ensureCourseLearningOutcomesLoaded(ref, widget.course.id);
  }

  void _tapTopic(ModuleItem m, MaterialItem mat, TopicItem t) {
    setState(() {
      _expanded.add(m.id);
      _expandedMaterialIds.add(mat.id);
      if (t.parentTopicId == null) {
        _expandedTopicIds.add(t.id);
      }
      _sel = _Ctx.material(m, mat);
      _stack..clear()..add(_Ctx.topic(m, mat, t));
      _hideFooterForActive = false;
    });
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
    setState(() {
      _stack.add(_Ctx.topic(c!.module!, c.material!, t));
      _hideFooterForActive = false;
    });
    _persistUiState();
  }

  void _pop() => setState(() { if (_stack.isNotEmpty) _stack.removeLast(); _hideFooterForActive = false; _persistUiState(); });

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
        onCreateTopicManual: (title, description, learningOutcomeIds) =>
            _createManualTopicInline(
          module: c.module!,
          material: c.material!,
          title: title,
          description: description,
          learningOutcomeIds: learningOutcomeIds,
        ),
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
      onRenameTopic: () => _showRenameTopicDialog(c.module!, c.material!, c.topic!),
      onEditTopicSummary: () => _showTopicSummaryDialog(c.module!, c.material!, c.topic!),
      onEditTopicStatus: () => _showTopicStatusDialog(c.module!, c.material!, c.topic!),
      onMapTopicOutcomes: () => _showTopicOutcomeMappingDialog(c.module!, c.material!, c.topic!),
      onDeleteTopic: () => _confirmDeleteTopic(c.module!, c.material!, c.topic!),
      onOpenSubtopic: (TopicItem subtopic) {
        _drillTopic(subtopic);
      },
      onAddSubtopic: () => _showAddSubtopicDialog(c.module!, c.material!, c.topic!),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────
Future<void> _showRenameTopicDialog(ModuleItem m, MaterialItem mat, TopicItem topic) async {
  final ctrl = TextEditingController(text: topic.title);
  final result = await _showManagedDialog<bool>(
    barrierColor: Colors.black.withOpacity(0.38),
    builder: (_) => _PreferencesDialogShell(
      title: topic.parentTopicId == null ? 'Rename topic' : 'Rename subtopic',
      subtitle: 'This popup changes the title only.',
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.drive_file_rename_outline_rounded, size: 18, color: AppColors.primary),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DialogTextField(
            controller: ctrl,
            hintText: 'Write a clear title',
            autofocus: true,
          ),
          const SizedBox(height: 16),
          _DialogActions(
            onCancel: () => Navigator.pop(context, false),
            onConfirm: () => Navigator.pop(context, true),
            confirmLabel: 'Save title',
          ),
        ],
      ),
    ),
  );

  if (result != true || !mounted) return;
  final title = ctrl.text.trim();
  ctrl.dispose();
  if (title.isEmpty) {
    AppToast.error(context, title: 'Title required', message: 'Topic title cannot be empty.');
    return;
  }
  await ref.read(courseDetailsControllerProvider(widget.course.id).notifier).updateTopic(
        topic.copyWith(moduleId: m.id, materialId: mat.id, title: title),
      );
  if (!mounted) return;
  AppToast.success(context, title: 'Title updated', message: 'The topic title was saved.');
}

Future<void> _showTopicSummaryDialog(ModuleItem m, MaterialItem mat, TopicItem topic) async {
  final descriptionCtrl = TextEditingController(text: topic.description ?? '');
  final notesCtrl = TextEditingController(text: topic.instructorNotes ?? '');
  final result = await _showManagedDialog<bool>(
    barrierColor: Colors.black.withOpacity(0.38),
    builder: (_) => _PreferencesDialogShell(
      title: 'Edit summary',
      subtitle: 'This popup only updates the scope and instructor notes.',
      maxWidth: 680,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.notes_rounded, size: 18, color: AppColors.primary),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Scope / description', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          _DialogTextField(
            controller: descriptionCtrl,
            hintText: 'What exactly does this topic cover?',
            multiline: true,
            autofocus: true,
          ),
          const SizedBox(height: 14),
          Text('Instructor notes', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          _DialogTextField(
            controller: notesCtrl,
            hintText: 'Examples, warnings, pacing notes, or delivery hints',
            multiline: true,
          ),
          const SizedBox(height: 16),
          _DialogActions(
            onCancel: () => Navigator.pop(context, false),
            onConfirm: () => Navigator.pop(context, true),
            confirmLabel: 'Save summary',
          ),
        ],
      ),
    ),
  );

  if (result != true || !mounted) return;
  final description = descriptionCtrl.text.trim();
  final notes = notesCtrl.text.trim();
  descriptionCtrl.dispose();
  notesCtrl.dispose();
  await ref.read(courseDetailsControllerProvider(widget.course.id).notifier).updateTopic(
        topic.copyWith(
          moduleId: m.id,
          materialId: mat.id,
          description: description.isEmpty ? null : description,
          instructorNotes: notes.isEmpty ? null : notes,
        ),
      );
  if (!mounted) return;
  AppToast.success(context, title: 'Summary updated', message: 'The topic summary was saved.');
}

Future<void> _showTopicStatusDialog(ModuleItem m, MaterialItem mat, TopicItem topic) async {
  TopicDifficulty difficulty = topic.difficulty;
  TopicReadiness readiness = topic.readiness;

  final result = await _showManagedDialog<bool>(
    barrierColor: Colors.black.withOpacity(0.38),
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => _PreferencesDialogShell(
        title: 'Set delivery state',
        subtitle: 'This popup only changes difficulty and readiness.',
        maxWidth: 600,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.speed_rounded, size: 18, color: AppColors.primary),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Difficulty', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in TopicDifficulty.values)
                  ChoiceChip(
                    label: Text(value.label),
                    selected: difficulty == value,
                    onSelected: (_) => setDialogState(() => difficulty = value),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Readiness', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in TopicReadiness.values)
                  ChoiceChip(
                    label: Text(value.label),
                    selected: readiness == value,
                    onSelected: (_) => setDialogState(() => readiness = value),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _DialogActions(
              onCancel: () => Navigator.pop(dialogContext, false),
              onConfirm: () => Navigator.pop(dialogContext, true),
              confirmLabel: 'Save state',
            ),
          ],
        ),
      ),
    ),
  );

  if (result != true || !mounted) return;
  await ref.read(courseDetailsControllerProvider(widget.course.id).notifier).updateTopic(
        topic.copyWith(
          moduleId: m.id,
          materialId: mat.id,
          difficulty: difficulty,
          readiness: readiness,
        ),
      );
  if (!mounted) return;
  AppToast.success(context, title: 'State updated', message: 'Delivery state was saved.');
}

Future<void> _showTopicOutcomeMappingDialog(ModuleItem m, MaterialItem mat, TopicItem topic) async {
  final allTopics = ref.read(courseDetailsControllerProvider(widget.course.id)).topics[m.id] ?? const <TopicItem>[];
  final hasSubtopics = allTopics.any((t) => t.parentTopicId == topic.id);

  if (hasSubtopics && topic.parentTopicId == null) {
    await _showManagedDialog<void>(
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => _PreferencesDialogShell(
        title: 'Outcome mapping is on subtopics',
        subtitle: 'This topic contains subtopics, so the parent topic should inherit coverage from its children.',
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppColors.warningSoftBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warningText),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningSoftBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.warningBorder),
              ),
              child: Text(
                'Map learning outcomes inside each subtopic. The topic coverage is then calculated from the subtopic mappings.',
                style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.warningText, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Got it',
              onTap: () => Navigator.pop(context),
              fullWidth: true,
              height: 40,
            ),
          ],
        ),
      ),
    );
    return;
  }

  final outcomes = ref.read(courseLOProvider(widget.course.id));
  final selectedOutcomeIds = <int>{...topic.learningOutcomeIds};
  final result = await _showManagedDialog<bool>(
    barrierColor: Colors.black.withOpacity(0.38),
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => _PreferencesDialogShell(
        title: 'Map learning outcomes',
        subtitle: 'This popup only controls outcome links for this final-level item.',
        maxWidth: 660,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.flag_outlined, size: 18, color: AppColors.primary),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (outcomes.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text('No course outcomes yet. Add them from the Outcomes tab first.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: outcomes.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (_, i) {
                    final lo = outcomes[i];
                    final selected = selectedOutcomeIds.contains(lo.id);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (_) => setDialogState(() {
                        if (selected) {
                          selectedOutcomeIds.remove(lo.id);
                        } else {
                          selectedOutcomeIds.add(lo.id);
                        }
                      }),
                      title: Text('${lo.code} • ${lo.title}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            _DialogActions(
              onCancel: () => Navigator.pop(dialogContext, false),
              onConfirm: outcomes.isEmpty ? null : () => Navigator.pop(dialogContext, true),
              confirmLabel: 'Save mapping',
            ),
          ],
        ),
      ),
    ),
  );

  if (result != true || !mounted) return;
  await ref.read(courseDetailsControllerProvider(widget.course.id).notifier).updateTopic(
        topic.copyWith(
          moduleId: m.id,
          materialId: mat.id,
          learningOutcomeIds: selectedOutcomeIds.toList(),
          linkedOutcomeId: selectedOutcomeIds.isEmpty ? null : selectedOutcomeIds.first.toString(),
          linkedOutcomeIds: selectedOutcomeIds.map((id) => id.toString()).toList(),
        ),
      );
  if (!mounted) return;
  AppToast.success(context, title: 'Outcomes updated', message: 'Outcome mapping was saved.');
}

Future<void> _confirmDeleteTopic(ModuleItem m, MaterialItem mat, TopicItem topic) async {
  final ok = await _showManagedDialog<bool>(
        barrierColor: Colors.black.withOpacity(0.38),
        builder: (_) => _ConfirmDialogWidget(
          title: topic.parentTopicId == null ? 'Delete Topic' : 'Delete Subtopic',
          body: 'Delete "${topic.title}"? This action cannot be undone.',
          confirm: 'Delete',
          confirmColor: AppColors.dangerText,
        ),
      ) ??
      false;
  if (!ok || !mounted) return;

  await ref.read(courseDetailsControllerProvider(widget.course.id).notifier).deleteTopic(
        moduleId: m.id,
        materialId: mat.id,
        topicId: topic.id,
      );
  if (!mounted) return;
  setState(() {
    _sel = _Ctx.material(m, mat);
    _stack.clear();
    _persistUiState();
  });
  AppToast.success(context, title: 'Deleted', message: 'The item was removed from this material.');
}

Future<void> _showAddSubtopicDialog(
  ModuleItem m,
  MaterialItem mat,
  TopicItem parent,
) async {
  final outcomes = ref.read(courseLOProvider(widget.course.id));

  final result = await _showManagedDialog<_TopicDialogResult>(
    barrierColor: Colors.black.withOpacity(0.42),
    builder: (_) => _AddTopicDialogV2(outcomes: outcomes, isSubtopic: true),
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
          title: 'Module created', message: '"${m.title}" added.',);
    }
    return;
  }

  final sourceModule = result.existing;
  final sourceCourseId = result.sourceCourseId;
  if (sourceModule == null || sourceCourseId == null) {
    AppToast.error(
      context,
      title: 'Copy failed',
      message: 'Could not determine which module to copy.',
    );
    return;
  }

  final copied = await notifier.copyModule(
    sourceCourseId: sourceCourseId,
    moduleId: sourceModule.id,
    targetCourseId: widget.course.id,
  );

  if (!mounted) return;

  if (copied != null) {
    final refreshedModule = ref
        .read(courseDetailsControllerProvider(widget.course.id))
        .modules
        .where((m) => m.id == copied.id)
        .cast<ModuleItem?>()
        .firstWhere((m) => m != null, orElse: () => copied);

    setState(() {
      _expanded.add(refreshedModule!.id);
      _sel = _Ctx.module(refreshedModule);
      _stack.clear();
      _persistUiState();
    });
    if (refreshedModule != null) {
      await ref
          .read(courseDetailsControllerProvider(widget.course.id).notifier)
          .loadMaterials(refreshedModule.id);
    }

    AppToast.success(
      context,
      title: 'Module copied',
      message: '"${sourceModule.title}" added.',
    );
  } else {
    AppToast.error(
      context,
      title: 'Copy failed',
      message: 'Could not copy module. Please try again.',
    );
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
            confirm: 'Delete', confirmColor: const Color(0xFFEF4444),),);
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

  Future<bool> _createManualTopicInline({
    required ModuleItem module,
    required MaterialItem material,
    required String title,
    String? description,
    List<int> learningOutcomeIds = const [],
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return false;

    final notifier = ref.read(courseDetailsControllerProvider(widget.course.id).notifier);
    final topic = await notifier.createTopic(
      moduleId: module.id,
      materialId: material.id,
      payload: TopicCreateRequest(
        title: trimmedTitle,
        description: description?.trim().isEmpty ?? false ? null : description?.trim(),
        learningOutcomeIds: learningOutcomeIds,
      ),
    );

    if (!mounted) return false;

    if (topic != null) {
      AppToast.success(
        context,
        title: 'Topic added',
        message: '"${topic.title}" was attached to this PDF.',
      );
      return true;
    }

    AppToast.error(
      context,
      title: 'Could not add topic',
      message: 'Please try again.',
    );
    return false;
  }

  Future<void> _showAddTopicDialog(ModuleItem m, MaterialItem mat) async {
    ref.read(courseLOProvider(widget.course.id));
    final result = await _showManagedDialog<_TopicDialogResult>(
      barrierColor: Colors.black.withOpacity(0.42),
      builder: (_) => const _AddTopicDialogV2(),
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
    int? selectedParentTopicId = topic.parentTopicId;
    final parentTopicOptions = ref
        .read(courseDetailsControllerProvider(widget.course.id))
        .topics[m.id]
        ?.where((t) => t.materialId == mat.id && t.parentTopicId == null && t.id != topic.id)
        .toList() ??
        <TopicItem>[];

    Color difficultyColor(TopicDifficulty value) {
      switch (value) {
        case TopicDifficulty.advanced:
          return AppColors.dangerText;
        case TopicDifficulty.intermediate:
          return _K.amber;
        case TopicDifficulty.beginner:
          return _K.blue;
      }
    }

    Color difficultyBg(TopicDifficulty value) {
      switch (value) {
        case TopicDifficulty.advanced:
          return const Color(0xFFFFF1F2);
        case TopicDifficulty.intermediate:
          return const Color(0xFFFFFBEB);
        case TopicDifficulty.beginner:
          return AppColors.primarySoft;
      }
    }

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
          return AppColors.headerBg;
      }
    }

    Future<bool> confirmDelete(BuildContext context) async {
      final ok = await _showManagedDialog<bool>(
            barrierColor: Colors.black.withOpacity(0.4),
            builder: (_) => _ConfirmDialogWidget(
              title: 'Delete Topic',
              body: 'Delete "${topic.title}"? This action cannot be undone.',
              confirm: 'Delete',
              confirmColor: AppColors.dangerText,
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

          return _PreferencesDialogShell(
            title: 'Manage Topic',
            subtitle: 'Update topic details, delivery state, and linked learning outcomes without leaving the material workspace.',
            maxWidth: 760,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 720),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF8FAFF), Color(0xFFFFFFFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE8EEF8)),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TopicStatusChip(
                            icon: topic.parentTopicId != null
                                ? Icons.subdirectory_arrow_right_rounded
                                : (topic.source == TopicSource.ai
                                    ? Icons.auto_awesome_rounded
                                    : Icons.edit_note_rounded),
                            label: topic.parentTopicId != null
                                ? 'Subtopic'
                                : (topic.source == TopicSource.ai ? 'AI-assisted' : 'Manual topic'),
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
                    ),
                    const SizedBox(height: 16),
                    _CardWidget(
                      header: const _HdrWidget(
                        icon: Icons.edit_note_rounded,
                        iconColor: AppColors.primary,
                        title: 'Core details',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Topic title',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 8),
                            _DialogTextField(
                              controller: titleCtrl,
                              hintText: 'Write a concise, teachable topic name',
                              autofocus: true,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Description',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 8),
                            _DialogTextField(
                              controller: descriptionCtrl,
                              hintText: 'Add a short summary, scope, or teaching angle for this topic',
                              multiline: true,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Hierarchy',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _K.div),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int?>(
                                  value: selectedParentTopicId,
                                  isExpanded: true,
                                  dropdownColor: AppColors.cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      child: Text('Top-level topic'),
                                    ),
                                    ...parentTopicOptions.map(
                                      (parent) => DropdownMenuItem<int?>(
                                        value: parent.id,
                                        child: Text('Subtopic under ${parent.title}'),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) => setDialogState(() => selectedParentTopicId = value),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              selectedParentTopicId == null
                                  ? 'This item appears as a top-level topic inside the material.'
                                  : 'This item becomes a subtopic. Subtopics are final-level items and cannot contain children.',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.45),
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
                            header: const _HdrWidget(
                              icon: Icons.settings_suggest_rounded,
                              iconColor: AppColors.primary,
                              title: 'Delivery setup',
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Difficulty',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted),
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
                                        labelStyle: TextStyle(
                                          color: selected ? Colors.white : AppColors.textTitle,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        selectedColor: difficultyColor(value),
                                        backgroundColor: difficultyBg(value),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                        side: BorderSide(
                                          color: selected ? difficultyColor(value) : AppColors.borderGray,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Readiness',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted),
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
                                        labelStyle: TextStyle(
                                          color: selected ? Colors.white : AppColors.textTitle,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        selectedColor: readinessFg(value),
                                        backgroundColor: readinessBg(value),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                        side: BorderSide(
                                          color: selected ? readinessFg(value) : AppColors.borderGray,
                                        ),
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
                            header: const _HdrWidget(
                              icon: Icons.sticky_note_2_outlined,
                              iconColor: AppColors.primary,
                              title: 'Instructor notes',
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Use notes for examples, misconceptions, teaching cues, or assessment reminders.',
                                    style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
                                  ),
                                  const SizedBox(height: 10),
                                  _DialogTextField(
                                    controller: notesCtrl,
                                    hintText: 'Add delivery notes for this topic',
                                    multiline: true,
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
                      header: const _HdrWidget(
                        icon: Icons.flag_outlined,
                        iconColor: AppColors.primary,
                        title: 'Learning outcome alignment',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select the course outcomes this topic supports.',
                              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
                            ),
                            const SizedBox(height: 12),
                            if (outcomes.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
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
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: _K.blueSoft,
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(color: _K.blueMid),
                                          ),
                                          child: Text(
                                            '${lo.code} • ${lo.title}',
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Container(
                                constraints: const BoxConstraints(maxHeight: 220),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _K.div),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: outcomes.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEAECEF)),
                                    itemBuilder: (_, i) {
                                      final lo = outcomes[i];
                                      final selected = selectedOutcomeIds.contains(lo.id);
                                      return InkWell(
                                        hoverColor: Colors.transparent,
                                        splashColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                                        onTap: () => setDialogState(() {
                                          if (selected) {
                                            selectedOutcomeIds.remove(lo.id);
                                          } else {
                                            selectedOutcomeIds.add(lo.id);
                                          }
                                        }),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 18,
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  color: selected ? AppColors.primary : Colors.white,
                                                  borderRadius: BorderRadius.circular(5),
                                                  border: Border.all(
                                                    color: selected ? AppColors.primary : const Color(0xFFCBD5E1),
                                                    width: 1.4,
                                                  ),
                                                ),
                                                child: selected
                                                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                                                    : null,
                                              ),
                                              const SizedBox(width: 10),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AppColors.badgeBlueBg,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  lo.code,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.badgeBlueFg,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  lo.title,
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                                    color: selected ? AppColors.textTitle : AppColors.textMuted,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _CardWidget(
                      header: _HdrWidget(
                        icon: Icons.warning_amber_rounded,
                        iconColor: AppColors.dangerText,
                        title: 'Danger zone',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Delete this topic',
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textTitle),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'This removes the topic and its direct links from the material structure.',
                                    style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            AppButton(
                              label: 'Delete topic',
                              onTap: () async {
                                final ok = await confirmDelete(dialogContext);
                                if (!ok) return;
                                await notifier.deleteTopic(
                                  moduleId: m.id,
                                  topicId: topic.id,
                                  materialId: mat.id,
                                );
                                if (mounted) Navigator.pop(dialogContext, true);
                              },
                              variant: AppButtonVariant.danger,
                              height: 40,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _DialogActions(
                      confirmLabel: 'Save changes',
                      onCancel: () => Navigator.pop(dialogContext, false),
                      onConfirm: () async {
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
                            parentTopicId: selectedParentTopicId,
                          ),
                        );
                        if (mounted) Navigator.pop(dialogContext, true);
                      },
                    ),
                  ],
                ),
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
        topicId: topic.id,
        topicName: topic.title,
        onAdd: (q) async {
          final api = ref.read(questionsApiProvider);
          final payload = api.buildCreatePayloadFromQuestion(q);
          if (payload == null) {
            throw StateError('Question type or topic is not compatible with backend.');
          }
          final saved = await api.createQuestion(
            courseId: widget.course.id,
            payload: payload,
          );
          ref.read(courseDetailsControllerProvider(widget.course.id).notifier).addQuestion(saved);
        },
      );
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }

  void _openQuestionAuthoringFromSelection(_Ctx active) {
    final CourseDetailsState st = ref.read(
      courseDetailsControllerProvider(widget.course.id),
    );
    final bool hasTreeSelection = _selectionMode && !_treeSelection.isEmpty;
    final QuestionAuthoringLaunchContext launchContext =
        _buildAuthoringLaunchContext(active, st, hasTreeSelection: hasTreeSelection);

    final Set<int> moduleIds = hasTreeSelection
        ? {..._treeSelection.moduleIds}
        : (active.type == _CType.module
            ? <int>{if (active.module != null) active.module!.id}
            : const <int>{});

    final Set<int> materialIds = hasTreeSelection
        ? {..._treeSelection.materialIds}
        : (active.type == _CType.material
            ? <int>{if (active.material != null) active.material!.id}
            : const <int>{});

    final Set<int> topicIds = hasTreeSelection
        ? {..._treeSelection.topicIds}
        : (active.type == _CType.topic
            ? <int>{if (active.topic != null) active.topic!.id}
            : const <int>{});

    if (moduleIds.isEmpty && materialIds.isEmpty && topicIds.isEmpty) {
      _openGenerateDialog(
        moduleId: active.module?.id,
        materialId: active.material?.id,
        topicId: active.topic?.id,
      );
      return;
    }

    setState(() {
      _authoringModuleIds = moduleIds;
      _authoringMaterialIds = materialIds;
      _authoringTopicIds = topicIds;
      _authoringLaunchContext = launchContext;
      _showQuestionAuthoring = true;
      _hideFooterForActive = true;
    });
    _persistUiState();
  }

  QuestionAuthoringLaunchContext _buildAuthoringLaunchContext(
    _Ctx active,
    CourseDetailsState st, {
    required bool hasTreeSelection,
  }) {
    if (!hasTreeSelection) {
      switch (active.type) {
        case _CType.module:
          final ModuleItem? module = active.module;
          return QuestionAuthoringLaunchContext(
            kind: QuestionAuthoringScopeKind.module,
            title: module?.title ?? 'Selected module',
            subtitle: 'Questions will be built from every topic and subtopic inside this module.',
            selectedModuleId: module?.id,
            selectedModuleIds: <int>{if (module != null) module.id},
          );
        case _CType.material:
          final ModuleItem? module = active.module;
          final MaterialItem? material = active.material;
          return QuestionAuthoringLaunchContext(
            kind: QuestionAuthoringScopeKind.material,
            title: material?.displayTitle ?? 'Selected material',
            subtitle: module == null
                ? 'Questions will be built from this file structure.'
                : '${module.title} • questions will use this file topics and subtopics.',
            selectedModuleId: module?.id,
            selectedMaterialId: material?.id,
            selectedModuleIds: <int>{if (module != null) module.id},
            selectedMaterialIds: <int>{if (material != null) material.id},
          );
        case _CType.topic:
          final ModuleItem? module = active.module;
          final MaterialItem? material = active.material;
          final TopicItem? topic = active.topic;
          final bool isSubtopic = topic?.parentTopicId != null;
          return QuestionAuthoringLaunchContext(
            kind: isSubtopic
                ? QuestionAuthoringScopeKind.subtopic
                : QuestionAuthoringScopeKind.topic,
            title: topic?.title ?? 'Selected topic',
            subtitle: isSubtopic
                ? 'Questions will target this specific subtopic.'
                : 'Questions will use this topic and its subtopics if they exist.',
            selectedModuleId: module?.id,
            selectedMaterialId: material?.id,
            selectedTopicId: topic?.id,
            selectedModuleIds: <int>{if (module != null) module.id},
            selectedMaterialIds: <int>{if (material != null) material.id},
            selectedTopicIds: <int>{if (topic != null) topic.id},
          );
      }
    }

    final Set<int> containingModuleIds = <int>{};
    final Set<int> containingMaterialIds = <int>{};
    final Set<int> selectedTopicIds = {..._treeSelection.topicIds};

    for (final ModuleItem module in st.modules) {
      final List<TopicItem> topics = st.topics[module.id] ?? const <TopicItem>[];
      for (final TopicItem topic in topics) {
        if (!selectedTopicIds.contains(topic.id)) continue;
        containingModuleIds.add(module.id);
        containingMaterialIds.add(topic.materialId);
      }
    }

    final Set<int> moduleIds = <int>{
      ...containingModuleIds,
      ..._treeSelection.moduleIds,
    };
    final Set<int> materialIds = <int>{
      ...containingMaterialIds,
      ..._treeSelection.materialIds,
    };

    ModuleItem? selectedModule;
    MaterialItem? selectedMaterial;
    TopicItem? selectedTopic;

    if (_treeSelection.moduleIds.length == 1) {
      selectedModule = _findModuleById(st, _treeSelection.moduleIds.first);
    }
    if (_treeSelection.materialIds.length == 1) {
      selectedMaterial = _findMaterialById(st, _treeSelection.materialIds.first);
    }
    if (_treeSelection.topicIds.length == 1) {
      selectedTopic = _findTopicById(st, _treeSelection.topicIds.first);
      selectedMaterial ??= selectedTopic == null ? null : _findMaterialById(st, selectedTopic.materialId);
      selectedModule ??= selectedMaterial == null ? null : _findModuleById(st, selectedMaterial.moduleId);
    }

    if (selectedModule != null && _treeSelection.moduleIds.length == 1) {
      return QuestionAuthoringLaunchContext(
        kind: QuestionAuthoringScopeKind.module,
        title: selectedModule.title,
        subtitle: 'Full module selected from the structure tree.',
        selectedModuleId: selectedModule.id,
        selectedModuleIds: moduleIds,
        selectedMaterialIds: materialIds,
        selectedTopicIds: selectedTopicIds,
      );
    }

    if (selectedMaterial != null && _treeSelection.materialIds.length == 1) {
      return QuestionAuthoringLaunchContext(
        kind: QuestionAuthoringScopeKind.material,
        title: selectedMaterial.displayTitle,
        subtitle: 'Full material file selected from the structure tree.',
        selectedModuleId: selectedModule?.id ?? selectedMaterial.moduleId,
        selectedMaterialId: selectedMaterial.id,
        selectedModuleIds: moduleIds,
        selectedMaterialIds: materialIds,
        selectedTopicIds: selectedTopicIds,
      );
    }

    if (selectedTopic != null && _treeSelection.topicIds.length == 1) {
      final bool isSubtopic = selectedTopic.parentTopicId != null;
      return QuestionAuthoringLaunchContext(
        kind: isSubtopic
            ? QuestionAuthoringScopeKind.subtopic
            : QuestionAuthoringScopeKind.topic,
        title: selectedTopic.title,
        subtitle: isSubtopic
            ? 'One subtopic selected from the structure tree.'
            : 'One topic selected from the structure tree.',
        selectedModuleId: selectedModule?.id,
        selectedMaterialId: selectedMaterial?.id,
        selectedTopicId: selectedTopic.id,
        selectedModuleIds: moduleIds,
        selectedMaterialIds: materialIds,
        selectedTopicIds: selectedTopicIds,
      );
    }

    return QuestionAuthoringLaunchContext(
      kind: QuestionAuthoringScopeKind.selection,
      title: '${selectedTopicIds.length} selected content targets',
      subtitle: 'Custom selection across ${moduleIds.length} module${moduleIds.length == 1 ? '' : 's'} and ${materialIds.length} file${materialIds.length == 1 ? '' : 's'}.',
      selectedModuleIds: moduleIds,
      selectedMaterialIds: materialIds,
      selectedTopicIds: selectedTopicIds,
    );
  }

  ModuleItem? _findModuleById(CourseDetailsState st, int id) {
    for (final ModuleItem module in st.modules) {
      if (module.id == id) return module;
    }
    return null;
  }

  MaterialItem? _findMaterialById(CourseDetailsState st, int id) {
    for (final List<MaterialItem> materials in st.materials.values) {
      for (final MaterialItem material in materials) {
        if (material.id == id) return material;
      }
    }
    return null;
  }

  TopicItem? _findTopicById(CourseDetailsState st, int id) {
    for (final List<TopicItem> topics in st.topics.values) {
      for (final TopicItem topic in topics) {
        if (topic.id == id) return topic;
      }
    }
    return null;
  }

  void _closeQuestionAuthoring() {
    if (!mounted) return;
    setState(() {
      _showQuestionAuthoring = false;
      _authoringModuleIds = const <int>{};
      _authoringMaterialIds = const <int>{};
      _authoringTopicIds = const <int>{};
      _authoringLaunchContext = null;
    });
    _persistUiState();
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
//  SIDEBAR
// ─────────────────────────────────────────────────────────────────────────────
