import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/routes.dart';
import '../../core/storage/token_storage.dart';
import '../../core/storage/user_storage.dart';
import 'package:learnova/core/theme/app_theme.dart';

/// Global fallback error screen — design-accurate implementation.
///
/// Shown for:
/// - 5xx server errors
/// - Network / timeout failures
/// - Unhandled runtime exceptions
///
/// Design: light gray page background (#F0F2F5), Learnova logo top-left,
/// large ghost status-code text centered behind the card, two CTA buttons,
/// "Contact Support" link at the very bottom.
///
/// Does NOT appear for 401 auth errors — those use the session-expired dialog.
class ErrorPage extends StatefulWidget {
  final String errorType; // 'server' | 'network' | 'timeout'
  final String? message;
  final String? errorId;

  const ErrorPage({
    super.key,
    this.errorType = 'server',
    this.message,
    this.errorId,
  });

  @override
  State<ErrorPage> createState() => _ErrorPageState();
}

class _ErrorPageState extends State<ErrorPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..forward();

  late final Animation<double> _fade =
      CurvedAnimation(parent: _ac, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  _ErrorVariant get _variant {
    switch (widget.errorType) {
      case 'network':
        return _ErrorVariant.network;
      case 'timeout':
        return _ErrorVariant.timeout;
      default:
        return _ErrorVariant.server;
    }
  }

  void _goToDashboard() {
    try {
      if (UserStorage.isOwner) {
        context.go(Routes.adminUsers);
      } else if (UserStorage.isInstructor) {
        context.go(Routes.instructorDashboard);
      } else if (TokenStorage.hasToken || TokenStorage.isPersisted) {
        context.go(Routes.home);
      } else {
        context.go(Routes.login);
      }
    } catch (_) {
      context.go(Routes.login);
    }
  }

  void _refresh() {
    if (context.canPop()) {
      context.pop();
    } else {
      _goToDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final v = _variant;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Stack(
        children: [
          // ── Top nav bar ───────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopBar(),
          ),

          // ── Bottom footer ─────────────────────────────────────────────
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _Footer(),
          ),

          // ── Main content ──────────────────────────────────────────────
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: _Body(
                  variant: v,
                  message: widget.message,
                  errorId: widget.errorId,
                  onDashboard: _goToDashboard,
                  onRefresh: _refresh,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      height: 56,
      color: AppColors.cardBg,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Image.asset('assets/logo.webp', height: 32, cacheWidth: (32 * MediaQuery.of(context).devicePixelRatio).round()),
          const SizedBox(width: 10),
          Text(
            'Learnova',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textTitle,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Footer ───────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      height: 44,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 1,
            height: 14,
            color: AppColors.borderSoft,
            margin: const EdgeInsets.only(right: 12),
          ),
          Text(
            'Contact Support',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textGray500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Main body ────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final _ErrorVariant variant;
  final String? message;
  final String? errorId;
  final VoidCallback onDashboard;
  final VoidCallback onRefresh;

  const _Body({
    required this.variant,
    required this.message,
    required this.errorId,
    required this.onDashboard,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ghost status code background text
          Text(
            variant.ghostText,
            style: TextStyle(
              fontSize: 220,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF000000).withValues(alpha: 0.04),
              height: 1,
              letterSpacing: -8,
            ),
          ),

          // Foreground content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Text(
                variant.headline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textTitle,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Text(
                  message?.isNotEmpty ?? false ? message! : variant.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textGray500,
                    height: 1.55,
                  ),
                ),
              ),

              // Error ID (optional)
              if (errorId != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Error ID: $errorId',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                    fontFamily: 'monospace',
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // Buttons
              _Buttons(
                onDashboard: onDashboard,
                onRefresh: onRefresh,
                refreshLabel:
                    variant == _ErrorVariant.network ? 'Try Again' : 'Refresh Page',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Buttons ─────────────────────────────────────────────────────────────────

class _Buttons extends StatelessWidget {
  final VoidCallback onDashboard;
  final VoidCallback onRefresh;
  final String refreshLabel;

  const _Buttons({
    required this.onDashboard,
    required this.onRefresh,
    required this.refreshLabel,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        // Primary — Return to Dashboard
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: onDashboard,
            child: const Text(
              'Return to Dashboard',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),

        // Secondary — Refresh Page
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textGray,
              side: BorderSide(color: AppColors.borderSoft),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: AppColors.cardBg,
            ),
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              refreshLabel,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Variant config ───────────────────────────────────────────────────────────

enum _ErrorVariant { server, network, timeout }

extension _ErrorVariantX on _ErrorVariant {
  String get ghostText {
    switch (this) {
      case _ErrorVariant.server:
        return '500';
      case _ErrorVariant.network:
        return '---';
      case _ErrorVariant.timeout:
        return '408';
    }
  }

  String get headline {
    switch (this) {
      case _ErrorVariant.server:
        return 'Something went wrong';
      case _ErrorVariant.network:
        return 'No internet connection';
      case _ErrorVariant.timeout:
        return 'Request timed out';
    }
  }

  String get subtitle {
    switch (this) {
      case _ErrorVariant.server:
        return 'We apologize for the inconvenience. The Smart Study Companion is '
            'currently unable to complete your request. Our team has been notified automatically.';
      case _ErrorVariant.network:
        return 'Check your Wi-Fi or mobile data connection and try again.';
      case _ErrorVariant.timeout:
        return 'The server is taking too long to respond. Please wait a moment and retry.';
    }
  }
}
