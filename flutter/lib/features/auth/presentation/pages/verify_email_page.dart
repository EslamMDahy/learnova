import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/storage/token_storage.dart';
import '../controllers/verify_email_controller.dart';
import 'package:learnova/core/theme/app_theme.dart';

/// Email verification result page.
///
/// Reached when the user clicks the verification link from their inbox.
/// Backend link format: https://app.learnova.com/#/verify-email?token=...
///
/// Three states:
///   - Loading: verifying the token
///   - Success: email verified → auto-redirect to login after 3s
///   - Failure: invalid / expired token → option to resend
///
/// Design: same gray background + Learnova header + footer as Error page.
class VerifyEmailPage extends ConsumerStatefulWidget {
  final String? token;
  const VerifyEmailPage({super.key, required this.token});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage>
    with SingleTickerProviderStateMixin {
  Timer? _redirectTimer;
  int _redirectSecs = 3;

  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ac, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _ac.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final token = widget.token?.trim() ?? '';

    if (token.isEmpty) {
      ref
          .read(verifyEmailControllerProvider.notifier)
          .setError('Invalid verification link — the token is missing.');
      return;
    }

    await ref.read(verifyEmailControllerProvider.notifier).verify(token);
    if (!mounted) return;

    final state = ref.read(verifyEmailControllerProvider);
    if (state.success) {
      // Clear any stored pending verification email
      TokenStorage.clearPendingVerificationEmail();
      _startRedirectCountdown();
    }
  }

  void _startRedirectCountdown() {
    _redirectTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _redirectSecs--;
        if (_redirectSecs <= 0) {
          t.cancel();
          context.go('${Routes.login}?verified=1');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final state = ref.watch(verifyEmailControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Stack(
        children: [
          // ── Header ──────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopBar(),
          ),

          // ── Footer ──────────────────────────────────────────────────
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _Footer(),
          ),

          // ── Content ─────────────────────────────────────────────────
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ghost icon behind content
                      Opacity(
                        opacity: 0.04,
                        child: Icon(
                          state.loading
                              ? Icons.hourglass_empty_rounded
                              : state.success
                                  ? Icons.verified_user_rounded
                                  : Icons.error_outline_rounded,
                          size: 260,
                          color: AppColors.textTitle,
                        ),
                      ),

                      // Main content
                      _Content(
                        loading: state.loading,
                        success: state.success,
                        error: state.error,
                        redirectSecs: _redirectSecs,
                        onGoLogin: () =>
                            context.go(Routes.login),
                        onGoSignup: () =>
                            context.go(Routes.signup),
                      ),
                    ],
                  ),
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

// ─── Content ──────────────────────────────────────────────────────────────────

class _Content extends StatelessWidget {
  final bool loading;
  final bool success;
  final String? error;
  final int redirectSecs;
  final VoidCallback onGoLogin;
  final VoidCallback onGoSignup;

  const _Content({
    required this.loading,
    required this.success,
    required this.error,
    required this.redirectSecs,
    required this.onGoLogin,
    required this.onGoSignup,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    if (loading) return _LoadingState();
    if (success) return _SuccessState(redirectSecs: redirectSecs, onGoLogin: onGoLogin);
    return _FailureState(
      error: error ?? 'This verification link is invalid or has expired.',
      onGoLogin: onGoLogin,
      onGoSignup: onGoSignup,
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 3,
        ),
        const SizedBox(height: 24),
        Text(
          'Verifying your email...',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textTitle,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Please wait a moment.',
          style: TextStyle(fontSize: 15, color: AppColors.textGray500),
        ),
      ],
    );
  }
}

// ── Success ───────────────────────────────────────────────────────────────────

class _SuccessState extends StatelessWidget {
  final int redirectSecs;
  final VoidCallback onGoLogin;

  const _SuccessState({required this.redirectSecs, required this.onGoLogin});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Success icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.successBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.successDot, width: 1.5),
          ),
          child: Icon(
            Icons.check_circle_outline_rounded,
            size: 38,
            color: AppColors.successText,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Email verified!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textTitle,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your email has been confirmed successfully.\nYou\'ll be redirected to login in ${redirectSecs}s.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textGray500,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 36),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),),
            ),
            onPressed: onGoLogin,
            child: const Text(
              'Go to Login',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Failure ───────────────────────────────────────────────────────────────────

class _FailureState extends StatelessWidget {
  final String error;
  final VoidCallback onGoLogin;
  final VoidCallback onGoSignup;

  const _FailureState({
    required this.error,
    required this.onGoLogin,
    required this.onGoSignup,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Failure icon  
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.dangerBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.dangerBorder, width: 1.5),
          ),
          child: Icon(
            Icons.error_outline_rounded,
            size: 38,
            color: AppColors.dangerText,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Verification failed',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textTitle,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textGray500,
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 36),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),),
                ),
                onPressed: onGoLogin,
                child: const Text(
                  'Return to Login',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textGray,
                  side: BorderSide(color: AppColors.borderSoft),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  backgroundColor: AppColors.cardBg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),),
                ),
                onPressed: onGoSignup,
                child: const Text(
                  'Create New Account',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
