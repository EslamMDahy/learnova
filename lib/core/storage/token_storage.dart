import 'package:flutter/foundation.dart';

import 'key_value_store.dart';
import 'key_value_store_factory.dart';

class TokenStorage {
  TokenStorage._();

  static const _accessKey = 'learnova_access_token';
  static const _persistKey = 'learnova_persist';
  static const _pendingKey = 'learnova_pending_verify';

  static String? _memoryAccess;

  static final KeyValueStore _session = createSessionStore();
  static final KeyValueStore _local = createLocalStore();

  static final ValueNotifier<int> _rev = ValueNotifier<int>(0);
  static ValueListenable<int> get revision => _rev;
  static Listenable get listenable => _rev;

  static String? get token =>
      _memoryAccess ??
      _session.getString(_accessKey) ??
      _local.getString(_accessKey);

  static bool get hasToken => (token ?? '').trim().isNotEmpty;

  /// True when the user chose "Remember Me":
  /// – the explicit persist flag is set, OR
  /// – the access token is stored in localStorage.
  static bool get isPersisted =>
      _local.containsKey(_persistKey) ||
      (_local.containsKey(_accessKey) &&
          (_local.getString(_accessKey) ?? '').trim().isNotEmpty);

  static String? get pendingVerificationEmail {
    final v = _local.getString(_pendingKey);
    return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
  }

  static void saveSession({
    required String accessToken,
    required bool persist,
  }) {
    final trimmed = accessToken.trim();
    _memoryAccess = trimmed;

    _session.setString(_accessKey, trimmed);

    if (persist) {
      _local.setString(_accessKey, trimmed);
      _local.setString(_persistKey, '1');
    } else {
      _local.remove(_accessKey);
      _local.remove(_persistKey);
    }

    _local.remove(_pendingKey);
    _rev.value++;
  }

  static void saveToken(String token, {required bool persist}) {
    saveSession(accessToken: token, persist: persist);
  }

  static void setPendingVerificationEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isNotEmpty) {
      _local.setString(_pendingKey, trimmed);
      _rev.value++;
    }
  }

  static void clearPendingVerificationEmail() {
    _local.remove(_pendingKey);
    _rev.value++;
  }

  static void clear() {
    _memoryAccess = null;
    _session.remove(_accessKey);
    _local.remove(_accessKey);
    _local.remove(_persistKey);
    _local.remove(_pendingKey);
    _rev.value++;
  }
}
