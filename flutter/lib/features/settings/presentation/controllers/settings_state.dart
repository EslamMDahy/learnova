import '../../data/dto/user_profile.dart';
import '../../data/dto/user_preferences.dart';

class SettingsState {
  final bool loading;
  final bool savingProfile;
  final bool savingPreferences;
  final bool updatingPassword;
  final bool deleting;
  final bool uploadingAvatar;

  final UserProfile? profile;
  final UserPreferences? preferences;

  final String? error;
  final String? success;

  const SettingsState({
    this.loading = false,
    this.savingProfile = false,
    this.savingPreferences = false,
    this.updatingPassword = false,
    this.deleting = false,
    this.uploadingAvatar = false,
    this.profile,
    this.preferences,
    this.error,
    this.success,
  });

  SettingsState copyWith({
    bool? loading,
    bool? savingProfile,
    bool? savingPreferences,
    bool? updatingPassword,
    bool? deleting,
    bool? uploadingAvatar,
    UserProfile? profile,
    UserPreferences? preferences,
    String? error,
    String? success,
  }) {
    return SettingsState(
      loading: loading ?? this.loading,
      savingProfile: savingProfile ?? this.savingProfile,
      savingPreferences: savingPreferences ?? this.savingPreferences,
      updatingPassword: updatingPassword ?? this.updatingPassword,
      deleting: deleting ?? this.deleting,
      uploadingAvatar: uploadingAvatar ?? this.uploadingAvatar,
      profile: profile ?? this.profile,
      preferences: preferences ?? this.preferences,
      error: error,
      success: success,
    );
  }
}
