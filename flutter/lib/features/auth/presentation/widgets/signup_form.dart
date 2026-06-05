import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/storage/token_storage.dart';
import '../controllers/signup_controller.dart';


import '../../../../shared/widgets/app_ui_components.dart';

enum AccountType { user, owner }
enum UserKind { student, instructor, assistant }

class SignUpForm extends ConsumerStatefulWidget {
  final bool isMobile;
  const SignUpForm({super.key, this.isMobile = false});

  @override
  ConsumerState<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends ConsumerState<SignUpForm> {
  final _formKey = GlobalKey<FormState>();
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;

  AccountType accountType = AccountType.user;
  UserKind userKind = UserKind.student;

  bool isChecked = false;
  bool _obscurePassword = true;

  // UI/local error (terms etc.)
  String? _localError;

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _clearLocalError() {
    if (_localError != null) setState(() => _localError = null);
  }

  void _clearAllErrors() {
    _clearLocalError();
    ref.read(signupControllerProvider.notifier).clearError();
  }

  void _onSwitchAccountType(AccountType type) {
    if (accountType == type) return;

    setState(() {
      accountType = type;
      _localError = null;

      
      if (type == AccountType.owner) {
        userKind = UserKind.student; // irrelevant for owner
      }
    });

    ref.read(signupControllerProvider.notifier).clearError();
  }

  String? _validatePassword(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Password is required';
    if (s.length < 8) return 'Min 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(s)) return 'Add at least 1 uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(s)) return 'Add at least 1 lowercase letter';
    if (!RegExp(r'\d').hasMatch(s)) return 'Add at least 1 number';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\\/\[\]=+~`]').hasMatch(s)) {
      return 'Add at least 1 special character';
    }
    if (s.contains(' ')) return 'No spaces allowed';
    return null;
  }

  Future<void> _onCreateAccount() async {
    if (_autoValidate != AutovalidateMode.onUserInteraction) {
      setState(() => _autoValidate = AutovalidateMode.onUserInteraction);
    }

    _clearAllErrors();

    final okForm = _formKey.currentState?.validate() ?? false;
    if (!okForm) return;

    if (!isChecked) {
      setState(() => _localError = 'Please accept Terms and Privacy Policy.');
      return;
    }

    final fullName =
        '${firstNameController.text.trim()} ${lastNameController.text.trim()}'
            .trim();

    final systemRole =
        accountType == AccountType.owner ? 'owner' : userKind.name;

    final ok = await ref.read(signupControllerProvider.notifier).signup(
          fullName: fullName,
          email: emailController.text.trim(),
          password: passwordController.text,
          systemRole: systemRole,
        );

    if (!mounted) return;

    if (ok) {
      final email = emailController.text.trim();
      // Persist so that reopening the browser before verifying
      // always returns the user to this screen.
      TokenStorage.setPendingVerificationEmail(email);
      context.go(Routes.verifyEmailSentFor(email));
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final state = ref.watch(signupControllerProvider);

    // shown error: local first then api
    final shownError = _localError ?? state.error;

    return Container(
      color: AppColors.cardBg,
      padding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 24 : 56),
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              autovalidateMode: _autoValidate,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppFormHeader(
                    title: 'Create account',
                    subtitle:
                        'Start your journey with AI-driven personalized assessments today.',
                  ),
                  AppSpacing.gap16,

                  if (shownError != null) ...[
                    AppErrorBox(message: shownError),
                    const SizedBox(height: 14),
                  ],

                  AppSegmentedControl<AccountType>(
                    disabled: state.loading,
                    value: accountType,
                    onChanged: _onSwitchAccountType,
                    options: [
                      const AppSegmentOption(label: 'User', value: AccountType.user),
                      const AppSegmentOption(label: 'Owner', value: AccountType.owner),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (accountType == AccountType.user) ...[
                    AppSegmentedControl<UserKind>(
                      disabled: state.loading,
                      value: userKind,
                      onChanged: (k) => setState(() => userKind = k),
                      options: [
                        const AppSegmentOption(label: 'Student', value: UserKind.student),
                        const AppSegmentOption(label: 'Instructor', value: UserKind.instructor),
                        const AppSegmentOption(label: 'Assistant', value: UserKind.assistant),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: AppLabeledIconField(
                          label: 'First Name',
                          controller: firstNameController,
                          hint: 'Enter first name',
                          icon: Icons.person_outline,
                          onChanged: (_) => _clearAllErrors(),
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: AppLabeledIconField(
                          label: 'Last Name',
                          controller: lastNameController,
                          hint: 'Enter last name',
                          icon: Icons.person_outline,
                          onChanged: (_) => _clearAllErrors(),
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  AppLabeledIconField(
                    label: 'Email',
                    controller: emailController,
                    hint: 'Enter your email address',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => _clearAllErrors(),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Email is required';
                      if (!s.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppLabeledIconField(
                        label: 'Password',
                        controller: passwordController,
                        hint: 'Create a password',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        onChanged: (_) {
                          _clearAllErrors();
                          setState(() {}); 
                        },
                        validator: _validatePassword,
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
                      const SizedBox(height: 10),
                      AppPasswordStrengthHints(password: passwordController.text),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Checkbox(
                        value: isChecked,
                        activeColor: AppColors.primary,
                        checkColor: Colors.white,
                        onChanged: state.loading
                            ? null
                            : (v) => setState(() {
                                  isChecked = v ?? false;
                                  _clearLocalError();
                                }),
                      ),
                      Expanded(
                        child: Wrap(
                          children: [
                            Text(
                              'I agree to the ',
                              style: AppText.input.copyWith(fontSize: 14),
                            ),
                            InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
                              onTap: state.loading ? null : () {},
                              child: Text(
                                'Terms',
                                style: AppText.input.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              ' and ',
                              style: AppText.input.copyWith(fontSize: 14),
                            ),
                            InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
                              onTap: state.loading ? null : () {},
                              child: Text(
                                'Privacy Policy',
                                style: AppText.input.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: state.loading ? null : _onCreateAccount,
                      child: state.loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: AppText.input.copyWith(color: AppColors.title),
                      ),
                      InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
                        onTap: state.loading ? null : () => context.go(Routes.login),
                        child: Text(
                          'Log in',
                          style: AppText.input.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
