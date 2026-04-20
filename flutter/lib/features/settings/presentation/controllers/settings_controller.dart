import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_error_bus.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/log/app_logger.dart';
import '../../../../core/network/error_mapper.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/storage/user_storage.dart';
import '../../data/dto/user_preferences.dart';
import '../../data/dto/user_profile.dart';
import '../../data/settings_providers.dart';
import '../../data/settings_repository.dart';
import 'settings_state.dart';
import 'settings_form_snapshot.dart';

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>(
  (ref) {
    ref.keepAlive();
    return SettingsController(ref);
  },
);

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this.ref) : super(const SettingsState());

  final Ref ref;

  CancelToken? _loadCancel;
  CancelToken? _saveCancel;
  CancelToken? _avatarCancel;

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  void clearMessages() {
    if (state.error != null || state.success != null) {
      state = state.copyWith();
    }
  }

  void _resetLoadCancel() {
    _loadCancel?.cancel('superseded');
    _loadCancel = CancelToken();
  }

  void _resetSaveCancel() {
    _saveCancel?.cancel('superseded');
    _saveCancel = CancelToken();
  }

  void _reportSoftWarning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    AppLogger.log(
      message,
      level: LogLevel.warn,
      error: error,
      stackTrace: stackTrace,
    );
    AppErrorReporter.report(
      ref,
      AppFailure(
        type: AppFailureType.warning,
        message: message,
      ),
    );
  }

  void _handleError(Object e, {bool stopLoading = true}) {
    final failure = mapApiFailure(e);

    
    if (TokenStorage.hasToken && failure.isAuthIssue) {
      if (stopLoading) state = state.copyWith(loading: false);
      AppErrorReporter.report(ref, failure);
      return;
    }

    state = state.copyWith(
      loading: false,
      error: failure.message,
    );
  }

  void _hydrateProfileFromStorageIfPossible() {
    
    if (state.profile != null) return;

    final cachedUser = UserStorage.userMap;
    if (cachedUser == null) return;

    try {
      final profile = UserProfile.fromJson(cachedUser);
      state = state.copyWith(profile: profile);
    } catch (e, st) {
      AppLogger.log(
        'Failed to hydrate settings profile from cached storage.',
        level: LogLevel.warn,
        error: e,
        stackTrace: st,
      );
    }
  }

Future<void> load() async {
  if (state.loading) return;

  clearMessages();

  _hydrateProfileFromStorageIfPossible();

  _resetLoadCancel();

  final hasData = state.profile != null && state.preferences != null;
  state = state.copyWith(loading: !hasData);

  try {
    final settingsApi = ref.read(settingsApiProvider);
    final profile = await settingsApi.me(cancelToken: _loadCancel);

    // ── Merge: don't overwrite existing rich data with sparse /me fields ──
    // /auth/me only returns 4 fields. Login saved the full profile.
    // We merge: existing values are kept; non-null new values override.
    final currentMe = UserStorage.meJson ?? <String, dynamic>{};
    final existingUser = (currentMe['user'] is Map)
        ? (currentMe['user'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    final profileJson = profile.toJson();
    final mergedUser = <String, dynamic>{...existingUser};
    profileJson.forEach((k, v) {
      if (v != null) mergedUser[k] = v;
    });

    UserStorage.saveMe(
      {
        ...currentMe,
        'user': mergedUser,
      },
      persist: TokenStorage.isPersisted,
    );

    // Re-read from storage to get the fully merged profile
    final mergedProfile = UserProfile.fromJson(mergedUser);

    UserPreferences prefs;
    try {
      prefs = await _repo.getPreferences(cancelToken: _loadCancel);
    } catch (e, st) {
      prefs = state.preferences ?? UserPreferences.defaults();
      _reportSoftWarning(
        'Preferences could not be loaded. Showing defaults for now.',
        error: e,
        stackTrace: st,
      );
    }

    state = state.copyWith(
      loading: false,
      profile: mergedProfile,
      preferences: prefs,
    );
  } catch (e, st) {
    if (state.profile != null) {
      state = state.copyWith(loading: false);
      _reportSoftWarning(
        'Unable to refresh settings right now. Showing cached profile data.',
        error: e,
        stackTrace: st,
      );
    } else {
      _handleError(e);
    }
  }
}

  /// Upload avatar: 3-step flow
  /// 1) Get signed upload URL from backend
  /// 2) PUT file bytes to Supabase
  /// 3) Confirm to backend → get new avatar_url

  SettingsFormSnapshot buildFormSnapshot({
    required String firstName,
    required String lastName,
    required String phone,
    required String bio,
    required String language,
    required bool emailNotifications,
    required bool assignmentAlerts,
    required bool courseUpdates,
    required bool announcementNotifications,
    required bool gradingNotifications,
    required bool deadlineReminders,
    required String themeMode,
    required String profileVisibility,
    required bool showOnlineStatus,
  }) {
    return SettingsFormSnapshot(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      phone: phone.trim(),
      bio: bio.trim(),
      language: language,
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

  bool hasFormChanges({
    required SettingsFormSnapshot initial,
    required SettingsFormSnapshot current,
  }) {
    return initial.firstName != current.firstName ||
        initial.lastName != current.lastName ||
        initial.phone != current.phone ||
        initial.bio != current.bio ||
        initial.language != current.language ||
        initial.emailNotifications != current.emailNotifications ||
        initial.assignmentAlerts != current.assignmentAlerts ||
        initial.courseUpdates != current.courseUpdates ||
        initial.announcementNotifications != current.announcementNotifications ||
        initial.gradingNotifications != current.gradingNotifications ||
        initial.deadlineReminders != current.deadlineReminders ||
        initial.themeMode != current.themeMode ||
        initial.profileVisibility != current.profileVisibility ||
        initial.showOnlineStatus != current.showOnlineStatus;
  }

  bool shouldValidateProfileOnSave({
    required SettingsFormSnapshot initial,
    required SettingsFormSnapshot current,
  }) {
    return initial.firstName != current.firstName ||
        initial.lastName != current.lastName ||
        initial.phone != current.phone;
  }

  Future<bool> uploadAvatar({
    required List<int> bytes,
    required String contentType,
  }) async {
    clearMessages();
    _avatarCancel?.cancel('superseded');
    _avatarCancel = CancelToken();

    state = state.copyWith(uploadingAvatar: true);

    try {
      // Step 1: signed upload url
      final urlData = await _repo.getAvatarUploadUrl(
        contentType: contentType,
        fileSizeBytes: bytes.length,
        cancelToken: _avatarCancel,
      );

      final uploadUrl = urlData['upload_url']?.toString() ?? '';
      if (uploadUrl.isEmpty) throw Exception('Missing upload_url from server');

      // Step 2: upload to Supabase
      await _repo.uploadAvatarToSupabase(
        uploadUrl: uploadUrl,
        bytes: bytes,
        contentType: contentType,
        cancelToken: _avatarCancel,
      );

      // Step 3: confirm to backend
      final newAvatarUrl = await _repo.confirmAvatarUpload(
        cancelToken: _avatarCancel,
      );

      // Update local profile state
      final updatedProfile = state.profile != null
          ? UserProfile(
              id: state.profile!.id,
              fullName: state.profile!.fullName,
              email: state.profile!.email,
              avatarUrl: newAvatarUrl.isNotEmpty ? newAvatarUrl : state.profile!.avatarUrl,
              phoneNumber: state.profile!.phoneNumber,
              bio: state.profile!.bio,
              studentId: state.profile!.studentId,
              universityEmail: state.profile!.universityEmail,
              languagePreference: state.profile!.languagePreference,
              systemRole: state.profile!.systemRole,
              isEmailVerified: state.profile!.isEmailVerified,
              accountStatus: state.profile!.accountStatus,
              createdAt: state.profile!.createdAt,
              lastLoginAt: state.profile!.lastLoginAt,
            )
          : null;

      // Persist to UserStorage
      if (updatedProfile != null) {
        final currentMe = UserStorage.meJson ?? <String, dynamic>{};
        UserStorage.saveMe(
          {
            ...currentMe,
            'user': {
              ...(currentMe['user'] as Map<String, dynamic>? ?? {}),
              'avatar_url': updatedProfile.avatarUrl,
            },
          },
          persist: TokenStorage.isPersisted,
        );
      }

      state = state.copyWith(
        uploadingAvatar: false,
        profile: updatedProfile,
        success: 'Profile picture updated successfully',
      );

      return true;
    } catch (e) {
      final failure = mapApiFailure(e);
      state = state.copyWith(
        uploadingAvatar: false,
        error: failure.message,
      );
      return false;
    }
  }

  Future<bool> saveProfile({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String bio,
    required String language,
    required bool assignmentAlerts,

    
    bool? emailNotifications,
    bool? courseUpdates,
    bool? announcementNotifications,
    bool? gradingNotifications,
    bool? deadlineReminders,
    String? themeMode,
    String? profileVisibility,
    bool? showOnlineStatus,
  }) async {
    clearMessages();
    _resetSaveCancel();
    state = state.copyWith(savingProfile: true);

    try {
      final fullName = _mergeName(firstName, lastName);
      final langCode = _mapLanguageToCode(language);

      final updatedProfile = await _repo.updateProfile(
        fullName: fullName,
        phoneNumber: phoneNumber,
        bio: bio,
        studentId: state.profile?.studentId,
        universityEmail: state.profile?.universityEmail,
        languagePreference: langCode,
        cancelToken: _saveCancel,
      );

      
      final old = state.profile;

      final mergedProfile = UserProfile(
        id: updatedProfile.id,
        fullName: updatedProfile.fullName,
        email: updatedProfile.email,
        avatarUrl: updatedProfile.avatarUrl ?? old?.avatarUrl,
        phoneNumber: updatedProfile.phoneNumber ?? old?.phoneNumber,
        bio: updatedProfile.bio ?? old?.bio,
        studentId: updatedProfile.studentId ?? old?.studentId,
        universityEmail: updatedProfile.universityEmail ?? old?.universityEmail,
        languagePreference: updatedProfile.languagePreference,
        systemRole: updatedProfile.systemRole,
        isEmailVerified: updatedProfile.isEmailVerified,
        accountStatus: updatedProfile.accountStatus,
        createdAt: updatedProfile.createdAt ?? old?.createdAt,
        lastLoginAt: updatedProfile.lastLoginAt ?? old?.lastLoginAt,
      );

      
      final currentMe = UserStorage.meJson ?? <String, dynamic>{};
      UserStorage.saveMe(
        {
          ...currentMe,
          'user': mergedProfile.toJson(),
        },
        persist: TokenStorage.isPersisted,
      );

      // preferences
      final currentPrefs = state.preferences ?? UserPreferences.defaults();
      final nextPrefs = UserPreferences(
        emailNotifications: emailNotifications ?? currentPrefs.emailNotifications,
        assignmentAlerts: assignmentAlerts,
        courseUpdates: courseUpdates ?? currentPrefs.courseUpdates,
        announcementNotifications:
            announcementNotifications ?? currentPrefs.announcementNotifications,
        gradingNotifications:
            gradingNotifications ?? currentPrefs.gradingNotifications,
        deadlineReminders: deadlineReminders ?? currentPrefs.deadlineReminders,
        themeMode: themeMode ?? currentPrefs.themeMode,
        profileVisibility: profileVisibility ?? currentPrefs.profileVisibility,
        showOnlineStatus: showOnlineStatus ?? currentPrefs.showOnlineStatus,
      );

      UserPreferences savedPrefs = nextPrefs;
      var preferencesSyncFailed = false;

      try {
        state = state.copyWith(savingPreferences: true);
        savedPrefs = await _repo.updatePreferences(
          nextPrefs,
          cancelToken: _saveCancel,
        );
      } catch (e, st) {
        savedPrefs = nextPrefs;
        preferencesSyncFailed = true;
        _reportSoftWarning(
          'Profile was saved, but preference changes could not be synced.',
          error: e,
          stackTrace: st,
        );
      } finally {
        state = state.copyWith(savingPreferences: false);
      }

      state = state.copyWith(
        savingProfile: false,
        profile: mergedProfile,
        preferences: savedPrefs,
        success: preferencesSyncFailed
            ? 'Profile saved. Preferences will need to be retried.'
            : 'Saved',
      );

      return true;
    } catch (e) {
      final failure = mapApiFailure(e);

      if (TokenStorage.hasToken && failure.isAuthIssue) {
        state = state.copyWith(savingProfile: false);
        AppErrorReporter.report(ref, failure);
        return false;
      }

      state = state.copyWith(
        savingProfile: false,
        error: failure.message,
      );
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    clearMessages();
    _resetSaveCancel();
    state = state.copyWith(updatingPassword: true);

    try {
      final msg = await _repo.updatePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        cancelToken: _saveCancel,
      );

      state = state.copyWith(
        updatingPassword: false,
        success: msg.isEmpty ? 'Password updated' : msg,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        updatingPassword: false,
        error: mapApiFailure(e).message,
      );
      return false;
    }
  }

  Future<bool> requestDelete({required String currentPassword}) async {
    clearMessages();
    _resetSaveCancel();
    state = state.copyWith(deleting: true);

    try {
      final msg = await _repo.requestAccountDelete(
        currentPassword: currentPassword,
        cancelToken: _saveCancel,
      );

      state = state.copyWith(
        deleting: false,
        success: msg.isEmpty ? 'OTP sent' : msg,
      );
      return true;
    } catch (e) {
      state = state.copyWith(deleting: false, error: mapApiFailure(e).message);
      return false;
    }
  }

  Future<bool> confirmDelete({required String otp}) async {
    clearMessages();
    _resetSaveCancel();
    state = state.copyWith(deleting: true);

    try {
      final msg = await _repo.confirmDeleteAccount(
        otp: otp,
        cancelToken: _saveCancel,
      );

      state = state.copyWith(
        deleting: false,
        success: msg.isEmpty ? 'Account deleted' : msg,
      );
      return true;
    } catch (e) {
      state = state.copyWith(deleting: false, error: mapApiFailure(e).message);
      return false;
    }
  }

  String _mergeName(String first, String last) {
    final f = first.trim();
    final l = last.trim();
    if (f.isEmpty) return l;
    if (l.isEmpty) return f;
    return '$f $l';
  }

  String _mapLanguageToCode(String ui) {
    switch (ui) {
      case 'English (US)':
      case 'English (UK)':
        return 'en';
      case 'Arabic':
        return 'ar';
      default:
        return 'en';
    }
  }

  @override
  void dispose() {
    _loadCancel?.cancel('disposed');
    _saveCancel?.cancel('disposed');
    _avatarCancel?.cancel('disposed');
    super.dispose();
  }
}
