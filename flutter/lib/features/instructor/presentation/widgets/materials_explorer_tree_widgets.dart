import 'package:flutter/material.dart';
import 'materials_explorer_constants.dart';
import 'materials_explorer_micro_widgets.dart';

// =============================================================================
//  TREE NODES
// =============================================================================

/// One complete module row + its children
class ModuleTreeItem extends StatelessWidget {
  final Node module;
  final String? selectedId;
  final ValueChanged<Node> onModule, onMaterial, onTopic, onRename, onDelete;

  const ModuleTreeItem({
    super.key,
    required this.module, required this.selectedId,
    required this.onModule, required this.onMaterial, required this.onTopic,
    required this.onRename, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sel = selectedId == module.id;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Module row
      SidebarRow(
        indent: 0, isSelected: sel,
        leading: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            module.isExpanded
              ? Icons.keyboard_arrow_down_rounded
              : Icons.keyboard_arrow_right_rounded,
            size: 14, color: K.muted,
          ),
          const SizedBox(width: 5),
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E0),
              borderRadius: BorderRadius.circular(5),),
            child: const Icon(Icons.folder_rounded, size: 12, color: Color(0xFFF97316)),
          ),
        ],),
        title: module.title,
        titleStyle: TextStyle(
          fontSize: 12.5, fontWeight: FontWeight.w700,
          color: sel ? K.blue : K.text,),
        trailing: CtxMenu(items: [
          MItem(icon: Icons.upload_rounded, label: 'Upload material',
            color: K.blue, onTap: () => onModule(module),),
          const MDivider(),
          MItem(icon: Icons.edit_outlined, label: 'Rename',
            onTap: () => onRename(module),),
          MItem(icon: Icons.delete_outline, label: 'Delete',
            color: K.red, onTap: () => onDelete(module),),
        ],),
        onTap: () => onModule(module),
      ),
      // Materials
      if (module.isExpanded)
        ...module.children.map((mat) => MaterialTreeItem(
          mat: mat, selectedId: selectedId,
          onMaterial: onMaterial, onTopic: onTopic,
          onRename: onRename, onDelete: onDelete,
        ),),
    ],);
  }
}

class MaterialTreeItem extends StatelessWidget {
  final Node mat;
  final String? selectedId;
  final ValueChanged<Node> onMaterial, onTopic, onRename, onDelete;

  const MaterialTreeItem({
    super.key,
    required this.mat, required this.selectedId,
    required this.onMaterial, required this.onTopic,
    required this.onRename, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sel    = selectedId == mat.id;
    final icon   = _mkIcon(mat.mk);
    final col    = _mkColor(mat.mk);
    final bg     = _mkBg(mat.mk);
    final topics = mat.children.where((c) => c.nk == NK.topic).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SidebarRow(
        indent: 1, isSelected: sel,
        leading: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            topics.isNotEmpty
              ? (mat.isExpanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_right_rounded)
              : Icons.remove_rounded,
            size: 13, color: K.hint,
          ),
          const SizedBox(width: 5),
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
            child: Icon(icon, size: 11, color: col),
          ),
        ],),
        title: mat.title,
        titleStyle: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: sel ? K.blue : const Color(0xFF2D3748),),
        trailing: CtxMenu(items: [
          MItem(icon: Icons.label_outline_rounded, label: 'Add topic manually',
            color: K.purple, onTap: () => onMaterial(mat),),
          MItem(icon: Icons.auto_awesome_rounded, label: 'Generate topics with AI',
            color: K.blue, onTap: () => onMaterial(mat),),
          const MDivider(),
          MItem(icon: Icons.edit_outlined, label: 'Rename', onTap: () => onRename(mat)),
          MItem(icon: Icons.delete_outline, label: 'Delete',
            color: K.red, onTap: () => onDelete(mat),),
        ],),
        onTap: () => onMaterial(mat),
      ),
      // Topics
      if (mat.isExpanded)
        ...topics.map((t) {
          final tsel = selectedId == t.id;
          return SidebarRow(
            indent: 2, isSelected: tsel,
            leading: Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                color: K.purpleSoft, borderRadius: BorderRadius.circular(4),),
              child: const Icon(Icons.label_rounded, size: 10, color: K.purple),
            ),
            title: t.title,
            titleStyle: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w500,
              color: tsel ? K.purple : K.muted,),
            onTap: () => onTopic(t),
          );
        }),
    ],);
  }

  static IconData _mkIcon(MK? k) {
    switch (k) {
      case MK.video: return Icons.play_circle_rounded;
      case MK.doc:   return Icons.description_rounded;
      case MK.ppt:   return Icons.slideshow_rounded;
      default:        return Icons.picture_as_pdf_rounded;
    }
  }

  static Color _mkColor(MK? k) {
    switch (k) {
      case MK.video: return K.blue;
      case MK.doc:   return const Color(0xFF1E40AF);
      case MK.ppt:   return K.orange;
      default:        return K.red;
    }
  }

  static Color _mkBg(MK? k) {
    switch (k) {
      case MK.video: return K.blueSoft;
      case MK.doc:   return K.badgeDocBg;
      case MK.ppt:   return K.orangeSoft;
      default:        return K.redSoft;
    }
  }
}

/// Base sidebar row — animated hover + selected
class SidebarRow extends StatefulWidget {
  final int indent;
  final bool isSelected;
  final Widget leading;
  final String title;
  final TextStyle titleStyle;
  final Widget? trailing;
  final VoidCallback onTap;

  const SidebarRow({
    super.key,
    required this.indent, required this.isSelected, required this.leading,
    required this.title, required this.titleStyle, required this.onTap,
    this.trailing,
  });

  @override
  State<SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<SidebarRow> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final lp = 14.0 + widget.indent * 18.0;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          margin: widget.isSelected
            ? const EdgeInsets.symmetric(horizontal: 6, vertical: 1)
            : const EdgeInsets.symmetric(vertical: 1),
          padding: EdgeInsets.fromLTRB(
            widget.isSelected ? lp - 4 : lp, 7, 8, 7,),
          decoration: BoxDecoration(
            color: widget.isSelected
              ? K.blueSoft
              : (_h ? const Color(0xFFF4F6F8) : Colors.transparent),
            borderRadius: widget.isSelected
              ? BorderRadius.circular(8) : null,
          ),
          child: Row(children: [
            widget.leading,
            const SizedBox(width: 7),
            Expanded(child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: widget.titleStyle,
            ),),
            if (widget.trailing != null) widget.trailing!,
          ],),
        ),
      ),
    );
  }
}
