import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/before_unload_stub.dart'
    if (dart.library.html) '../../../../core/utils/before_unload_web.dart'
    as before_unload;

import '../../../../core/ui/toast.dart';
import '../../../../core/utils/image_picker_bytes.dart';
import '../../../../core/routing/routes.dart';
import '../../../auth/data/auth_providers.dart';
import '../../presentation/controllers/settings_controller.dart';
import '../../presentation/controllers/settings_state.dart';
import '../../presentation/controllers/settings_form_snapshot.dart';
import '../../../../shared/widgets/app_ui_components.dart';

part 'settings_page_sections.dart';
part 'settings_page_widgets.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _sectionIndex = 0;

  VoidCallback? _beforeUnloadDispose;

  
  final ScrollController _scrollController = ScrollController();
  
  final GlobalKey _kPersonal = GlobalKey();
  final GlobalKey _kSecurity = GlobalKey();
  final GlobalKey _kPreferences = GlobalKey();
  final GlobalKey _kNotifications = GlobalKey();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  // ===== Controllers (hydrate from API) =====
  final firstName = TextEditingController(text: '');
  final lastName = TextEditingController(text: '');
  final universityEmailCtrl = TextEditingController(text: '');
  final studentIdCtrl = TextEditingController(text: '');

  String _language = 'English (US)';

  final bio = TextEditingController(text: '');
  final phoneNumber = TextEditingController(text: '');

  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();

  // ===== Preferences (matches user_preferences) =====
  bool emailNotifications = true;
  bool assignmentAlerts = true;
  bool courseUpdates = true;
  bool announcementNotifications = true;
  bool gradingNotifications = true;
  bool deadlineReminders = true;

  String themeMode = 'light'; // light, dark, system
  String profileVisibility = 'private'; // public, private, connections
  bool showOnlineStatus = true;

  SettingsFormSnapshot? _initialSnapshot;

  DateTime? _cachedCreatedAt;
  DateTime? _cachedLastLoginAt;

  bool _hydrated = false;

  @override
  void initState() {
    super.initState();

    final st = ref.read(settingsControllerProvider);
    if (!_hydrated && st.profile != null) {
      if (st.preferences != null) {
        _hydrated = true;
      }
      _hydrateFields(st);
    }

    Future.microtask(() => ref.read(settingsControllerProvider.notifier).load());

    _beforeUnloadDispose = before_unload.registerBeforeUnload(() => _hasChanges);

    _takeSnapshot();
  }

  @override
  void dispose() {
    _beforeUnloadDispose?.call();
    firstName.dispose();
    lastName.dispose();
    bio.dispose();
    phoneNumber.dispose();
    currentPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    universityEmailCtrl.dispose();
    studentIdCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }



// =========================
// Scroll helpers (left nav)
// =========================

Future<void> _scrollTo(GlobalKey key) async {
  final ctx = key.currentContext;
  if (ctx == null) return;
  await Scrollable.ensureVisible(
    ctx,
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeInOut,
    alignment: 0.02, // small top padding
  );
}

void _onNavSelect(int i) {
  setState(() => _sectionIndex = i);
  switch (i) {
    case 0:
      _scrollTo(_kPersonal);
      break;
    case 1:
      _scrollTo(_kSecurity);
      break;
    case 2:
      _scrollTo(_kPreferences);
      break;
    case 3:
      _scrollTo(_kNotifications);
      break;
    default:
      _scrollTo(_kPersonal);
  }
}

  // =========================
  // Validation helpers
  // =========================

  String? _required(String? v, String msg) {
    if ((v ?? '').trim().isEmpty) return msg;
    return null;
  }

  
  String _fmtMemberSince(DateTime? dt) {
    if (dt == null) return '—';
    final d = dt.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]}, ${d.year}';
  }

  
  String _fmtLastLoginRelative(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';

    // fallback date only
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  String? _validatePhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;

    final ok = RegExp(r'^[0-9+\-\s()]{7,20}$').hasMatch(s);
    if (!ok) return 'Enter a valid phone number';
    return null;
  }

  String? _validateNewPassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'New password is required';
    if (s.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String? _validateConfirmPassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Confirmation is required';
    if (s != newPassword.text) return "Passwords don't match";
    return null;
  }


  // Legacy compatibility alias retained during page refactor.
  TextEditingController get _nameController => firstName;

  void _toast(
    BuildContext context, {
    required String title,
    required String message,
    AppToastType type = AppToastType.info,
    IconData? icon,
  }) {
    switch (type) {
      case AppToastType.success:
        AppToast.success(context, title: title, message: message);
        break;
      case AppToastType.warning:
        AppToast.warning(context, title: title, message: message);
        break;
      case AppToastType.error:
        AppToast.error(context, title: title, message: message);
        break;
      case AppToastType.info:
        AppToast.info(context, title: title, message: message);
        break;
    }
  }

  bool _validateProfileForm() {
    final isValid = _profileFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      _toast(
        context,
        title: 'Validation',
        message: 'Please fix the highlighted fields.',
        type: AppToastType.warning,
        icon: Icons.warning_amber_rounded,
      );
      return false;
    }

    final first = firstName.text.trim();
    final last = lastName.text.trim();
    if ('$first $last'.trim().isEmpty) {
      _toast(
        context,
        title: 'Validation',
        message: 'Name is required.',
        type: AppToastType.warning,
        icon: Icons.warning_amber_rounded,
      );
      return false;
    }

    return true;
  }

  // ──────────────────────────────────────
  // =========================
  // Avatar Upload
  // =========================
  Future<void> _pickAndUploadAvatar() async {
    final picked = await pickSingleImageFile(
      accept: ['image/png', 'image/jpeg'],
    );
    if (picked == null || picked.bytes.isEmpty) return;

    final bytes = picked.bytes;
    var contentType = (picked.mimeType ?? '').trim().toLowerCase();
    final fileName = (picked.name ?? '').trim().toLowerCase();

    if (contentType.isEmpty) {
      if (fileName.endsWith('.png')) {
        contentType = 'image/png';
      } else if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
        contentType = 'image/jpeg';
      }
    }
    if (contentType == 'image/jpg') contentType = 'image/jpeg';

    final isAllowedImage =
        contentType == 'image/png' || contentType == 'image/jpeg';
    if (!isAllowedImage) {
      _toast(
        context,
        title: 'Invalid file',
        message: 'Please choose a PNG or JPG image.',
        type: AppToastType.warning,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    if (bytes.length > 5 * 1024 * 1024) {
      _toast(
        context,
        title: 'Image too large',
        message: 'Maximum avatar size is 5 MB.',
        type: AppToastType.warning,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    final ok = await ref.read(settingsControllerProvider.notifier).uploadAvatar(
          bytes: bytes,
          contentType: contentType,
        );

    if (!mounted) return;
    if (ok) {
      _toast(
        context,
        title: 'Profile updated',
        message: 'Your profile picture was updated successfully.',
        icon: Icons.check_circle_outline,
      );
    }
  }

  bool _validatePasswordForm() {
    final ok = _passwordFormKey.currentState?.validate() ?? false;
    if (!ok) {
      _toast(
        context,
        title: 'Validation',
        message: 'Please fix the highlighted fields.',
        icon: Icons.warning_amber_rounded,
      );
    }
    return ok;
  }

  
  SettingsFormSnapshot _currentSnapshot() {
    return ref.read(settingsControllerProvider.notifier).buildFormSnapshot(
      firstName: firstName.text,
      lastName: lastName.text,
      phone: phoneNumber.text,
      bio: bio.text,
      language: _language,
      emailNotifications: emailNotifications,
      assignmentAlerts: assignmentAlerts,
      courseUpdates: courseUpdates,
      announcementNotifications: announcementNotifications,
      gradingNotifications: gradingNotifications,
      deadlineReminders: deadlineReminders,
      themeMode: themeMode,
      profileVisibility: profileVisibility,
      showOnlineStatus: showOnlineStatus,
    );
  }

  bool get _hasChanges {
    final initial = _initialSnapshot;
    if (initial == null) return false;
    return ref.read(settingsControllerProvider.notifier).hasFormChanges(
      initial: initial,
      current: _currentSnapshot(),
    );
  }

  bool _shouldValidateProfileOnSave() {
    final initial = _initialSnapshot;
    if (initial == null) return true;
    return ref.read(settingsControllerProvider.notifier).shouldValidateProfileOnSave(
      initial: initial,
      current: _currentSnapshot(),
    );
  }



Future<bool> _confirmDiscardDialog(BuildContext context) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Discard changes?'),
      content: const Text(
        'You have unsaved changes. If you leave now, your changes will be lost.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Stay'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  return res ?? false;
}

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final st = ref.watch(settingsControllerProvider);
    final isFirstLoad = st.profile == null || st.preferences == null;
    if (st.loading && isFirstLoad) {
      return Scaffold(
        backgroundColor: AppColors.pageBg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: const Padding(
                padding: AppSpacing.page,
                child: _SettingsSkeleton(),
              ),
            ),
          ),
        ),
      );
    }
    ref.listen(settingsControllerProvider, (prev, next) {
      // ── Hydrate fields as soon as profile data arrives ──────────────────
      // Don't wait for preferences — hydrate immediately when profile loads,
      // then update again when preferences arrive.
      if (!_hydrated && next.profile != null && !next.loading) {
        if (next.preferences != null) {
          // Both arrived together — full hydrate
          _hydrated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _hydrateFields(next);
          });
        } else {
          // Profile arrived first — hydrate profile fields now
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _hydrateFields(next);
          });
        }
      } else if (_hydrated && prev?.preferences == null && next.preferences != null) {
        // Preferences arrived after profile — re-hydrate to fill pref fields
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _hydrateFields(next);
        });
      }

      final err = next.error;
      final ok = next.success;

      if (err != null && err.trim().isNotEmpty) {
        _toast(context,
            title: 'Error', message: err, icon: Icons.error_outline_rounded,);
      } else if (ok != null && ok.trim().isNotEmpty) {
        _toast(context,
            title: 'Done',
            message: ok,
            icon: Icons.check_circle_outline_rounded,);

        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _takeSnapshot();
          setState(() {});
        });
      }
    });

    
    _cachedCreatedAt = st.profile?.createdAt ?? _cachedCreatedAt;
    _cachedLastLoginAt = st.profile?.lastLoginAt ?? _cachedLastLoginAt;

    final isBusy =
        st.savingProfile || st.updatingPassword || st.deleting || st.savingPreferences;

    
    final canSave = _hasChanges && !isBusy;

    
    const double btnH = 40;

return PopScope(
  canPop: !_hasChanges,
  onPopInvokedWithResult: (didPop, _) async {
    if (!didPop) {
      final shouldPop = await _confirmDiscardDialog(context);
      if (shouldPop && context.mounted) Navigator.of(context).pop();
    }
  },
  child: AbsorbPointer(
    absorbing: isBusy,
    child: Container(
      color: AppColors.pageBg,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: AppSpacing.page,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row + actions (stays visible)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Account Settings', style: AppText.h1),
                          const SizedBox(height: 6),
                          Text(
                            'Manage your personal information, security credentials, and system preferences.',
                            style: AppText.subtitle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 120,
                          child: AppPrimaryLoadingButton(
                            label: 'Cancel',
                            loading: false,
                            height: btnH,
                            onPressed: () {
                              setState(() {
                                _restoreSnapshot();
                                currentPassword.clear();
                                newPassword.clear();
                                confirmPassword.clear();
                              });
                              _toast(
                                context,
                                title: 'Cancelled',
                                message: 'Changes discarded.',
                                icon: Icons.info_outline_rounded,
                              );
                            },
                            backgroundColor: AppColors.cardBg,
                            foregroundColor: AppColors.title,
                            borderColor: AppColors.borderSoft,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 160,
                          child: AppPrimaryLoadingButton(
                            label: 'Save Changes',
                            height: btnH,
                            loading: st.savingProfile || st.savingPreferences,
                            onPressed: canSave
                                ? () {
                                    
                                    if (_shouldValidateProfileOnSave()) {
                                      if (!_validateProfileForm()) return;
                                    }

                                    ref
                                        .read(settingsControllerProvider.notifier)
                                        .saveProfile(
                                          firstName: firstName.text.trim(),
                                          lastName: lastName.text.trim(),
                                          phoneNumber: phoneNumber.text.trim(),
                                          bio: bio.text.trim(),
                                          language: _language,
                                          assignmentAlerts: assignmentAlerts,

                                          // prefs (user_preferences)
                                          emailNotifications: emailNotifications,
                                          courseUpdates: courseUpdates,
                                          announcementNotifications:
                                              announcementNotifications,
                                          gradingNotifications: gradingNotifications,
                                          deadlineReminders: deadlineReminders,
                                          themeMode: themeMode,
                                          profileVisibility: profileVisibility,
                                          showOnlineStatus: showOnlineStatus,
                                        );
                                  }
                                : null, 
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Main (scrollable content). Sidebar stays sticky on wide screens.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final isWide = c.maxWidth >= 980;

                      final left = Column(
                        children: [
                          _ProfileCard(
                            name: (st.profile?.fullName.isNotEmpty ?? false)
                                ? st.profile!.fullName
                                : '${firstName.text} ${lastName.text}'.trim(),
                            subtitle: st.profile?.email ?? universityEmailCtrl.text,
                            memberSince: _fmtMemberSince(_cachedCreatedAt),
                            lastLogin: _fmtLastLoginRelative(_cachedLastLoginAt),
                            avatarUrl: st.profile?.avatarUrl,
                            uploadingAvatar: st.uploadingAvatar,
                            onUploadAvatar: () => _pickAndUploadAvatar(),
                          ),
                          const SizedBox(height: 16),
                          _NavCard(
                            selectedIndex: _sectionIndex,
                            onSelect: (i) => _onNavSelect(i),
                          ),
                        ],
                      );

                      final right = Column(
                        children: [
                          _buildPersonalInfoCard(),
                          const SizedBox(height: 16),
                          _buildSecurityCard(st),
                          const SizedBox(height: 16),
                          _buildPreferencesCard(),
                          const SizedBox(height: 16),
                          _buildNotificationsCard(),
                          const SizedBox(height: 16),
                          _buildDangerZone(st),
                          const SizedBox(height: 24),
                        ],
                      );

                      if (!isWide) {
                        return SingleChildScrollView(
                          controller: _scrollController,
                          child: Column(
                            children: [
                              left,
                              const SizedBox(height: 16),
                              right,
                            ],
                          ),
                        );
                      }

                      
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 264 + 32),
                                child: right,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: 0,
                            child: SizedBox(width: 264, child: left),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
  }

}

