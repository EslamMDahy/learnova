import 'package:flutter/material.dart';
import 'package:learnova/shared/widgets/design_tokens.dart';

class ForgetPasswordLeftPanel extends StatelessWidget {
  const ForgetPasswordLeftPanel({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final w = MediaQuery.sizeOf(context).width;
    final bgCacheWidth = (w * dpr).clamp(800.0, 2000.0).round();
    return Container(
      width: double.infinity,
      height: double.infinity,

      decoration: BoxDecoration(
        image: DecorationImage(
          image: ResizeImage(const AssetImage('assets/book.webp'), width: bgCacheWidth),

          
          fit: BoxFit.cover,

          
          colorFilter: const ColorFilter.mode(
            Color.fromRGBO(0, 0, 0, 0.25), 
            BlendMode.darken,
          ),
        ),
      ),

      child: Container(
        padding: const EdgeInsets.all(48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// Logo
            Row(
              children: [
                Image.asset('assets/logo.webp', height: 40, cacheWidth: (40 * MediaQuery.of(context).devicePixelRatio).round()),
                const SizedBox(width: 10),
                const Text(
                  'Learnova',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            /// Title
            Text(
              'Unlock your academic\npotential with AI-driven\nassessments.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
                height: 1.2,
                shadows: [
                  Shadow(
                    blurRadius: 10,
                    color: AppColors.textMuted,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// Subtitle
            Text(
              'Join thousands of students and instructors enhancing\ntheir learning experience.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.5,
                shadows: [
                  Shadow(
                    blurRadius: 8,
                    color: AppColors.textHint,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
