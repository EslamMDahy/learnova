import 'package:flutter/material.dart';
import 'package:learnova/core/theme/app_theme.dart';


import '../../../../../data/materials_models.dart';
import '../../../../../data/topics_models.dart';
import '../materials_tab_colors.dart';
import '../materials_tab_context.dart';
import '../shared/status_dot_widget.dart';


// ─────────────────────────────────────────────────────────────────────────────
//  Material row (+ its nested topic rows)
// ─────────────────────────────────────────────────────────────────────────────

class MatRowWidget extends StatelessWidget {
  final MaterialItem        material;
  final List<TopicItem>     topics;
  final bool                isSelected;
  final MaterialTabContext? active;
  final VoidCallback        onTap;
  final void Function(TopicItem) onTopicTap;

  const MatRowWidget({
    super.key,
    required this.material,
    required this.topics,
    required this.isSelected,
    required this.active,
    required this.onTap,
    required this.onTopicTap,
  });

  @override
  Widget build(BuildContext context) {
    const iconMap = {
      'video': (Icons.play_circle_outline_rounded, Color(0xFF2563EB)),
      'pdf':   (Icons.picture_as_pdf_outlined,     Color(0xFFDC2626)),
      'quiz':  (Icons.quiz_outlined,               Color(0xFF7C3AED)),
    };
    final (ico, col) =
        iconMap[material.type] ?? (Icons.article_outlined, AppColors.textMuted);

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
                Container(
                    width: 1,
                    height: 14,
                    color: _K.div,
                    margin: const EdgeInsets.only(right: 8)),
                Icon(ico,
                    size: 13,
                    color: isSelected ? AppColors.primary : col),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    material.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : const Color(0xFF334155),
                    ),
                  ),
                ),
                StatusDotWidget(status: material.status),
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
                  Container(
                      width: 1,
                      height: 11,
                      color: _K.div,
                      margin: const EdgeInsets.only(right: 7)),
                  Icon(Icons.tag_rounded,
                      size: 10,
                      color: tSel ? AppColors.primary : AppColors.textHint),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            tSel ? FontWeight.w600 : FontWeight.w400,
                        color:
                            tSel ? AppColors.primary : AppColors.textMuted,
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
