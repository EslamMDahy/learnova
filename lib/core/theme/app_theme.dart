import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AppColors — single source of truth for every color token.
//  All old token names are kept as aliases so existing code compiles unchanged.
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF137FEC);
  static const Color primarySoft = Color(0x0D137FEC); // ~5 % opacity

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color pageBg = Color(0xFFF6F7F8);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color headerBg = Color(0xFFF1F5F9);
  static const Color cardBg = Colors.white;
  static const Color surfaceBg = Color(0xFFF9FAFB);

  // ── Borders ───────────────────────────────────────────────────────────────
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderSoft = Color(0xFFDBE0E6);
  static const Color borderGray = Color(0xFFE5E7EB);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textTitle = Color(0xFF111418);
  static const Color textMuted = Color(0xFF617589);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textGray = Color(0xFF374151);
  static const Color textGray500 = Color(0xFF6B7280);

  static const Color text = Color(0xFF1F2937); // Dark gray for main text
  static const Color divider = Color(0xFFF3F4F6); // Very light divider

  // ── Text — legacy aliases (keep so existing code compiles) ────────────────
  static const Color title = textTitle;
  static const Color muted = textMuted;
  static const Color hint = textHint;
  static const Color card = cardBg;
  static const Color cText = textTitle;
  static const Color cMuted = textMuted;
  static const Color cBg = Colors.white;
  static const Color cSurface = surfaceBg;
  static const Color cBorder = border;
  static const Color cBorderSoft = Color(0xFFF3F4F6);
  static const Color cGray700 = textGray;
  static const Color cGray500 = textGray500;

  // ── Status — Success ──────────────────────────────────────────────────────
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color successDot = Color(0xFF22C55E);
  static const Color successText = Color(0xFF166534);

  // ── Status — Danger ───────────────────────────────────────────────────────
  static const Color dangerBg = Color(0xFFFEF2F2);
  static const Color dangerBorder = Color(0xFFFECACA);
  static const Color dangerText = Color(0xFFDC2626);
  static const Color dangerTitle = Color(0xFFB91C1C);

  // ── Status — Warning / Error ──────────────────────────────────────────────
  static const Color warningDot = Color(0xFFEAB308);
  static const Color errorDot = Color(0xFFEF4444);

  // ── Badge palettes ────────────────────────────────────────────────────────
  static const Color badgeBlueBg = Color(0xFFDBEAFE);
  static const Color badgeBlueBorder = Color(0xFFBFDBFE);
  static const Color badgeBlueFg = Color(0xFF1E40AF);

  static const Color badgePurpleBg = Color(0xFFF3E8FF);
  static const Color badgePurpleBorder = Color(0xFFE9D5FF);
  static const Color badgePurpleFg = Color(0xFF6B21A8);

  static const Color badgeIndigoBg = Color(0xFFE0E7FF);
  static const Color badgeIndigoBorder = Color(0xFFC7D2FE);
  static const Color badgeIndigoFg = Color(0xFF4338CA);

  // ── Shadows ───────────────────────────────────────────────────────────────
  static const Color shadowSoft = Color(0x14000000);
  static const Color shadowThin = Color(0x0D000000);
  static const Color shadowBlue = Color(0xFFBFDBFE);
}

// ─────────────────────────────────────────────────────────────────────────────
//  AppTextStyles — typography scale.
// ─────────────────────────────────────────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  static const String _font = 'Inter';

  static const TextStyle h1 = TextStyle(
    fontFamily: _font,
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 40 / 36,
    letterSpacing: -0.9,
    color: AppColors.textTitle,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: _font,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textTitle,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: _font,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
    color: AppColors.textMuted,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w700,
    fontSize: 18,
    height: 28 / 18,
    color: AppColors.textTitle,
  );

  static const TextStyle sectionSubtitle = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 20 / 14,
    color: AppColors.textMuted,
  );

  static const TextStyle button = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w700,
    fontSize: 14,
    height: 21 / 14,
  );

  static const TextStyle label = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w700,
    fontSize: 14,
    height: 20 / 14,
    color: AppColors.textTitle,
  );

  static const TextStyle input = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 19 / 14,
    color: AppColors.textTitle,
  );

  static const TextStyle hint = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 19 / 14,
    color: AppColors.textHint,
  );

  static const TextStyle muted = TextStyle(
    fontFamily: _font,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  static const TextStyle mutedSmall = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 16 / 12,
    color: AppColors.textMuted,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  AppText — static alias for AppTextStyles.
//  Use: AppText.h1, AppText.button, etc.  (drop-in for old code)
// ─────────────────────────────────────────────────────────────────────────────
class AppText {
  AppText._();

  static const TextStyle h1 = AppTextStyles.h1;
  static const TextStyle h3 = AppTextStyles.h3;
  static const TextStyle subtitle = AppTextStyles.subtitle;
  static const TextStyle sectionTitle = AppTextStyles.sectionTitle;
  static const TextStyle sectionSubtitle = AppTextStyles.sectionSubtitle;
  static const TextStyle button = AppTextStyles.button;
  static const TextStyle label = AppTextStyles.label;
  static const TextStyle input = AppTextStyles.input;
  static const TextStyle hint = AppTextStyles.hint;
  static const TextStyle muted = AppTextStyles.muted;
  static const TextStyle mutedSmall = AppTextStyles.mutedSmall;
}

// ─────────────────────────────────────────────────────────────────────────────
//  AppSpacing — sizing and spacing tokens.
// ─────────────────────────────────────────────────────────────────────────────
class AppSpacing {
  AppSpacing._();

  // Named page paddings
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(24, 40, 24, 40);
  static const EdgeInsets notificationsPage = EdgeInsets.fromLTRB(
    32,
    32,
    32,
    24,
  );
  static const EdgeInsets cardPadding = EdgeInsets.all(32);

  /// Legacy alias — use [pagePadding] in new code.
  static const EdgeInsets page = pagePadding;

  // Raw values
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double xl2 = 20;
  static const double xl3 = 24;
  static const double xl4 = 32;

  // Vertical gap widgets
  static const SizedBox gap4 = SizedBox(height: xs);
  static const SizedBox gap6 = SizedBox(height: sm);
  static const SizedBox gap8 = SizedBox(height: md);
  static const SizedBox gap12 = SizedBox(height: lg);
  static const SizedBox gap16 = SizedBox(height: xl);
  static const SizedBox gap20 = SizedBox(height: xl2);
  static const SizedBox gap24 = SizedBox(height: xl3);
  static const SizedBox gap32 = SizedBox(height: xl4);
}

// ─────────────────────────────────────────────────────────────────────────────
//  AppTheme — MaterialApp ThemeData factory.
//  Usage: MaterialApp.router(theme: AppTheme.light, darkTheme: AppTheme.dark)
// ─────────────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);

  /// Dark-mode scaffold — extend color tokens when fully implementing.
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final ColorScheme colorScheme = isDark
        ? const ColorScheme.dark(
            primary: AppColors.primary,
            surface: Color(0xFF1E1E2E),
            onPrimary: Colors.white,
          )
        : const ColorScheme.light(
            primary: AppColors.primary,
            onSurface: AppColors.textTitle,
            outline: AppColors.border,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF121212)
          : AppColors.pageBg,

      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.textTitle,
        elevation: 0,
        titleTextStyle: AppTextStyles.h3.copyWith(
          color: isDark ? Colors.white : AppColors.textTitle,
          fontSize: 18,
        ),
      ),

      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isDark ? Colors.white12 : AppColors.border),
        ),
      ),

      // ── Web feel: no mobile ripple, subtle overlay on hover ──────────────
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent, // remove global material hover overlay

      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              textStyle: AppTextStyles.button,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: const Size(0, 40),
              elevation: 0,
              splashFactory: NoSplash.splashFactory,
            ).copyWith(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return const Color(0x18000000);
                }
                if (states.contains(WidgetState.pressed)) {
                  return const Color(0x28000000);
                }
                return Colors.transparent;
              }),
            ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: AppColors.textTitle,
              textStyle: AppTextStyles.button,
              side: const BorderSide(color: AppColors.borderSoft),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: const Size(0, 40),
              splashFactory: NoSplash.splashFactory,
            ).copyWith(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return const Color(0x08000000);
                }
                return Colors.transparent;
              }),
            ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(splashFactory: NoSplash.splashFactory)
            .copyWith(
              mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return AppColors.primary.withOpacity(0.06);
                }
                return Colors.transparent;
              }),
            ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A3A) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        hintStyle: AppTextStyles.hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borderSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.dangerText),
        ),
      ),

      textTheme: const TextTheme(
        displayLarge: AppTextStyles.h1,
        headlineMedium: AppTextStyles.h3,
        bodyLarge: AppTextStyles.input,
        bodyMedium: AppTextStyles.muted,
        bodySmall: AppTextStyles.mutedSmall,
        labelLarge: AppTextStyles.button,
        labelMedium: AppTextStyles.label,
        titleMedium: AppTextStyles.sectionTitle,
        titleSmall: AppTextStyles.sectionSubtitle,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.grey.shade200;
        }),
      ),
    );
  }
}
