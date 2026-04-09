import 'package:flutter/material.dart';

import '../../../../../../core/ui/app_colors.dart';
import 'materials_context.dart';

class MatFooterWidget extends StatelessWidget {
  final MatCtx ctx;
  final bool uploading;
  final bool canGenerate;
  final VoidCallback onUpload;
  final VoidCallback onGenerate;
  final VoidCallback onClose;

  const MatFooterWidget({
    super.key,
    required this.ctx,
    required this.uploading,
    required this.canGenerate,
    required this.onUpload,
    required this.onGenerate,
    required this.onClose,
  });

  String get _label => switch (ctx.type) {
    MatCType.module   => ctx.module?.title ?? 'Module',
    MatCType.material => ctx.material?.displayTitle ?? 'Material',
    MatCType.topic    => ctx.topic?.title ?? 'Topic',
  };

  IconData get _icon => switch (ctx.type) {
    MatCType.module   => Icons.folder_rounded,
    MatCType.material => ctx.material?.type == 'video'
        ? Icons.play_circle_filled_rounded
        : Icons.picture_as_pdf_rounded,
    MatCType.topic    => Icons.tag_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: MatK.div)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          // Label pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: MatK.blueSoft,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon, size: 13, color: AppColors.primary),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    _label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Generate button
          _FooterBtn(
            icon: Icons.auto_awesome_rounded,
            label: canGenerate ? 'Generate Questions' : 'No content yet',
            primary: true,
            disabled: !canGenerate,
            onTap: canGenerate ? onGenerate : null,
          ),
          const SizedBox(width: 8),
          // Close
          InkWell(
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            onTap: onClose,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.all(7),
              child: Icon(Icons.close_rounded, size: 15, color: AppColors.textHint),
            ),
          ),
        ],
      ),
    );
  }
}

// ── internal button ──────────────────────────────────────────────────────────
class _FooterBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final bool disabled;
  final VoidCallback? onTap;

  const _FooterBtn({
    required this.icon,
    required this.label,
    this.primary = false,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = primary
        ? (disabled ? AppColors.primary.withOpacity(0.35) : AppColors.primary)
        : Colors.transparent;
    final fg = primary ? Colors.white : AppColors.textMuted;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
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
