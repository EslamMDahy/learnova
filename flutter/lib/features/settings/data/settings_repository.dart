import 'package:dio/dio.dart';

import '../../../core/storage/user_storage.dart';
import 'dto/user_profile.dart';
import 'dto/user_preferences.dart';
import 'settings_api.dart';

class SettingsRepository {
  final SettingsApi _api;
  SettingsRepository(this._api);

  Future<UserProfile> me({CancelToken? cancelToken}) async {
    
    final u = UserStorage.userMap;
    if (u != null && (u['id']?.toString().trim().isNotEmpty ?? false)) {
      try {
        return UserProfile.fromJson(u);
      } catch (_) {
        // ignore & fallback to API
      }
    }

    // fallback
    return _api.me(cancelToken: cancelToken);
  }

  Future<UserProfile> updateProfile({
    required String fullName,
    String? phoneNumber,
    String? bio,
    String? studentId,
    String? universityEmail,
    required String languagePreference,
    CancelToken? cancelToken,
  }) =>
      _api.updateProfile(
        fullName: fullName,
        phoneNumber: phoneNumber,
        bio: bio,
        studentId: studentId,
        universityEmail: universityEmail,
        languagePreference: languagePreference,
        cancelToken: cancelToken,
      );

  // ──────────── Avatar ────────────

  Future<Map<String, dynamic>> getAvatarUploadUrl({
    required String contentType,
    required int fileSizeBytes,
    CancelToken? cancelToken,
  }) =>
      _api.getAvatarUploadUrl(
        contentType: contentType,
        fileSizeBytes: fileSizeBytes,
        cancelToken: cancelToken,
      );

  Future<void> uploadAvatarToSupabase({
    required String uploadUrl,
    required List<int> bytes,
    required String contentType,
    CancelToken? cancelToken,
  }) =>
      _api.uploadAvatarToSupabase(
        uploadUrl: uploadUrl,
        bytes: bytes,
        contentType: contentType,
        cancelToken: cancelToken,
      );

  Future<String> confirmAvatarUpload({CancelToken? cancelToken}) =>
      _api.confirmAvatarUpload(cancelToken: cancelToken);

  // ──────────── rest ────────────

  Future<String> updatePassword({
    required String currentPassword,
    required String newPassword,
    CancelToken? cancelToken,
  }) =>
      _api.updatePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        cancelToken: cancelToken,
      );

  Future<String> requestAccountDelete({
    required String currentPassword,
    CancelToken? cancelToken,
  }) =>
      _api.requestAccountDelete(
        currentPassword: currentPassword,
        cancelToken: cancelToken,
      );

  Future<String> confirmDeleteAccount({
    required String otp,
    CancelToken? cancelToken,
  }) =>
      _api.confirmDeleteAccount(
        otp: otp,
        cancelToken: cancelToken,
      );

  Future<UserPreferences> getPreferences({CancelToken? cancelToken}) =>
      _api.getPreferences(cancelToken: cancelToken);

  Future<UserPreferences> updatePreferences(
    UserPreferences prefs, {
    CancelToken? cancelToken,
  }) =>
      _api.updatePreferences(prefs, cancelToken: cancelToken);
}
