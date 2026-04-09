import 'package:flutter/material.dart';

class SetNewPasswordLeftPanel extends StatelessWidget {
  const SetNewPasswordLeftPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final w = MediaQuery.sizeOf(context).width;
    final bgCacheWidth = (w * dpr).clamp(800.0, 2000.0).round();
    return Container(
      width: double.infinity,
      height: double.infinity,

      decoration: BoxDecoration(
        image: DecorationImage(
          image: ResizeImage(const AssetImage('assets/floors.webp'), width: bgCacheWidth),

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
            const Text(
              'Reset your password and\nsecure you account easily.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
                height: 1.2,
                shadows: [
                  Shadow(
                    blurRadius: 10,
                    color: Colors.black54,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// Subtitle
            const Text(
              'Create a strong new password\nto keep your learning journey safe.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.5,
                shadows: [
                  Shadow(
                    blurRadius: 8,
                    color: Colors.black45,
                    offset: Offset(0, 3),
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
