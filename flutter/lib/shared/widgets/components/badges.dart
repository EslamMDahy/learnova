import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../design_tokens.dart';

/// Badges / chips / status pills.

class AppFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.title : Colors.white;
    final border = selected ? AppColors.title : AppColors.border;
    final textColor = selected ? Colors.white : const Color(0xFF334155);
    final weight = selected ? FontWeight.w700 : FontWeight.w500;

    return InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: weight,
            color: textColor,
            height: 20 / 14,
          ),
        ),
      ),
    );
  }
}

class FigmaUmRolePill extends StatelessWidget {
  final String role;
  const FigmaUmRolePill({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final r = role.toLowerCase();

    Color bg = AppColors.badgeBlueBg;
    Color br = AppColors.badgeBlueBorder;
    Color fg = AppColors.badgeBlueFg;

    if (r == 'teacher' || r == 'instructor') {
      bg = AppColors.badgePurpleBg;
      br = AppColors.badgePurpleBorder;
      fg = AppColors.badgePurpleFg;
    }

    if (r == 'owner') {
      bg = AppColors.badgeIndigoBg;
      br = AppColors.badgeIndigoBorder;
      fg = AppColors.badgeIndigoFg;
    }

    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: br),
        borderRadius: BorderRadius.circular(9999),
      ),
      alignment: Alignment.center,
      child: Text(
        _titleCase(r),
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 16 / 12,
          color: fg,
        ),
      ),
    );
  }

  String _titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

@Deprecated('Use JrStatusBadge (normalizes more cases)')

class JrRolePill extends StatelessWidget {
  final String role;
  const JrRolePill({super.key, required this.role});

  @override
  Widget build(BuildContext context) => FigmaUmRolePill(role: role);
}

class FigmaUmStatus extends StatelessWidget {
  final String status;
  const FigmaUmStatus({super.key, required this.status});

  @override
  Widget build(BuildContext context) => JrStatusBadge(status: status);
}

class JrStatusBadge extends StatelessWidget {
  final String status;
  const JrStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = jrNormalizeStatus(status);

    Color dot = AppColors.warningDot;
    String label = normalized;

    if (normalized == 'accepted') {
      dot = AppColors.successDot;
      label = 'accepted';
    } else if (normalized == 'pending') {
      dot = AppColors.warningDot;
      label = 'pending';
    } else if (normalized == 'suspended') {
      dot = AppColors.errorDot;
      label = 'suspended';
    } else if (normalized == 'declined') {
      dot = AppColors.errorDot;
      label = 'declined';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: dot,
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textGray,
            height: 20 / 14,
          ),
        ),
      ],
    );
  }
}

String jrNormalizeStatus(String raw) {
  final s = raw.toLowerCase().trim();
  if (s == 'pinding') return 'pending';
  if (s == 'declinate') return 'declined';
  return s;
}

/* ---------------- Toggle ---------------- */

class UpgradePeriodToggle extends StatelessWidget {
  final bool isYearly;
  final VoidCallback onToggle;

  const UpgradePeriodToggle({
    super.key,
    required this.isYearly,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          const BoxShadow(
            color: Color(0x080F172A),
            blurRadius: (kIsWeb ? 12 : 18),
            offset: (kIsWeb ? Offset(0, 4) : Offset(0, 8)),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UpgradeToggleChip(
            text: 'Monthly',
            selected: !isYearly,
            onTap: isYearly ? onToggle : null,
          ),
          const SizedBox(width: 8),
          UpgradeToggleChip(
            text: 'Yearly',
            selected: isYearly,
            onTap: !isYearly ? onToggle : null,
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Save more',
              style: TextStyle(
                color: Color(0xFF166534),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UpgradeToggleChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback? onTap;

  const UpgradeToggleChip({
    super.key,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: kIsWeb ? Duration.zero : const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                selected ? const Color(0xFF2563EB) : AppColors.border,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}

/* ---------------- Card ---------------- */

enum UpgradeTone { primary, neutral }
