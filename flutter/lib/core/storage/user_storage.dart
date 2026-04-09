import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../log/app_logger.dart';
import 'key_value_store.dart';
import 'key_value_store_factory.dart';

class UserStorage {
  static const _key = 'learnova_me';
  static Map<String, dynamic>? _cache;

  static final KeyValueStore _session = createSessionStore();
  static final KeyValueStore _local = createLocalStore();

  static final ValueNotifier<int> _rev = ValueNotifier<int>(0);
  static ValueListenable<int> get revision => _rev;
  static Listenable get listenable => _rev;

  static Map<String, dynamic>? get meJson {
    if (_cache != null) return _cache;

    final raw = _session.getString(_key) ?? _local.getString(_key);
    if (raw == null || raw.isEmpty) return null;

    try {
      _cache = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return _cache;
    } catch (_) {
      return null;
    }
  }

  static bool get hasMe => meJson != null;

  /// Backend-aligned: we store { user: {...}, organizations: [...] }
  static Map<String, dynamic>? get userMap {
    final m = meJson;
    if (m == null) return null;

    final u = m['user'];
    if (u is Map) return u.cast<String, dynamic>();

    return null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Common getters used by UI
  // ───────────────────────────────────────────────────────────────────────────

  static String? get userId => userMap?['id']?.toString();
  static String? get email => userMap?['email']?.toString();
  static String? get fullName => userMap?['full_name']?.toString();

  /// Used by admin/instructor shells.
  static String? get avatarUrl => userMap?['avatar_url']?.toString();

  static String? get phoneNumber => userMap?['phone_number']?.toString();
  static String? get bio => userMap?['bio']?.toString();

  static String? get studentId => userMap?['student_id']?.toString();
  static String? get universityEmail => userMap?['university_email']?.toString();

  static String? get languagePreference => userMap?['language_preference']?.toString();
  static String? get createdAt => userMap?['created_at']?.toString();
  static String? get lastLoginAt => userMap?['last_login_at']?.toString();
  static String? get subscriptionPlanName => userMap?['subscription_plan_name']?.toString();

  // ───────────────────────────────────────────────────────────────────────────
  // Role helpers
  // ───────────────────────────────────────────────────────────────────────────

  static String get role =>
      (userMap?['system_role'] ?? '').toString().toLowerCase();

  static bool get isOwner => role == 'owner';
  static bool get isInstructor => role == 'instructor';

  // ───────────────────────────────────────────────────────────────────────────
  // Organizations
  // ───────────────────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> get organizations {
    final root = meJson;
    if (root == null) return const [];

    final raw = root['organizations'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    if (raw is Map) return [raw.cast<String, dynamic>()];
    return const [];
  }

  static String? get selectedOrganizationId {
    final root = meJson;
    if (root == null) return null;

    final v = root['selected_organization_id']?.toString();
    return (v == null || v.trim().isEmpty) ? null : v.trim();
  }

  static String? get organizationId {
    final selected = selectedOrganizationId;
    if (selected != null && selected.isNotEmpty) return selected;

    final orgs = organizations;
    if (orgs.isNotEmpty) {
      final id = orgs.first['id']?.toString();
      if (id != null && id.trim().isNotEmpty) return id.trim();
    }
    return null;
  }

  static bool get hasOrganization =>
      organizationId != null && organizationId!.trim().isNotEmpty;

  // ───────────────────────────────────────────────────────────────────────────
  // Write operations
  // ───────────────────────────────────────────────────────────────────────────

  static void saveMe(Map<String, dynamic> json, {required bool persist}) {
    _cache = json;
    final raw = jsonEncode(json);

    if (persist) {
      _session.remove(_key);
      _local.setString(_key, raw);
    } else {
      _local.remove(_key);
      _session.setString(_key, raw);
    }

    _rev.value++;

    if (kDebugMode) {
      AppLogger.log(
        'UserStorage.saveMe: role=$role isOwner=$isOwner isInstructor=$isInstructor '
        'orgId=$organizationId orgsCount=${organizations.length}',
        level: LogLevel.debug,
      );
    }
  }

  static void clear() {
    _cache = null;
    _local.remove(_key);
    _session.remove(_key);
    _rev.value++;
  }
}
