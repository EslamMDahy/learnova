import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learnova/core/storage/user_storage.dart';
import '../../../../core/routing/routes.dart';
import '../controllers/login_controller.dart';
import '../../../../shared/widgets/app_ui_components.dart';

class LoginForm extends ConsumerStatefulWidget {
  final bool isMobile;
  const LoginForm({super.key, this.isMobile = false});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool rememberMe = false;
  bool _obscurePassword = true;

  bool _showResetSuccess = false;
  bool _showVerifiedSuccess = false;
  Timer? _successTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final uri = GoRouterState.of(context).uri;
      final resetDone    = uri.queryParameters['reset'] == '1';
      final verifiedDone = uri.queryParameters['verified'] == '1';

      if (verifiedDone) setState(() => _showVerifiedSuccess = true);
      if (resetDone)    setState(() => _showResetSuccess = true);

      if (verifiedDone || resetDone) {
        final clean = uri.replace(queryParameters: {});
        context.replace(clean.toString());

        _successTimer?.cancel();
        _successTimer = Timer(const Duration(seconds: 3), () {
          if (!mounted) return;
          setState(() {
            _showResetSuccess    = false;
            _showVerifiedSuccess = false;
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _clearError() =>
      ref.read(loginControllerProvider.notifier).clearError();

  Future<void> _onLogin() async {
    final okForm = _formKey.currentState?.validate() ?? false;
    if (!okForm) return;

    _clearError();

    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    final result = await ref
        .read(loginControllerProvider.notifier)
        .login(email, password, persist: rememberMe);

    if (!mounted) return;

    switch (result) {
      case LoginResult.success:
        if (UserStorage.isOwner) {
          context.go(Routes.adminUsers);
        } else if (UserStorage.isInstructor) {
          context.go(Routes.instructorDashboard);
        } else {
          context.go(Routes.studentDashboard);
        }
        break;

      case LoginResult.emailNotVerified:
        context.go(Routes.verifyEmailSentFor(email));
        break;

      case LoginResult.authError:
      case LoginResult.error:
        // Error is shown inline via state.errorMessage.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final state = ref.watch(loginControllerProvider);

    // Derived from AsyncValue — no manual bool flags needed.
    final isLoading = state.isLoading;
    final err       = state.errorMessage;

    return AppAuthShell(
      isMobile: widget.isMobile,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppFormHeader(
              title: 'Login',
              subtitle: 'Please sign in to access your dashboard.',
            ),
            const SizedBox(height: 24),

            if (_showVerifiedSuccess && err == null) ...[
              AppSuccessBanner(
                title: 'Email verified!',
                message:
                    'Your email has been verified successfully. You can log in now.',
                onClose: () => setState(() => _showVerifiedSuccess = false),
              ),
              const SizedBox(height: 18),
            ],

            if (_showResetSuccess && err == null) ...[
              AppSuccessBanner(
                title: 'All set!',
                message:
                    'Your password has been updated. Log in with the new one.',
                onClose: () => setState(() => _showResetSuccess = false),
              ),
              const SizedBox(height: 18),
            ],

            if (err != null) ...[
              AppErrorBox(message: err),
              const SizedBox(height: 18),
            ],

            AppLabeledIconField(
              label: 'Email',
              controller: _emailCtrl,
              hint: 'Enter your email address',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => _clearError(),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'Email is required';
                if (!value.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),

            const SizedBox(height: 20),

            AppLabeledIconField(
              label: 'Password',
              controller: _passwordCtrl,
              hint: 'Enter your password',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              onChanged: (_) => _clearError(),
              validator: (v) {
                if ((v ?? '').isEmpty) return 'Password is required';
                return null;
              },
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.muted,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),

            const SizedBox(height: 16),

            AppRememberForgotRow(
              value: rememberMe,
              disabled: isLoading,
              onChanged: (v) => setState(() => rememberMe = v ?? false),
              onForgot: () => context.go(Routes.forgotPassword),
            ),

            const SizedBox(height: 20),

            AppPrimaryLoadingButton(
              label: 'Log In',
              loading: isLoading,
              onPressed: _onLogin,
            ),

            const SizedBox(height: 28),
            const AppAuthOrDivider(),
            const SizedBox(height: 24),

            AppSocialButton(
              label: 'Google',
              imagePath: 'assets/google.png',
              disabled: isLoading,
              onTap: () {},
            ),
            const SizedBox(height: 12),
            AppSocialButton(
              label: 'Microsoft',
              imagePath: 'assets/microsoft.png',
              disabled: isLoading,
              onTap: () {},
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Don't have an account? ",
                  style: TextStyle(color: Colors.black),
                ),
                InkWell(
                  hoverColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                  onTap: isLoading ? null : () => context.go(Routes.signup),
                  child: const Text(
                    'Sign up',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
