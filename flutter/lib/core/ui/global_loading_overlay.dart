import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/design_tokens.dart';
import 'global_loading_controller.dart';

class GlobalLoadingOverlay extends ConsumerWidget {
  const GlobalLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(globalLoadingProvider);
    if (!visible) return const SizedBox.shrink();

    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: AppColors.pageBg, 
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Image.asset(
                  'assets/logo.webp',
                  height: 90,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 24),

                // Brand name (clean & modern)
                Text(
                  'Learnova',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Loading...',
                  style: AppText.mutedSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
