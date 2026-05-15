import 'package:flutter/material.dart';

import '../../../../../core/ui/app_colors.dart';
import '../../../../data/materials_models.dart';
import '../../../../data/modules_models.dart';
import '../../../../data/topics_models.dart';
import '../../../controllers/course_details_state.dart';
import '../materials_tab_colors.dart';
import '../materials_tab_context.dart';
import 'module_row_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Sidebar — left-hand navigation panel for modules/materials/topics
// ─────────────────────────────────────────────────────────────────────────────

class MaterialsSidebarWidget extends StatelessWidget {
  final CourseDetailsState state;
  final Set<int>           expanded;
  final MaterialTabContext? active;
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

  const MaterialsSidebarWidget({
    super.key,
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
          _buildHeader(),
          Expanded(child: _buildList()),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
          _IconBtn(icon: Icons.refresh_rounded, tooltip: 'Refresh', onTap: onRefresh),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (state.modulesLoading && state.modules.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (state.modules.isEmpty) {
      return _SidebarEmptyWidget(onAdd: onAddModule);
    }

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
          child: ModuleRowWidget(
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
  }

  Widget _buildFooter() {
    return Container(
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sidebar empty state
// ─────────────────────────────────────────────────────────────────────────────

class _SidebarEmptyWidget extends StatelessWidget {
  final VoidCallback onAdd;
  const _SidebarEmptyWidget({required this.onAdd});

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

// ─────────────────────────────────────────────────────────────────────────────
//  Small icon button — used in sidebar header
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String   tooltip;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(icon, size: 14, color: AppColors.textHint),
          ),
        ),
      );
}
