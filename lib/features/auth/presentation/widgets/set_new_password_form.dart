import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../presentation/controllers/reset_password_controller.dart';

import '../../../../shared/widgets/app_ui_components.dart';

class SetNewPasswordForm extends ConsumerStatefulWidget {
  final String? token;
  final bool isMobile;

  const SetNewPasswordForm({
    super.key,
    required this.token,
    this.isMobile = false,
  });

  @override
  ConsumerState<SetNewPasswordForm> createState() => _SetNewPasswordFormState();
}

class _SetNewPasswordFormState extends ConsumerState<SetNewPasswordForm> {
  bool showNewPass = false;
  bool showConfirmPass = false;

  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _localError;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _clearAllErrors() {
    if (_localError != null) setState(() => _localError = null);
    ref.read(resetPasswordControllerProvider.notifier).clearError();
  }

  Future<void> _submit() async {
    setState(() => _localError = null);

    final token = widget.token?.trim();
    if (token == null || token.isEmpty) {
      setState(
        () => _localError = 'Invalid reset link. Please request a new one.',
      );
      return;
    }

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    
    ref.read(resetPasswordControllerProvider.notifier).clearError();

    final newPass = _newPassCtrl.text.trim();

    final success = await ref
        .read(resetPasswordControllerProvider.notifier)
        .resetPassword(
          token: token,
          newPassword: newPass,
        );

    if (!mounted) return;

    if (success) {
      context.go('${Routes.login}?reset=1');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resetPasswordControllerProvider);

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 24 : 56),
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppAuthHeaderIcon(
                    icon: Icons.security,
                    title: 'Set new password',
                    subtitle:
                        'Please choose a strong password. It must be different from\npreviously used passwords.',
                  ),

                  const SizedBox(height: 24),

                  if (_localError != null) ...[
                    AppInfoCard(
                      type: AppInfoType.error,
                      title: 'Invalid link',
                      message: _localError!,
                    ),
                    const SizedBox(height: 18),
                  ],

                  if (state.error != null) ...[
                    AppInfoCard(
                      type: AppInfoType.error,
                      title: 'Reset failed',
                      message: state.error!,
                    ),
                    const SizedBox(height: 18),
                  ],

                  AppLabeledIconField(
                    label: 'New Password',
                    controller: _newPassCtrl,
                    hint: 'Enter new password',
                    icon: Icons.lock_outline,
                    obscureText: !showNewPass,
                    onChanged: (_) => _clearAllErrors(),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Password is required';
                      if (s.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                    suffix: IconButton(
                      icon: Icon(
                        showNewPass
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.muted,
                        size: 20,
                      ),
                      onPressed: state.loading
                          ? null
                          : () => setState(() => showNewPass = !showNewPass),
                    ),
                  ),

                  const SizedBox(height: 16),

                  AppLabeledIconField(
                    label: 'Confirm Password',
                    controller: _confirmCtrl,
                    hint: 'Confirm password',
                    icon: Icons.lock_outline,
                    obscureText: !showConfirmPass,
                    onChanged: (_) => _clearAllErrors(),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Confirm password is required';
                      if (s != _newPassCtrl.text) return 'Passwords do not match';
                      return null;
                    },
                    suffix: IconButton(
                      icon: Icon(
                        showConfirmPass
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.muted,
                        size: 20,
                      ),
                      onPressed: state.loading
                          ? null
                          : () => setState(() => showConfirmPass = !showConfirmPass),
                    ),
                  ),

                  const SizedBox(height: 20),

                  AppPrimaryLoadingButton(
                    label: 'Reset Password',
                    loading: state.loading,
                    onPressed: _submit,
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: AppBackLink(showLabel: true, 
                      label: 'Return to Log In',
                      onTap: state.loading ? null : () => context.go(Routes.login),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
