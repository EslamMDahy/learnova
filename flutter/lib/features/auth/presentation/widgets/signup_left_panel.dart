import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:learnova/core/theme/app_theme.dart';

class SignupLeftPanel extends StatelessWidget {
  const SignupLeftPanel({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final bgCacheWidth = (w * dpr).clamp(800.0, 2000.0).round();

        final hPad = w < 1100 ? 32.0 : 64.0;
        final vPad = w < 1100 ? 32.0 : 48.0;

        final maxTextWidth = math.min(520.0, math.max(360.0, w - (hPad * 2)));

        return Container(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: ResizeImage(const AssetImage('assets/signup.webp'), width: bgCacheWidth),
              fit: BoxFit.cover,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.55),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Image.asset('assets/logo.webp', height: 40, cacheWidth: (40 * dpr).round()),
                  const SizedBox(width: 12),
                  const Text(
                    'Learnova',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'AI-Powered Learning for the\n',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: w < 1100 ? 32 : 38,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    TextSpan(
                      text: 'Modern Campus',
                      style: TextStyle(
                        color: AppColors.badgeBlueBorder,
                        fontSize: w < 1100 ? 32 : 38,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxTextWidth),
                child: const Text(
                  'Experience personalized assessments, adaptive question banks, and intelligent insights designed for students, instructors, and administrators.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _FeatureTag(title: 'Adaptive Learning', icon: Icons.timeline),
                  _FeatureTag(
                    title: 'Real-time Analytics',
                    icon: Icons.analytics_outlined,
                  ),
                  _FeatureTag(
                    title: 'Enterprise Grade',
                    icon: Icons.shield_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 50),
            ],
          ),
        );
      },
    );
  }
}

class _FeatureTag extends StatelessWidget {
  final String title;
  final IconData icon;

  const _FeatureTag({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.cardBg.withValues(alpha: 0.20), width: 1.2),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
