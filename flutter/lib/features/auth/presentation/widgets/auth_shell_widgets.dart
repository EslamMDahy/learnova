import 'package:flutter/material.dart';

/// Shared top bar used across auth "shell" pages
/// (VerifyEmailPage, VerifyEmailSentPage, and similar standalone screens).
///
/// Shows the Learnova logo + brand name on a white bar.
class AuthTopBar extends StatelessWidget {
  const AuthTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Image.asset(
            'assets/logo.webp',
            height: 32,
            cacheWidth:
                (32 * MediaQuery.of(context).devicePixelRatio).round(),
          ),
          const SizedBox(width: 10),
          const Text(
            'Learnova',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared footer used across auth "shell" pages.
///
/// Shows a centred "Contact Support" link with a subtle separator.
class AuthFooter extends StatelessWidget {
  const AuthFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '© Learnova',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w400,
            ),
          ),
          Container(
            width: 1,
            height: 14,
            color: const Color(0xFFD1D5DB),
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          const Text(
            'Contact Support',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
