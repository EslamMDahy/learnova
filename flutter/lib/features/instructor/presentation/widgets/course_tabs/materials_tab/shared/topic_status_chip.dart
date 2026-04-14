import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Topic status chip used in the edit topic dialog header
// ─────────────────────────────────────────────────────────────────────────────

class TopicStatusChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    fg;
  final Color    bg;

  const TopicStatusChip({
    super.key,
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
