import 'package:flutter/material.dart';
import 'package:learnova/core/theme/app_theme.dart';

/// Facebook-style splash screen.
///
/// Shown ONLY during app bootstrap (one time per full page load).
/// Never shown for API calls, page transitions, or in-app navigation.
///
/// Structure:
///   - Theme-aware background fills the entire screen
///   - Learnova logo centered (image asset + brand name)
///   - Tiny progress indicator at bottom (matches Facebook's "L" bar)
///   - Smooth fade-out when bootstrap completes
class SplashScreen extends StatefulWidget {
  /// Called when the fade-out animation completes and splash should be removed.
  final VoidCallback onDone;

  const SplashScreen({super.key, required this.onDone});

  @override
  State<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  late final Animation<double> _fade = Tween<double>(begin: 1, end: 0).animate(
    CurvedAnimation(parent: _ac, curve: Curves.easeIn),
  );

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  /// Called by parent when bootstrap is complete. Triggers fade-out.
  void fadeOut() {
    _ac.forward().then((_) {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: AppColors.pageBg,
        child: Stack(
          children: [
            // ── Centered logo ─────────────────────────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo image
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Image.asset(
                      'assets/logo.webp',
                      fit: BoxFit.contain,
                      cacheWidth: (72 * dpr).round(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Brand name
                  Text(
                    'Learnova',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textTitle,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Smart Study Companion',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textGray500,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom progress bar (Facebook-style) ──────────────────────
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _BottomBar(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Animated bottom bar ───────────────────────────────────────────────────────

class _BottomBar extends StatefulWidget {
  const _BottomBar();

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  late final Animation<double> _progress = CurvedAnimation(
    parent: _ac,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Learnova copyright tiny text
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'from Learnova',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textHint,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // Thin progress bar
        AnimatedBuilder(
          animation: _progress,
          builder: (_, __) {
            return SizedBox(
              height: 3,
              child: LinearProgressIndicator(
                backgroundColor: AppColors.borderGray,
                color: AppColors.primary,
                minHeight: 3,
              ),
            );
          },
        ),
      ],
    );
  }
}
