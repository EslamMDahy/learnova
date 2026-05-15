part of 'materials_tab.dart';

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
  final bool selectionMode;
  final _TreeSelectionState treeSelection;
  final VoidCallback onToggleSelectionMode;
  final VoidCallback onClearSelection;
  final void Function(ModuleItem module, bool checked) onModuleCheckChanged;
  final void Function(ModuleItem module, MaterialItem material, bool checked) onMaterialCheckChanged;
  final void Function(ModuleItem module, MaterialItem material, TopicItem topic, bool checked) onTopicCheckChanged;
  final Set<int> expandedMaterialIds;
  final Set<int> expandedTopicIds;
  final void Function(MaterialItem material) onToggleMaterialExpanded;
  final void Function(TopicItem topic) onToggleTopicExpanded;

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
    required this.selectionMode,
    required this.treeSelection,
    required this.onToggleSelectionMode,
    required this.onClearSelection,
    required this.onModuleCheckChanged,
    required this.onMaterialCheckChanged,
    required this.onTopicCheckChanged,
    required this.expandedMaterialIds,
    required this.expandedTopicIds,
    required this.onToggleMaterialExpanded,
    required this.onToggleTopicExpanded,
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
                if (selectionMode && !treeSelection.isEmpty) ...[
                  InkWell(
                    hoverColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                    onTap: onClearSelection,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: _K.blueSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${treeSelection.totalCount}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                InkWell(
                  hoverColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                  onTap: onToggleSelectionMode,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: selectionMode ? _K.blueSoft : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selectionMode ? AppColors.primary.withOpacity(0.18) : _K.div,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selectionMode ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          size: 12,
                          color: selectionMode ? AppColors.primary : AppColors.textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Select',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: selectionMode ? AppColors.primary : AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
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
                                  selectionMode: selectionMode,
                                  treeSelection: treeSelection,
                                  onModuleCheckChanged: (checked) => onModuleCheckChanged(m, checked),
                                  onMaterialCheckChanged: (material, checked) => onMaterialCheckChanged(m, material, checked),
                                  onTopicCheckChanged: (material, topic, checked) => onTopicCheckChanged(m, material, topic, checked),
                                  expandedMaterialIds: expandedMaterialIds,
                                  expandedTopicIds: expandedTopicIds,
                                  onToggleMaterialExpanded: onToggleMaterialExpanded,
                                  onToggleTopicExpanded: onToggleTopicExpanded,
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



List<TopicItem> _rootTopicsForMaterial(List<TopicItem> topics) {
  final roots = topics.where((t) => t.parentTopicId == null).toList()
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  return roots;
}

List<TopicItem> _childTopicsForParent(List<TopicItem> topics, int parentTopicId) {
  final children = topics.where((t) => t.parentTopicId == parentTopicId).toList()
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  return children;
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
              const SizedBox(height: 12),
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
  final ModuleItem module;
  final bool isExpanded;
  final List<MaterialItem> materials;
  final bool loading;
  final List<TopicItem> moduleTopics;
  final _Ctx? active;
  final bool isDragging;
  final Widget? dragHandle;
  final VoidCallback onModuleTap;
  final void Function(MaterialItem) onMaterialTap;
  final void Function(MaterialItem, TopicItem) onTopicTap;
  final VoidCallback onAddMaterial;
  final bool selectionMode;
  final _TreeSelectionState treeSelection;
  final ValueChanged<bool> onModuleCheckChanged;
  final void Function(MaterialItem material, bool checked) onMaterialCheckChanged;
  final void Function(MaterialItem material, TopicItem topic, bool checked) onTopicCheckChanged;
  final Set<int> expandedMaterialIds;
  final Set<int> expandedTopicIds;
  final void Function(MaterialItem material) onToggleMaterialExpanded;
  final void Function(TopicItem topic) onToggleTopicExpanded;

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
    required this.selectionMode,
    required this.treeSelection,
    required this.onModuleCheckChanged,
    required this.onMaterialCheckChanged,
    required this.onTopicCheckChanged,
    required this.expandedMaterialIds,
    required this.expandedTopicIds,
    required this.onToggleMaterialExpanded,
    required this.onToggleTopicExpanded,
  });

  bool get _isSel => active?.type == _CType.module && active?.module?.id == module.id;

  Set<int> _selectableTopicIdsForTopic(TopicItem topic, List<TopicItem> allTopics) {
    final children = _childTopicsForParent(allTopics, topic.id);
    if (children.isEmpty) {
      return <int>{topic.id};
    }

    final ids = <int>{};
    for (final child in children) {
      ids.addAll(_selectableTopicIdsForTopic(child, allTopics));
    }
    return ids;
  }

  Set<int> _selectableTopicIdsForMaterial(MaterialItem material) {
    final materialTopics = moduleTopics.where((topic) => topic.materialId == material.id).toList();
    final roots = _rootTopicsForMaterial(materialTopics);
    final ids = <int>{};
    for (final root in roots) {
      ids.addAll(_selectableTopicIdsForTopic(root, materialTopics));
    }
    return ids;
  }

  bool? _moduleCheckValue() {
    final selectableTopicIds = <int>{};
    for (final material in materials) {
      selectableTopicIds.addAll(_selectableTopicIdsForMaterial(material));
    }

    if (selectableTopicIds.isEmpty) return false;

    final selectedCount = selectableTopicIds.where(treeSelection.topicIds.contains).length;
    if (selectedCount == 0) return false;
    if (selectedCount == selectableTopicIds.length) return true;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _isSel || isDragging;
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
            margin: const EdgeInsets.fromLTRB(6, 0, 6, 2),
            padding: const EdgeInsets.fromLTRB(6, 7, 6, 7),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFF7FAFF) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? const Color(0xFFD5E5FF) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                dragHandle ?? const SizedBox(width: 18, height: 18),
                if (selectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Transform.scale(
                      scale: .88,
                      child: Checkbox(
                        value: _moduleCheckValue(),
                        tristate: true,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (value) => onModuleCheckChanged(value == true),
                      ),
                    ),
                  ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded,
                  size: 14,
                  color: const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.folder_rounded,
                  size: 14,
                  color: selected ? AppColors.primary : const Color(0xFFEAB308),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.2,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: selected ? AppColors.primary : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${materials.length} material${materials.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 10.2, color: Color(0xFF94A3B8), height: 1.1),
                      ),
                    ],
                  ),
                ),
                if (module.isPublished)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (isExpanded) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    hoverColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                    onTap: onAddMaterial,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.add_rounded, size: 14, color: Color(0xFF94A3B8)),
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
        margin: const EdgeInsets.fromLTRB(34, 6, 6, 4),
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
    return Padding(
      padding: const EdgeInsets.only(left: 26),
      child: Column(
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
            selectionMode: selectionMode,
            treeSelection: treeSelection,
            onCheckChanged: (checked) => onMaterialCheckChanged(mat, checked),
            onTopicCheckChanged: (topic, checked) => onTopicCheckChanged(mat, topic, checked),
            isExpanded: expandedMaterialIds.contains(mat.id),
            expandedTopicIds: expandedTopicIds,
            onToggleExpanded: () => onToggleMaterialExpanded(mat),
            onToggleTopicExpanded: onToggleTopicExpanded,
          );
        }).toList(),
      ),
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
  final bool selectionMode;
  final _TreeSelectionState treeSelection;
  final ValueChanged<bool> onCheckChanged;
  final void Function(TopicItem topic, bool checked) onTopicCheckChanged;
  final bool isExpanded;
  final Set<int> expandedTopicIds;
  final VoidCallback onToggleExpanded;
  final void Function(TopicItem topic) onToggleTopicExpanded;

  const _MatRowWidget({
    required this.material,
    required this.topics,
    required this.isSelected,
    required this.active,
    required this.onTap,
    required this.onTopicTap,
    required this.selectionMode,
    required this.treeSelection,
    required this.onCheckChanged,
    required this.onTopicCheckChanged,
    required this.isExpanded,
    required this.expandedTopicIds,
    required this.onToggleExpanded,
    required this.onToggleTopicExpanded,
  });

  Set<int> _selectableTopicIdsForTopic(TopicItem topic) {
    final children = _childTopicsForParent(topics, topic.id);
    if (children.isEmpty) {
      return <int>{topic.id};
    }

    final ids = <int>{};
    for (final child in children) {
      ids.addAll(_selectableTopicIdsForTopic(child));
    }
    return ids;
  }

  Set<int> _selectableTopicIdsForMaterial() {
    final roots = _rootTopicsForMaterial(topics);
    final ids = <int>{};
    for (final root in roots) {
      ids.addAll(_selectableTopicIdsForTopic(root));
    }
    return ids;
  }

  bool? _materialCheckValue() {
    final selectableTopicIds = _selectableTopicIdsForMaterial();
    if (selectableTopicIds.isEmpty) return false;

    final selectedCount = selectableTopicIds.where(treeSelection.topicIds.contains).length;
    if (selectedCount == 0) return false;
    if (selectedCount == selectableTopicIds.length) return true;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const iconMap = {
      'video': (Icons.play_circle_outline_rounded, Color(0xFF2563EB)),
      'pdf': (Icons.picture_as_pdf_outlined, Color(0xFFEF4444)),
      'quiz': (Icons.quiz_outlined, Color(0xFF7C3AED)),
    };
    final (ico, col) = iconMap[material.type] ?? (Icons.article_outlined, AppColors.textMuted);
    final roots = _rootTopicsForMaterial(topics);

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
            margin: const EdgeInsets.fromLTRB(0, 1, 4, 1),
            padding: const EdgeInsets.fromLTRB(8, 7, 6, 7),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF7FAFF) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? const Color(0xFFD5E5FF) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                if (selectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Transform.scale(
                      scale: .86,
                      child: Checkbox(
                        value: _materialCheckValue(),
                        tristate: true,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (value) => onCheckChanged(value == true),
                      ),
                    ),
                  ),
                InkWell(
                  hoverColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                  onTap: roots.isNotEmpty ? onToggleExpanded : null,
                  child: Icon(
                    roots.isEmpty
                        ? Icons.remove_rounded
                        : (isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded),
                    size: 13,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: col.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(ico, size: 10, color: col),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.1,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? AppColors.primary : const Color(0xFF334155),
                        ),
                      ),
                      if (topics.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${roots.length} topic${roots.length == 1 ? '' : 's'}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), height: 1.1),
                        ),
                      ],
                    ],
                  ),
                ),
                _Dot(status: material.status),
              ],
            ),
          ),
        ),
        if (roots.isNotEmpty && isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Column(
              children: roots
                  .map(
                    (topic) => _SidebarTopicNode(
                      topic: topic,
                      allTopics: topics,
                      active: active,
                      depth: 0,
                      onTap: onTopicTap,
                      selectionMode: selectionMode,
                      treeSelection: treeSelection,
                      onTopicCheckChanged: onTopicCheckChanged,
                      isExpanded: expandedTopicIds.contains(topic.id),
                      onToggleExpanded: () => onToggleTopicExpanded(topic),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _SidebarTopicNode extends StatelessWidget {
  final TopicItem topic;
  final List<TopicItem> allTopics;
  final _Ctx? active;
  final int depth;
  final ValueChanged<TopicItem> onTap;
  final bool selectionMode;
  final _TreeSelectionState treeSelection;
  final void Function(TopicItem topic, bool checked) onTopicCheckChanged;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  const _SidebarTopicNode({
    required this.topic,
    required this.allTopics,
    required this.active,
    required this.depth,
    required this.onTap,
    required this.selectionMode,
    required this.treeSelection,
    required this.onTopicCheckChanged,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  Set<int> _selectableTopicIdsForTopic(TopicItem item) {
    final children = _childTopicsForParent(allTopics, item.id);
    if (children.isEmpty) {
      return <int>{item.id};
    }

    final ids = <int>{};
    for (final child in children) {
      ids.addAll(_selectableTopicIdsForTopic(child));
    }
    return ids;
  }

  bool? _topicCheckValue() {
    final selectableTopicIds = _selectableTopicIdsForTopic(topic);
    if (selectableTopicIds.isEmpty) return false;

    final selectedCount = selectableTopicIds.where(treeSelection.topicIds.contains).length;
    if (selectedCount == 0) return false;
    if (selectedCount == selectableTopicIds.length) return true;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = active?.type == _CType.topic && active?.topic?.id == topic.id;
    final children = depth == 0 ? _childTopicsForParent(allTopics, topic.id) : const <TopicItem>[];
    final isRootTopic = depth == 0;
    final baseIndent = isRootTopic ? 10.0 : 34.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(baseIndent, 0, 4, 0),
          child: Stack(
            children: [
              if (isRootTopic)
                Positioned(
                  left: 6,
                  top: 0,
                  bottom: children.isNotEmpty && isExpanded ? -2 : 14,
                  child: Container(width: 1, color: const Color(0xFFE2E8F0)),
                )
              else
                Positioned(
                  left: 6,
                  top: 0,
                  bottom: 14,
                  child: Container(width: 1, color: const Color(0xFFE2E8F0)),
                ),
              Positioned(
                left: 6,
                top: 14,
                child: Container(width: 10, height: 1, color: const Color(0xFFE2E8F0)),
              ),
              InkWell(
                hoverColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                onTap: () => onTap(topic),
                child: Container(
                  margin: const EdgeInsets.only(left: 16),
                  padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFEFF6FF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: selected ? const Color(0xFFD5E5FF) : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (selectionMode)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Transform.scale(
                            scale: .84,
                            child: Checkbox(
                              value: _topicCheckValue(),
                              tristate: true,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (value) => onTopicCheckChanged(topic, value == true),
                            ),
                          ),
                        ),
                      if (isRootTopic)
                        InkWell(
                          hoverColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                          onTap: children.isNotEmpty ? onToggleExpanded : null,
                          child: Icon(
                            children.isEmpty
                                ? Icons.remove_rounded
                                : (isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded),
                            size: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        )
                      else
                        const SizedBox(width: 12, height: 12),
                      const SizedBox(width: 4),
                      Icon(
                        isRootTopic ? Icons.topic_outlined : Icons.subdirectory_arrow_right_rounded,
                        size: isRootTopic ? 12 : 11,
                        color: selected ? AppColors.primary : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          topic.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isRootTopic ? 11.2 : 10.7,
                            height: 1.15,
                            fontWeight: selected ? FontWeight.w700 : (isRootTopic ? FontWeight.w600 : FontWeight.w500),
                            color: selected ? AppColors.primary : (isRootTopic ? const Color(0xFF334155) : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                      if (isRootTopic && children.isNotEmpty)
                        Text(
                          '${children.length}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isRootTopic && isExpanded)
          for (final child in children)
            _SidebarTopicNode(
              topic: child,
              allTopics: allTopics,
              active: active,
              depth: depth + 1,
              onTap: onTap,
              selectionMode: selectionMode,
              treeSelection: treeSelection,
              onTopicCheckChanged: onTopicCheckChanged,
              isExpanded: false,
              onToggleExpanded: () {},
            ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FOOTER
// ─────────────────────────────────────────────────────────────────────────────
class _FooterWidget extends StatelessWidget {
  final _Ctx ctx; final bool uploading; final bool canGenerate;
  final int? selectionCount;
  final VoidCallback onUpload, onGenerate, onClose;
  const _FooterWidget({required this.ctx, required this.uploading, required this.canGenerate,
      this.selectionCount,
      required this.onUpload, required this.onGenerate, required this.onClose});

  bool get _showSelectionLabel => (selectionCount ?? 0) > 0;
  String get _label => _showSelectionLabel
      ? '${selectionCount!} selected'
      : switch (ctx.type) {
          _CType.module   => ctx.module?.title ?? 'Module',
          _CType.material => ctx.material?.displayTitle ?? 'Material',
          _CType.topic    => ctx.topic?.title ?? 'Topic',
        };
  IconData get _icon => _showSelectionLabel
      ? Icons.checklist_rounded
      : switch (ctx.type) {
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
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 112),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1080;

            final mainColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ModuleCanvasHeader(
                  module: module,
                  materialCount: materials.length,
                  onUpload: uploading ? null : onUpload,
                ),
                const SizedBox(height: 18),
                if (uploading) ...[
                  _UploadProgressWidget(progress: uploadProgress),
                  const SizedBox(height: 18),
                ],
                _CanvasSection(
                  title: 'Overview',
                  icon: Icons.grid_view_rounded,
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, sectionConstraints) {
                          final compact = sectionConstraints.maxWidth < 760;
                          final children = [
                            _SoftStatTile(
                              icon: Icons.layers_rounded,
                              iconBg: const Color(0xFFEAF2FF),
                              iconFg: AppColors.primary,
                              label: 'Position',
                              value: '#${module.orderIndex + 1}',
                              description: 'Current order inside this course.',
                            ),
                            _SoftStatTile(
                              icon: module.isPublished ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              iconBg: module.isPublished ? const Color(0xFFEAFBF0) : const Color(0xFFFFF4E5),
                              iconFg: module.isPublished ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                              label: 'Visibility',
                              value: module.isPublished ? 'Published' : 'Draft',
                              description: module.isPublished ? 'Students can access this module.' : 'Hidden from students right now.',
                            ),
                            _SoftStatTile(
                              icon: Icons.folder_open_rounded,
                              iconBg: const Color(0xFFF1F5F9),
                              iconFg: const Color(0xFF64748B),
                              label: 'Materials',
                              value: '${materials.length}',
                              description: '$readyMaterials ready and $processingMaterials processing.',
                            ),
                          ];

                          if (compact) {
                            return Column(
                              children: [
                                for (var i = 0; i < children.length; i++) ...[
                                  children[i],
                                  if (i != children.length - 1) const SizedBox(height: 12),
                                ],
                              ],
                            );
                          }

                          return Row(
                            children: [
                              for (var i = 0; i < children.length; i++) ...[
                                Expanded(child: children[i]),
                                if (i != children.length - 1) const SizedBox(width: 14),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _DescriptionBlock(
                        hasDescription: hasDescription,
                        description: description,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _CanvasSection(
                  title: 'Materials',
                  icon: Icons.folder_copy_rounded,
                  trailing: _SmBtn(
                    icon: Icons.upload_rounded,
                    label: 'Upload',
                    disabled: uploading,
                    onTap: onUpload,
                  ),
                  child: materials.isEmpty
                      ? _MatEmptyWidget(onUpload: onUpload)
                      : Column(
                          children: materials.asMap().entries.map(
                            (e) => Padding(
                              padding: EdgeInsets.only(bottom: e.key == materials.length - 1 ? 0 : 12),
                              child: _ModuleMaterialCard(
                                material: e.value,
                                onTap: () => onMaterialTap(e.value),
                              ),
                            ),
                          ).toList(),
                        ),
                ),
              ],
            );

            final sideColumn = Column(
              children: [
                _CanvasSection(
                  title: 'Quick actions',
                  icon: Icons.auto_fix_high_rounded,
                  compactHeader: true,
                  child: Column(
                    children: [
                      _ActionTile(
                        icon: Icons.drive_file_rename_outline_rounded,
                        iconBg: const Color(0xFFEAF2FF),
                        iconFg: AppColors.primary,
                        title: 'Rename module',
                        subtitle: 'Update the module title shown across the course.',
                        onTap: onRename,
                      ),
                      const SizedBox(height: 10),
                      _ActionTile(
                        icon: Icons.notes_rounded,
                        iconBg: const Color(0xFFF1F5F9),
                        iconFg: const Color(0xFF64748B),
                        title: 'Edit description',
                        subtitle: hasDescription ? 'Refine the current summary and teaching context.' : 'Add a short summary for this module.',
                        onTap: onEditDescription,
                      ),
                      const SizedBox(height: 10),
                      _ActionTile(
                        icon: Icons.upload_file_rounded,
                        iconBg: const Color(0xFFEAF2FF),
                        iconFg: AppColors.primary,
                        title: 'Upload material',
                        subtitle: uploading ? 'Upload in progress…' : 'Add a PDF, video, or document to this module.',
                        onTap: uploading ? null : onUpload,
                        emphasis: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _CanvasSection(
                  title: 'Module status',
                  icon: Icons.tune_rounded,
                  compactHeader: true,
                  child: Column(
                    children: [
                      _ActionTile(
                        icon: module.isPublished ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        iconBg: module.isPublished ? const Color(0xFFFFF4E5) : const Color(0xFFEAFBF0),
                        iconFg: module.isPublished ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                        title: module.isPublished ? 'Unpublish module' : 'Publish module',
                        subtitle: module.isPublished ? 'Hide this module from students.' : 'Make this module visible to students.',
                        onTap: onTogglePublish,
                      ),
                      const SizedBox(height: 10),
                      _ActionTile(
                        icon: Icons.swap_vert_rounded,
                        iconBg: const Color(0xFFF1F5F9),
                        iconFg: const Color(0xFF64748B),
                        title: 'Change position',
                        subtitle: 'Currently #${module.orderIndex + 1} in the course structure.',
                        onTap: onChangePosition,
                      ),
                      const SizedBox(height: 10),
                      _ActionTile(
                        icon: Icons.share_rounded,
                        iconBg: const Color(0xFFEAFBF0),
                        iconFg: const Color(0xFF16A34A),
                        title: 'Share with another course',
                        subtitle: module.sharedWithCourseIds.isEmpty
                            ? 'Not shared with any other course.'
                            : 'Shared with ${module.sharedWithCourseIds.length} course${module.sharedWithCourseIds.length == 1 ? '' : 's'}.',
                        onTap: onShare,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _CanvasDangerSection(onDelete: onDelete),
              ],
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 8, child: mainColumn),
                  const SizedBox(width: 20),
                  SizedBox(width: 320, child: sideColumn),
                ],
              );
            }

            return Column(
              children: [
                mainColumn,
                const SizedBox(height: 18),
                sideColumn,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ModuleCanvasHeader extends StatelessWidget {
  final ModuleItem module;
  final int materialCount;
  final VoidCallback? onUpload;

  const _ModuleCanvasHeader({
    required this.module,
    required this.materialCount,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final description = (module.description ?? '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeaderChip(
                    label: module.isPublished ? 'Published' : 'Draft',
                    bg: module.isPublished ? const Color(0xFFEAFBF0) : const Color(0xFFFFF4E5),
                    fg: module.isPublished ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                  ),
                  _HeaderChip(
                    label: '$materialCount material${materialCount == 1 ? '' : 's'}',
                    bg: const Color(0xFFF1F5F9),
                    fg: const Color(0xFF475569),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                module.title,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textTitle,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description.isNotEmpty
                    ? description
                    : 'Organize files, manage visibility, and keep this module ready for students.',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textMuted,
                  height: 1.6,
                ),
              ),
            ],
          );

          final side = Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Module order',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '#${module.orderIndex + 1}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTitle,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Updated ${_relativeDate(module.updatedAt)}',
                  style: const TextStyle(
                    fontSize: 11.8,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onUpload,
                    icon: const Icon(Icons.upload_rounded, size: 16),
                    label: const Text('Upload material'),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [titleBlock, const SizedBox(height: 18), side],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 18),
              SizedBox(width: 240, child: side),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _HeaderChip({
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _CanvasSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final bool compactHeader;

  const _CanvasSection({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.compactHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compactHeader ? 18 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTitle,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SoftStatTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String label;
  final String value;
  final String description;

  const _SoftStatTile({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.label,
    required this.value,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: iconFg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTitle,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionBlock extends StatelessWidget {
  final bool hasDescription;
  final String description;

  const _DescriptionBlock({
    required this.hasDescription,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.notes_rounded, size: 18, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasDescription ? description : 'No description added yet',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTitle,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasDescription
                      ? 'This text helps instructors and students understand the purpose of the module.'
                      : 'Add a short summary to make this module clearer for instructors and students.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatefulWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool emphasis;

  const _ActionTile({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasis = false,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) {
        if (!disabled) setState(() => _hovered = true);
      },
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.emphasis
                ? const Color(0xFFEFF6FF)
                : (_hovered && !disabled ? const Color(0xFFF8FAFC) : const Color(0xFFFDFDFD)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Opacity(
            opacity: disabled ? 0.45 : 1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: widget.iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(widget.icon, size: 18, color: widget.iconFg),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _hovered && !disabled ? AppColors.primary : AppColors.textTitle,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: disabled ? AppColors.textHint : AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CanvasDangerSection extends StatelessWidget {
  final VoidCallback? onDelete;

  const _CanvasDangerSection({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
              SizedBox(width: 10),
              Text(
                'Danger zone',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF991B1B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Delete this module only when you are sure its content is no longer needed in the course.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF7F1D1D),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('Delete module'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF145CCB), Color(0xFF137FEC), Color(0xFF4CB5FF)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final rightCard = Container(
            constraints: const BoxConstraints(minWidth: 180),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Module order', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.74))),
                const SizedBox(height: 8),
                Text('#${module.orderIndex + 1}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, height: 1.0)),
                const SizedBox(height: 14),
                Text('Updated ${_relativeDate(module.updatedAt)}', style: TextStyle(fontSize: 11.8, height: 1.45, color: Colors.white.withOpacity(0.86))),
              ],
            ),
          );

          final body = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
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
                const SizedBox(height: 18),
                Text(
                  module.title,
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, height: 1.04),
                ),
                const SizedBox(height: 12),
                Text(
                  description.isNotEmpty
                      ? description
                      : 'This module groups related materials and learning assets inside the course structure.',
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.86), height: 1.6),
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [body, const SizedBox(height: 20), rightCard],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: body), const SizedBox(width: 20), rightCard],
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 14.0;
        final itemWidth = constraints.maxWidth < 620
            ? constraints.maxWidth
            : (constraints.maxWidth < 1040
                ? (constraints.maxWidth - spacing) / 2
                : (constraints.maxWidth - (spacing * 3)) / 4);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) => SizedBox(
            width: itemWidth,
            child: Container(
              constraints: const BoxConstraints(minHeight: 92),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _K.div),
                boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 3))],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: item.$4, borderRadius: BorderRadius.circular(13)),
                    child: Icon(item.$1, size: 20, color: item.$5),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(item.$2, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                        const SizedBox(height: 6),
                        Text(item.$3, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textTitle, height: 1.28)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )).toList(),
        );
      },
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _K.div),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 18, color: iconFg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.2)),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: multiline ? null : 1,
                  overflow: multiline ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textTitle, height: 1.45),
                ),
                const SizedBox(height: 4),
                Text(caption, style: const TextStyle(fontSize: 11.8, color: AppColors.textMuted, height: 1.55)),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final textBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDanger ? const Color(0xFFB91C1C) : AppColors.textTitle)),
              const SizedBox(height: 6),
              Text(description, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.45)),
            ],
          );
          final button = OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: fg,
              side: BorderSide(color: fg),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(actionLabel),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [textBlock, const SizedBox(height: 14), button],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: textBlock), const SizedBox(width: 14), button],
          );
        },
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFD),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _K.div),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: ib, borderRadius: BorderRadius.circular(12)),
              child: Icon(ico, size: 22, color: ic),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(material.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textTitle, height: 1.3)),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(typeLabel, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textHint, letterSpacing: 0.4)),
                      if (material.pageCount != null)
                        Text('${material.pageCount} pages', style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
