import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learnova/features/auth/presentation/controllers/verify_email_sent_state.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/storage/user_storage.dart';
import '../controllers/verify_email_sent_controller.dart';
import 'package:learnova/core/theme/app_theme.dart';

/// "Verify Your Email" screen.
///
/// Shown in two scenarios:
///   1. Immediately after successful signup.
///   2. When an unverified user attempts to login (backend returns 403).
///
/// Design: matches the global error page aesthetic — same gray bg, same
/// Learnova header, same footer. Card adapts to show email-verification content.
class VerifyEmailSentPage extends ConsumerStatefulWidget {
  final String? email;
  const VerifyEmailSentPage({super.key, required this.email});

  @override
  ConsumerState<VerifyEmailSentPage> createState() =>
      _VerifyEmailSentPageState();
}

class _VerifyEmailSentPageState extends ConsumerState<VerifyEmailSentPage>
    with SingleTickerProviderStateMixin {
  static const _cooldownSec = 60;

  int _secondsLeft = 0;
  Timer? _cooldownTimer;

  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ac, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.05),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));

  String get _email =>
      widget.email?.trim() ??
      TokenStorage.pendingVerificationEmail ??
      '';
  bool get _hasEmail => _email.isNotEmpty;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _ac.dispose();
    super.dispose();
  }

  // ── Cooldown timer ────────────────────────────────────────────────────────

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _secondsLeft = _cooldownSec);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) t.cancel();
      });
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _onResend() async {
    if (!_hasEmail || _secondsLeft > 0) return;
    final ok = await ref
        .read(verifyEmailSentControllerProvider.notifier)
        .resend(_email);
    if (ok && mounted) _startCooldown();
  }

  Future<void> _onCheckVerified() async {
    final ok = await ref
        .read(verifyEmailSentControllerProvider.notifier)
        .checkVerified(_email);
    if (!mounted) return;
    if (ok) {
      TokenStorage.clearPendingVerificationEmail();
      // Redirect to dashboard (role-aware) if user has a session,
      // otherwise go to login with ?verified=1 banner.
      if (TokenStorage.hasToken || TokenStorage.isPersisted) {
        if (UserStorage.isOwner) {
          context.go(Routes.adminUsers);
        } else if (UserStorage.isInstructor) {
          context.go(Routes.instructorDashboard);
        } else {
          context.go(Routes.home);
        }
      } else {
        context.go('${Routes.login}?verified=1');
      }
    }
  }

  Future<void> _onLogout() async {
    TokenStorage.clear();
    TokenStorage.clearPendingVerificationEmail();
    UserStorage.clear();
    if (mounted) context.go(Routes.login);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final state = ref.watch(verifyEmailSentControllerProvider);
    final canResend = _hasEmail && _secondsLeft <= 0 && !state.loading;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Stack(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopBar(),
          ),

          // ── Footer ────────────────────────────────────────────────────
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _Footer(),
          ),

          // ── Content ───────────────────────────────────────────────────
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 80, 24, 60),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ghost envelope text in background
                      const Opacity(
                        opacity: 0.04,
                        child: Icon(
                          Icons.mark_email_unread_outlined,
                          size: 260,
                          color: Color(0xFF000000),
                        ),
                      ),

                      // Foreground card
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: _Card(
                          email: _email,
                          hasEmail: _hasEmail,
                          state: state,
                          canResend: canResend,
                          secondsLeft: _secondsLeft,
                          onResend: _onResend,
                          onCheckVerified: _onCheckVerified,
                          onLogout: _onLogout,
                        ),
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

// ─── Card ─────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String email;
  final bool hasEmail;
  final VerifyEmailSentState state;
  final bool canResend;
  final int secondsLeft;
  final VoidCallback onResend;
  final VoidCallback onCheckVerified;
  final VoidCallback onLogout;

  const _Card({
    required this.email,
    required this.hasEmail,
    required this.state,
    required this.canResend,
    required this.secondsLeft,
    required this.onResend,
    required this.onCheckVerified,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Headline (above card, matching error page layout)
        Text(
          'Check your inbox',
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
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            hasEmail
                ? 'We\'ve sent a verification link to $email. Click the link to activate your account.'
                : 'We\'ve sent a verification link to your email address. Please check your inbox.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textGray500,
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Spam tip
        const _TipRow(
          icon: Icons.folder_special_outlined,
          text:
              'Can\'t find it? Check your spam or junk folder.',
        ),
        const SizedBox(height: 16),

        // Feedback banners
        if (state.error != null) ...[
          _Banner.error(message: state.error!),
          const SizedBox(height: 12),
        ],
        if (state.successMessage != null) ...[
          _Banner.success(message: state.successMessage!),
          const SizedBox(height: 12),
        ],

        // Primary: I've Verified
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),),
            ),
            onPressed: state.checkingVerification ? null : onCheckVerified,
            child: state.checkingVerification
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white,),
                  )
                : const Text(
                    'I\'ve Verified, Continue',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
          ),
        ),

        const SizedBox(height: 12),

        // Resend + Logout row
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: canResend
                        ? AppColors.textGray
                        : AppColors.textHint,
                    side: BorderSide(
                      color: canResend
                          ? AppColors.borderSoft
                          : AppColors.borderGray,
                    ),
                    backgroundColor: AppColors.cardBg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),),
                  ),
                  onPressed: (canResend && !state.loading) ? onResend : null,
                  icon: state.loading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textGray500,),
                        )
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    secondsLeft > 0
                        ? 'Resend in ${secondsLeft}s'
                        : 'Resend Email',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14,),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.dangerText,
                  side: BorderSide(color: AppColors.dangerBorder),
                  backgroundColor: AppColors.cardBg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: state.loading ? null : onLogout,
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text(
                  'Log out',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Tip row ──────────────────────────────────────────────────────────────────

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textGray500),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textGray,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Banners ──────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  final Color bgColor;
  final Color borderColor;
  final Color iconColor;
  final IconData icon;
  final String message;

  const _Banner._({
    required this.bgColor,
    required this.borderColor,
    required this.iconColor,
    required this.icon,
    required this.message,
  });

  factory _Banner.error({required String message}) => _Banner._(
        bgColor: AppColors.dangerBg,
        borderColor: AppColors.dangerBorder,
        iconColor: AppColors.dangerText,
        icon: Icons.error_outline_rounded,
        message: message,
      );

  factory _Banner.success({required String message}) => _Banner._(
        bgColor: AppColors.successBg,
        borderColor: AppColors.successDot,
        iconColor: AppColors.successText,
        icon: Icons.check_circle_outline_rounded,
        message: message,
      );

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: iconColor,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
