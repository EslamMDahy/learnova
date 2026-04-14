import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Generic card container used by panel sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class MaterialsCardWidget extends StatelessWidget {
  final Widget child;
  const MaterialsCardWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
