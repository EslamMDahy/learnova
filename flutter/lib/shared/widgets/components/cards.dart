import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../design_tokens.dart';
import 'badges.dart' show UpgradeTone;

/// Cards (shells + stat/plan cards).

class AppCardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final Color? background;
  final Color? borderColor;

  /// Optional: pass a custom shadow from outside
  final List<BoxShadow>? boxShadow;

  final double? maxWidth;

  const AppCardShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.background,
    this.borderColor,
    this.boxShadow,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final defaultShadow = <BoxShadow>[
      BoxShadow(
        blurRadius: 2,
        offset: kIsWeb ? const Offset(0, 4) : const Offset(0, 1),
        color: AppColors.shadowSoft,
      ),
    ];

    Widget c = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? AppColors.cardBg,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? AppColors.borderSoft),
        boxShadow: boxShadow ?? defaultShadow,
      ),
      child: child,
    );

    if (maxWidth != null) {
      c = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: c,
      );
    }

    return c;
  }
}


/// ------------------------------------------------------------
/// Reusable atoms / molecules
/// ------------------------------------------------------------

class AppCard extends StatelessWidget {
  final Widget child;
  const AppCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            blurRadius: 2,
            offset: (kIsWeb ? const Offset(0, 4) : const Offset(0, 1)),
            color: AppColors.shadowSoft,
          ),
        ],
      ),
      child: child,
    );
  }
}

class AppNotificationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String rightTag;
  final IconData icon;

  const AppNotificationCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.rightTag,
    this.icon = Icons.calendar_today_outlined,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.headerBg,
              borderRadius: BorderRadius.circular(9999),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: AppColors.textGray,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textGray,
                          height: 28 / 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      rightTag,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textHint,
                        height: 16 / 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted,
                    height: 23 / 14,
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

// ===================== Top Header components =====================

class FigmaUmCardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final BorderRadius borderRadius;

  const FigmaUmCardShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return AppCardShell(
      padding: padding,
      borderRadius: borderRadius,
      borderColor: AppColors.cBorder,
      boxShadow: [
        const BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 2,
          offset: (kIsWeb ? Offset(0, 4) : Offset(0, 1)),
        ),
      ],
      child: child,
    );
  }
}

class JrCardShell extends StatelessWidget {
  final Widget child;
  final double width;

  const JrCardShell({super.key, required this.child, required this.width});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return AppCardShell(
      maxWidth: width,
      borderColor: AppColors.borderGray,
      boxShadow: [
        const BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 2,
          offset: (kIsWeb ? Offset(0, 4) : Offset(0, 1)),
        ),
      ],
      child: child,
    );
  }
}

class FigmaUmStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color subtitleColor;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final double? fixedWidth;

  const FigmaUmStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.subtitleColor,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.fixedWidth,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final card = Container(
      height: 134,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cBorder),
        boxShadow: [
          const BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: (kIsWeb ? Offset(0, 4) : Offset(0, 1)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 20 / 14,
                  color: AppColors.cMuted,
                ),
              ),
              const Spacer(),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 32 / 24,
              color: AppColors.cText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 16 / 12,
              color: subtitleColor,
            ),
          ),
        ],
      ),
    );

    if (fixedWidth == null) return card;
    return SizedBox(width: fixedWidth, child: card);
  }
}

class UpgradePlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String? subPriceText;
  final String description;
  final List<String> features;
  final String buttonText;
  final bool isPopular;
  final bool isCurrent;
  final UpgradeTone tone;
  final VoidCallback? onPressed;

  const UpgradePlanCard({
    super.key,
    required this.title,
    required this.price,
    required this.period,
    required this.description,
    required this.features,
    required this.buttonText,
    required this.isPopular,
    required this.isCurrent,
    required this.tone,
    required this.onPressed,
    this.subPriceText,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final isPrimary = tone == UpgradeTone.primary;
    final isCustom = price == 'Custom';
    final isFree = price.toLowerCase() == 'free';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isPrimary ? AppColors.primary : AppColors.border,
          width: isPrimary ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? AppColors.primary.withValues(alpha: 0.10)
                : AppColors.textTitle.withValues(alpha: 0.04),
            blurRadius: (kIsWeb ? 12 : 30),
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPopular) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.badgeBlueBg, const Color(0xFFEDE9FE)],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'MOST POPULAR',
                style: TextStyle(
                  color: AppColors.badgeBlueFg,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textTitle,
            ),
          ),
          const SizedBox(height: 10),

          if (isFree) ...[
            Text(
              'Free',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: AppColors.textTitle,
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isCustom)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, right: 2),
                    child: Text(
                      '\$',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textTitle,
                      ),
                    ),
                  ),
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textTitle,
                  ),
                ),
                if (period.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, left: 6),
                    child: Text(
                      period,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],

          if (subPriceText != null) ...[
            const SizedBox(height: 6),
            Text(
              subPriceText!,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],

          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textMuted,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 18),
          Divider(color: AppColors.headerBg, thickness: 1.4),
          const SizedBox(height: 16),

          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isPrimary
                          ? AppColors.badgeBlueBg
                          : AppColors.headerBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.check,
                      size: 16,
                      color: isPrimary
                          ? AppColors.primary
                          : AppColors.textTitle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textTitle,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isCurrent ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isPrimary ? AppColors.primary : AppColors.cardBg,
                disabledBackgroundColor: const Color(0xFF93C5FD),
                foregroundColor:
                    isPrimary ? Colors.white : AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color: isPrimary
                      ? Colors.transparent
                      : AppColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
