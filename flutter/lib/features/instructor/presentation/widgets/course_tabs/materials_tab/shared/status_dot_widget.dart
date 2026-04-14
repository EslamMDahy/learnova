import 'package:flutter/material.dart';

import '../../../../../../core/ui/app_colors.dart';
import '../../../../data/materials_models.dart';
import '../materials_tab_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Status dot indicator for material processing state
// ─────────────────────────────────────────────────────────────────────────────

class StatusDotWidget extends StatelessWidget {
  final String? status;
  const StatusDotWidget({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == null || status == MaterialStatus.ready) return const SizedBox.shrink();
    final (Color color, String label) = switch (status) {
      MaterialStatus.processing => (_K.amber, 'Processing'),
      MaterialStatus.error      => (const Color(0xFFEF4444), 'Error'),
      _                         => (_K.div, status!),
    };
    return Tooltip(
      message: label,
      child: Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
