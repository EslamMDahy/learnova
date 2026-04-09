import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../presentation/controllers/forgot_password_controller.dart';

import '../../../../shared/widgets/app_ui_components.dart';

class ForgetPasswordForm extends ConsumerStatefulWidget {
  final bool isMobile;
  const ForgetPasswordForm({super.key, this.isMobile = false});

  @override
  ConsumerState<ForgetPasswordForm> createState() => _ForgetPasswordFormState();
}

class _ForgetPasswordFormState extends ConsumerState<ForgetPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(forgotPasswordControllerProvider.notifier).reset();
      _emailCtrl.clear();
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSend() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    
    ref.read(forgotPasswordControllerProvider.notifier).clearError();

    await ref
        .read(forgotPasswordControllerProvider.notifier)
        .sendResetLink(_emailCtrl.text.trim());
  }

  void _goToLogin() {
    ref.read(forgotPasswordControllerProvider.notifier).reset();
    _emailCtrl.clear();
    context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordControllerProvider);

    return AppAuthShell(
      isMobile: widget.isMobile,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppAuthHeaderIcon(
              icon: Icons.refresh,
              title: 'Forgot password?',
              subtitle: "No worries, we'll send you reset instructions.",
            ),
            const SizedBox(height: 24),

            if (state.sent && state.message != null) ...[
              AppInfoCard(
                type: AppInfoType.success,
                title: 'Check your inbox',
                message: state.message!,
              ),
              const SizedBox(height: 18),
            ],

            if (state.error != null) ...[
              AppInfoCard(
                type: AppInfoType.error,
                title: 'Something went wrong',
                message: state.error!,
              ),
              const SizedBox(height: 18),
            ],

            
            if (!state.sent) ...[
              AppLabeledIconField(
                label: 'Email',
                controller: _emailCtrl,
                hint: 'Enter your email address',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => ref
                    .read(forgotPasswordControllerProvider.notifier)
                    .clearError(),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Email is required';
                  if (!value.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              AppPrimaryLoadingButton(
                label: 'Send Reset Link',
                loading: state.loading,
                onPressed: _onSend,
              ),
              const SizedBox(height: 16),
            ] else ...[
              
              AppPrimaryLoadingButton(
                label: 'Resend email',
                loading: state.loading,
                onPressed: () => ref
                    .read(forgotPasswordControllerProvider.notifier)
                    .resend(),
                height: 48,
              ),
              const SizedBox(height: 16),

              
              if ((state.lastEmail ?? '').trim().isEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: AppTextLoadingButton(
                    label: 'Enter a different email',
                    loading: state.loading,
                    onPressed: () {
                      ref
                          .read(forgotPasswordControllerProvider.notifier)
                          .reset();
                      _emailCtrl.clear();
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],

            Center(
              child: AppBackLink(showLabel: true, 
                label: 'Return to Log In',
                onTap: state.loading ? null : _goToLogin,
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
