import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Unified async states for pages/tables: loading, error, empty, content.
///
/// Use this to keep UX consistent across modules.
class AsyncStateView extends StatelessWidget {
  final bool loading;
  final String? errorMessage;
  final bool isEmpty;

  final Widget child;

  final VoidCallback? onRetry;

  final String emptyTitle;
  final String emptyMessage;

  const AsyncStateView({
    super.key,
    required this.loading,
    required this.isEmpty,
    required this.child,
    this.errorMessage,
    this.onRetry,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage = 'No data available.',
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: _LoadingSkeleton(),
      );
    }

    final err = errorMessage?.trim();
    if (err != null && err.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: _ErrorCard(
          message: err,
          onRetry: onRetry,
        ),
      );
    }

    if (isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: _EmptyCard(
          title: emptyTitle,
          message: emptyMessage,
        ),
      );
    }

    return child;
  }
}

class _EmptyCard extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.headerBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.inbox_outlined, color: AppColors.textGray),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textGray,
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

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorCard({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final hasRetry = onRetry != null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.dangerBorder,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.error_outline, color: AppColors.dangerTitle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textGray,
                  ),
                ),
                if (hasRetry) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    // Shimmer animations can be surprisingly expensive on Flutter Web.
    // Keep skeleton static (web-friendly) and let pages feel snappy.
    final base = AppColors.borderGray;
    final hi = AppColors.headerBg;

    // On mobile/desktop you can still get a subtle pulse without a ticker.
    // On web: lock to a single color to avoid jank.
    final shimmer = kIsWeb ? base : Color.lerp(base, hi, 0.35)!;

    Widget bar({double? w, double h = 12}) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: shimmer,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header skeleton
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: shimmer,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(w: 180, h: 14),
                  const SizedBox(height: 8),
                  bar(w: 260),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Rows skeleton (table-like)
        ...List.generate(6, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: shimmer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(w: 220),
                        const SizedBox(height: 8),
                        bar(w: 160, h: 11),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  bar(w: 88, h: 22),
                  const SizedBox(width: 10),
                  bar(w: 64, h: 22),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
