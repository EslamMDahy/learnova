import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A reusable empty-state / coming-soon widget.
///
/// Uses only [AppColors] and [AppTextStyles] — zero new colour tokens.
/// Drop-in replacement for the old `_ComingSoonPage` in app_router.dart.
class EmptyStatePage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  /// Optional primary action (e.g. "Go back").
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStatePage({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      color: AppColors.pageBg,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: ConstrainedBox(
          // Keep the content readable on ultra-wide screens
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon container ──────────────────────────────────────────
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),

              // ── Title ───────────────────────────────────────────────────
              Text(
                title,
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // ── Description ─────────────────────────────────────────────
              Text(
                description,
                style: AppTextStyles.sectionSubtitle,
                textAlign: TextAlign.center,
              ),

              // ── Action button (optional) ─────────────────────────────────
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
