part of 'settings_page.dart';

extension _SettingsPageSections on _SettingsPageState {

  Widget _buildReadOnlyProfileValue({
    required String label,
    required String value,
    required String fallback,
    required IconData icon,
    required String helperText,
  }) {
    final resolved = value.trim().isNotEmpty ? value.trim() : fallback;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        AppSpacing.gap6,
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.muted, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  resolved,
                  style: TextStyle(
                    color: AppColors.title,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.lock_outline, color: AppColors.muted, size: 18),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          helperText,
          style: AppText.mutedSmall,
        ),
      ],
    );
  }


  // =========================
  // Sections
  // =========================

  Widget _buildPersonalInfoCard() {
    return AppCard(
      key: _kPersonal,
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionHeader(
              title: 'Personal Information',
              subtitle: 'Update your personal details here.',
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, c) {
                final isWide = c.maxWidth >= 780;

                final first = AppLabeledIconField(
                  label: 'First Name',
                  controller: firstName,
                  hint: 'First name',
                  icon: Icons.person_outline,
                  onChanged: (_) => setState(() {}),
                  validator: (v) => _required(v, 'First name is required'),
                );

                final last = AppLabeledIconField(
                  label: 'Last Name',
                  controller: lastName,
                  hint: 'Last name',
                  icon: Icons.person_outline,
                  onChanged: (_) => setState(() {}),
                  validator: (_) => null,
                );

                final row = isWide
                    ? Row(
                        children: [
                          Expanded(child: first),
                          const SizedBox(width: 24),
                          Expanded(child: last),
                        ],
                      )
                    : Column(
                        children: [
                          first,
                          const SizedBox(height: 16),
                          last,
                        ],
                      );

                return Column(
                  children: [
                    row,
                    const SizedBox(height: 16),
                    _buildReadOnlyProfileValue(
                      label: 'University Email',
                      value: universityEmailCtrl.text,
                      fallback: 'Not available',
                      icon: Icons.email_outlined,
                      helperText: 'Managed by your account identity and not editable from settings yet.',
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, c2) {
                        final wide2 = c2.maxWidth >= 780;

                        final id = _buildReadOnlyProfileValue(
                          label: 'Student ID',
                          value: studentIdCtrl.text,
                          fallback: 'Not set',
                          icon: Icons.badge_outlined,
                          helperText: 'This field is currently read-only until backend profile support is finalized.',
                        );

                        final phone = AppLabeledIconField(
                          label: 'Phone Number',
                          controller: phoneNumber,
                          hint: '+1 ...',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          onChanged: (_) => setState(() {}),
                          validator: _validatePhone,
                        );

                        return wide2
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: id),
                                  const SizedBox(width: 24),
                                  Expanded(child: phone),
                                ],
                              )
                            : Column(
                                children: [
                                  id,
                                  const SizedBox(height: 16),
                                  phone,
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 16),
                    AppLabeledIconField(
                      label: 'Bio / Academic Interests',
                      controller: bio,
                      hint: 'Write something...',
                      icon: Icons.edit_outlined,
                      onChanged: (_) => setState(() {}),
                      validator: (_) => null,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityCard(SettingsState st) {
    return AppCard(
      key: _kSecurity,
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionHeader(
              title: 'Security',
              subtitle: 'Manage your password and authentication settings.',
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, c) {
                final isWide = c.maxWidth >= 780;

                final left = Column(
                  children: [
                    AppLabeledIconField(
                      label: 'Current Password',
                      controller: currentPassword,
                      hint: 'Enter current password',
                      icon: Icons.lock_outline,
                      obscureText: _obscureCurrent,
                      onChanged: (_) => setState(() {}),
                      validator: (v) => _required(v, 'Current password is required'),
                      suffix: IconButton(
                        icon: Icon(
                          _obscureCurrent
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.muted,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppLabeledIconField(
                      label: 'New Password',
                      controller: newPassword,
                      hint: 'Enter new password',
                      icon: Icons.lock_outline,
                      obscureText: _obscureNew,
                      onChanged: (_) => setState(() {}),
                      validator: _validateNewPassword,
                      suffix: IconButton(
                        icon: Icon(
                          _obscureNew
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.muted,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppLabeledIconField(
                      label: 'Confirm New Password',
                      controller: confirmPassword,
                      hint: 'Confirm new password',
                      icon: Icons.lock_outline,
                      obscureText: _obscureConfirm,
                      onChanged: (_) => setState(() {}),
                      validator: _validateConfirmPassword,
                      suffix: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.muted,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppPrimaryLoadingButton(
                        label: 'Update Password',
                        loading: st.updatingPassword,
                        height: 40, 
                        onPressed: st.updatingPassword
                            ? null
                            : () async {
                                if (!_validatePasswordForm()) return;

                                if (currentPassword.text == newPassword.text) {
                                  _toast(
                                    context,
                                    title: 'Validation',
                                    message: 'New password must be different',
                                    icon: Icons.warning_amber_rounded,
                                  );
                                  return;
                                }

                                final ok = await ref
                                    .read(settingsControllerProvider.notifier)
                                    .changePassword(
                                      currentPassword: currentPassword.text,
                                      newPassword: newPassword.text,
                                    );

                                if (!mounted || !ok) return;
                                setState(() {
                                  currentPassword.clear();
                                  newPassword.clear();
                                  confirmPassword.clear();
                                  _obscureCurrent = true;
                                  _obscureNew = true;
                                  _obscureConfirm = true;
                                });
                              },
                        backgroundColor: AppColors.cardBg,
                        foregroundColor: AppColors.title,
                        borderColor: AppColors.borderSoft,
                      ),
                    ),
                  ],
                );

                if (!isWide) return left;

                return Row(
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tips',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.title,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Use a strong password and avoid reusing it across services.',
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                              color: AppColors.muted,
                              height: 20 / 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return AppCard(
      key: _kPreferences,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Preferences',
            subtitle: 'Customize your system experience.',
          ),
          const SizedBox(height: 24),
          AppModernDropdown<String>(
            label: 'Interface Language',
            value: _language,
            items: [
              const DropdownMenuItem(value: 'English (US)', child: Text('English (US)')),
              const DropdownMenuItem(value: 'English (UK)', child: Text('English (UK)')),
              const DropdownMenuItem(value: 'Arabic', child: Text('Arabic')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _language = v);
            },
          ),
          const SizedBox(height: 16),
          AppModernDropdown<String>(
            label: 'Theme Mode',
            value: themeMode,
            items: [
              const DropdownMenuItem(value: 'light', child: Text('Light')),
              const DropdownMenuItem(value: 'dark', child: Text('Dark')),
              const DropdownMenuItem(value: 'system', child: Text('System')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => themeMode = v);
              ref.read(settingsControllerProvider.notifier).applyLocalThemeMode(v);
            },
          ),
          const SizedBox(height: 16),
          AppModernDropdown<String>(
            label: 'Profile Visibility',
            value: profileVisibility,
            items: [
              const DropdownMenuItem(value: 'public', child: Text('Public')),
              const DropdownMenuItem(value: 'private', child: Text('Private')),
              const DropdownMenuItem(value: 'connections', child: Text('Connections')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => profileVisibility = v);
            },
          ),
          const SizedBox(height: 16),
          // ignore: deprecated_member_use_from_same_package
          AppToggleRow(
            title: 'Show Online Status',
            subtitle: "Allow others to see when you're online.",
            value: showOnlineStatus,
            onChanged: (v) => setState(() => showOnlineStatus = v),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNotificationsCard() {
    return AppCard(
      key: _kNotifications,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Notifications',
            subtitle: 'Control how and when you receive updates.',
          ),
          const SizedBox(height: 24),
          // ignore: deprecated_member_use_from_same_package
          AppToggleRow(
            title: 'Email Notifications',
            subtitle: 'Receive notifications by email.',
            value: emailNotifications,
            onChanged: (v) => setState(() => emailNotifications = v),
          ),
          const SizedBox(height: 12),
          // ignore: deprecated_member_use_from_same_package
          AppToggleRow(
            title: 'Assignment Alerts',
            subtitle: 'Get notified when new assessments are posted.',
            value: assignmentAlerts,
            onChanged: (v) => setState(() => assignmentAlerts = v),
          ),
          const SizedBox(height: 12),
          // ignore: deprecated_member_use_from_same_package
          AppToggleRow(
            title: 'Course Updates',
            subtitle: 'Updates about your courses.',
            value: courseUpdates,
            onChanged: (v) => setState(() => courseUpdates = v),
          ),
          const SizedBox(height: 12),
          // ignore: deprecated_member_use_from_same_package
          AppToggleRow(
            title: 'Announcements',
            subtitle: 'Important announcements.',
            value: announcementNotifications,
            onChanged: (v) => setState(() => announcementNotifications = v),
          ),
          const SizedBox(height: 12),
          // ignore: deprecated_member_use_from_same_package
          AppToggleRow(
            title: 'Grading Notifications',
            subtitle: 'Grades & evaluation updates.',
            value: gradingNotifications,
            onChanged: (v) => setState(() => gradingNotifications = v),
          ),
          const SizedBox(height: 12),
          // ignore: deprecated_member_use_from_same_package
          AppToggleRow(
            title: 'Deadline Reminders',
            subtitle: 'Reminders before deadlines.',
            value: deadlineReminders,
            onChanged: (v) => setState(() => deadlineReminders = v),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone(SettingsState st) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 560;

        final textContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Danger Zone',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.dangerTitle,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Once you delete your account, there is no going back. Please be certain.',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: Color(0xCCDC2626),
                height: 20 / 14,
              ),
            ),
          ],
        );

        final button = AppPrimaryLoadingButton(
          label: 'Delete Account',
          loading: st.deleting,
          onPressed: () => _openDeleteDialog(context),
          height: 40,
          backgroundColor: AppColors.dangerText,
          foregroundColor: Colors.white,
        );


        return Container(
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: AppColors.dangerBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.dangerBorder),
          ),
          child: narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    textContent,
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: button),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: textContent),
                    const SizedBox(width: 16),
                    SizedBox(width: 170, child: button),
                  ],
                ),
        );
      },
    );
  }

  // =========================
  // Delete Flow (Popup)
  // =========================

  void _openDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountDialog(),
    );
  }

  // =========================
  // Snapshot helpers
  // =========================

  /// Populate all form fields from a loaded [SettingsState].
  /// Called from initState (cache hit) AND from ref.listen (async load).
  void _hydrateFields(SettingsState st) {
    if (st.profile == null) return;

    final full = st.profile!.fullName.trim();
    final parts = full.split(RegExp(r'\s+'));
    firstName.text = parts.isNotEmpty ? parts.first : '';
    lastName.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    universityEmailCtrl.text = st.profile!.universityEmail ?? st.profile!.email;
    studentIdCtrl.text = st.profile!.studentId ?? '';
    phoneNumber.text = st.profile!.phoneNumber ?? '';
    bio.text = st.profile!.bio ?? '';

    setState(() {
      _language = _mapLangCodeToUi(st.profile!.languagePreference);

      // Only update prefs if they've loaded
      if (st.preferences != null) {
        emailNotifications        = st.preferences!.emailNotifications;
        assignmentAlerts          = st.preferences!.assignmentAlerts;
        courseUpdates             = st.preferences!.courseUpdates;
        announcementNotifications = st.preferences!.announcementNotifications;
        gradingNotifications      = st.preferences!.gradingNotifications;
        deadlineReminders         = st.preferences!.deadlineReminders;
        themeMode                 = st.preferences!.themeMode;
        profileVisibility         = st.preferences!.profileVisibility;
        showOnlineStatus          = st.preferences!.showOnlineStatus;
      }
    });

    _takeSnapshot();
  }

  void _takeSnapshot() {
    _initialSnapshot = _currentSnapshot();
  }

  void _restoreSnapshot() {
    final snapshot = _initialSnapshot;
    if (snapshot == null) return;

    firstName.text = snapshot.firstName;
    lastName.text = snapshot.lastName;
    phoneNumber.text = snapshot.phone;
    bio.text = snapshot.bio;
    _language = snapshot.language;

    emailNotifications = snapshot.emailNotifications;
    assignmentAlerts = snapshot.assignmentAlerts;
    courseUpdates = snapshot.courseUpdates;
    announcementNotifications = snapshot.announcementNotifications;
    gradingNotifications = snapshot.gradingNotifications;
    deadlineReminders = snapshot.deadlineReminders;

    themeMode = snapshot.themeMode;
    ref.read(settingsControllerProvider.notifier).applyLocalThemeMode(themeMode);
    profileVisibility = snapshot.profileVisibility;
    showOnlineStatus = snapshot.showOnlineStatus;
  }

  String _mapLangCodeToUi(String code) {
    switch (code) {
      case 'en_US':
      case 'en':
        return 'English (US)';
      case 'en_GB':
        return 'English (UK)';
      case 'ar_EG':
      case 'ar':
        return 'Arabic';
      default:
        return 'English (US)';
    }
  }


  static void _toast(
    BuildContext context, {
    required String title,
    required String message,
    AppToastType type = AppToastType.info,
    // icon param kept for call-site compatibility but ignored
    IconData? icon,
  }) {
    switch (type) {
      case AppToastType.success:
        AppToast.success(context, title: title, message: message);
      case AppToastType.warning:
        AppToast.warning(context, title: title, message: message);
      case AppToastType.error:
        AppToast.error(context, title: title, message: message);
      case AppToastType.info:
        AppToast.info(context, title: title, message: message);
    }
  }
}

// ============================================================================
// Delete Account Dialog (improved UI/UX)
// ============================================================================

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _passCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _otpStep = false;
  bool _obscurePass = true;

  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _passCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startCountdown([int seconds = 60]) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  String _mmss(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "${m.toString()}:${s.toString().padLeft(2, '0')}";
  }

  Future<void> _requestOtp() async {
    final pass = _passCtrl.text.trim();
    if (pass.isEmpty) {
      AppToast.warning(
        context,
        title: 'Validation',
        message: 'Password is required',
      );
      return;
    }

    final ok = await ref
        .read(settingsControllerProvider.notifier)
        .requestDelete(currentPassword: pass);

    if (!mounted) return;
    if (ok) {
      setState(() {
        _otpStep = true;
        _otpCtrl.clear();
      });
      _startCountdown();
    }
  }

  Future<void> _confirmDelete() async {
    final otp = _otpCtrl.text.trim();
    final valid = RegExp(r'^[a-zA-Z0-9]{6}$').hasMatch(otp);

    if (!valid) {
      AppToast.warning(
        context,
        title: 'Validation',
        message: 'Enter a valid 6-character OTP',
      );
      return;
    }

    final ok = await ref
        .read(settingsControllerProvider.notifier)
        .confirmDelete(otp: otp);

    if (!mounted) return;
    if (ok) {
      
      await ref.read(authRepositoryProvider).logout();

      if (context.mounted) {
        Navigator.of(context).pop();
        // go to login
        context.go(Routes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(settingsControllerProvider);
    final isBusy = st.deleting;

    final title = _otpStep ? 'Confirm deletion' : 'Delete account';
    final subtitle = _otpStep
        ? 'Enter the 6-character code sent to your email to confirm deletion.'
        : 'We’ll send a one-time code to confirm. This action can’t be undone.';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ),
                  IconButton(
                    onPressed: isBusy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 14),

              // step pills
              Row(
                children: [
                  _StepPill(active: !_otpStep, label: '1  Password'),
                  const SizedBox(width: 8),
                  _StepPill(active: _otpStep, label: '2  OTP'),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.dangerBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.dangerText, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Deleting your account is permanent. You’ll lose access to your data.',
                        style: TextStyle(
                          color: Color(0xCCDC2626),
                          height: 20 / 14,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (!_otpStep)
                AppLabeledIconField(
                  label: 'Current Password',
                  controller: _passCtrl,
                  hint: '••••••••',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePass,
                  onChanged: (_) => setState(() {}),
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.muted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                ),

              if (_otpStep)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppLabeledIconField(
                      label: 'OTP',
                      controller: _otpCtrl,
                      hint: '6-character code',
                      icon: Icons.verified_outlined,
                      keyboardType: TextInputType.text,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Didn’t get the code?',
                          style: TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: (isBusy || _secondsLeft > 0)
                              ? null
                              : () async {
                                  await _requestOtp();
                                },
                          child: Text(
                            _secondsLeft > 0
                                ? 'Resend in ${_mmss(_secondsLeft)}'
                                : 'Resend code',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppPrimaryLoadingButton(
                      label: _otpStep ? 'Back' : 'Cancel',
                      loading: false,
                      onPressed: isBusy
                          ? null
                          : () {
                              if (_otpStep) {
                                setState(() => _otpStep = false);
                                return;
                              }
                              Navigator.of(context).pop();
                            },
                      height: 40,
                      backgroundColor: AppColors.cardBg,
                      foregroundColor: AppColors.title,
                      borderColor: AppColors.borderSoft,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppPrimaryLoadingButton(
                      label: _otpStep ? 'Confirm delete' : 'Request OTP',
                      loading: isBusy,
                      onPressed: isBusy
                          ? null
                          : () async {
                              if (_otpStep) {
                                await _confirmDelete();
                              } else {
                                await _requestOtp();
                              }
                            },
                      height: 40,
                      backgroundColor: AppColors.dangerText,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}
