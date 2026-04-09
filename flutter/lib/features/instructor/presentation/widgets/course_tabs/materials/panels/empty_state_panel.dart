import 'package:flutter/material.dart';

import '../../../../../../../core/ui/app_colors.dart';
import '../materials_context.dart';

class MatEmptyStatePanel extends StatelessWidget {
  final VoidCallback onCreate;
  const MatEmptyStatePanel({super.key, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MatK.bg,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: MatK.div),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: MatK.blueSoft,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Select a module or material',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textTitle,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use the structure panel to explore your modules, reorder them by dragging, '
                'or open a material to manage topics and content.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: MatK.blueSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.drag_indicator_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Tip: drag modules in the left panel to reorder them',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text('New Module'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
