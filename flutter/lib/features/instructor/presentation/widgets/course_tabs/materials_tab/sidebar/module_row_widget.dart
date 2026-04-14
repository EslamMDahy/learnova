import 'package:flutter/material.dart';

import '../../../../../../core/ui/app_colors.dart';
import '../../../../data/materials_models.dart';
import '../../../../data/modules_models.dart';
import '../../../../data/topics_models.dart';
import '../materials_tab_colors.dart';
import '../materials_tab_context.dart';
import 'mat_row_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Module row — single collapsible module in the sidebar
// ─────────────────────────────────────────────────────────────────────────────

class ModuleRowWidget extends StatelessWidget {
  final ModuleItem             module;
  final bool                   isExpanded;
  final List<MaterialItem>     materials;
  final bool                   loading;
  final List<TopicItem>        moduleTopics;
  final MaterialTabContext?    active;
  final bool                   isDragging;
  final Widget?                dragHandle;
  final VoidCallback           onModuleTap;
  final void Function(MaterialItem) onMaterialTap;
  final void Function(MaterialItem, TopicItem) onTopicTap;
  final VoidCallback           onAddMaterial;

  const ModuleRowWidget({
    super.key,
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

  bool get _isSel =>
      active?.type == _CType.module && active?.module?.id == module.id;

  @override
  Widget build(BuildContext context) {
    final highlight = _isSel || isDragging;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(highlight),
        AnimatedCrossFade(
          crossFadeState:
              isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
          firstChild: const SizedBox.shrink(),
          secondChild: _buildChildren(),
        ),
      ],
    );
  }

  Widget _buildHeader(bool highlight) {
    return InkWell(
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
              isExpanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.chevron_right_rounded,
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
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                  child: Icon(Icons.add_rounded,
                      size: 14, color: AppColors.textHint),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChildren() {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5)),
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
            Icon(Icons.info_outline_rounded,
                size: 14, color: AppColors.textHint),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No materials yet. Use the plus button to upload one.',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textHint, height: 1.35),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: materials.map((mat) {
        final matSel = active?.material?.id == mat.id &&
            (active?.type == _CType.material ||
                active?.type == _CType.topic);
        final scopedTopics =
            moduleTopics.where((t) => t.materialId == mat.id).toList();
        return MatRowWidget(
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
