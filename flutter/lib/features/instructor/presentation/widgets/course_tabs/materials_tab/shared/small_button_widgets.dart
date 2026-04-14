import 'package:flutter/material.dart';

import '../../../../../../core/ui/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Small reusable button widgets used in panels and footer
// ─────────────────────────────────────────────────────────────────────────────

/// A compact labelled action button used in panel headers and footers.
class MaterialsActionBtn extends StatelessWidget {
  final IconData  icon;
  final String    label;
  final bool      primary;
  final bool      disabled;
  final VoidCallback? onTap;

  const MaterialsActionBtn({
    super.key,
    required this.icon,
    required this.label,
    this.primary  = false,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = disabled
        ? AppColors.textHint
        : (primary ? AppColors.primary : AppColors.textTitle);
    final bg = disabled
        ? const Color(0xFFF1F5F9)
        : (primary
            ? AppColors.primarySoft
            : const Color(0xFFF8FAFC));
    return Opacity(
      opacity: disabled ? 0.55 : 1.0,
      child: InkWell(
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
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

/// Tiny icon-only button used throughout panels.
class MaterialsIBtn extends StatelessWidget {
  final IconData     icon;
  final String       tooltip;
  final VoidCallback onTap;
  const MaterialsIBtn(
      {super.key,
      required this.icon,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(icon, size: 15, color: AppColors.textHint),
          ),
        ),
      );
}
