import 'package:flutter/material.dart';

import '../storage/key_value_store.dart';
import '../storage/key_value_store_factory.dart';

/// Synchronous cache for the selected theme mode.
///
/// This is intentionally independent from the authenticated settings API so
/// Flutter Web can paint the correct theme immediately after a browser refresh,
/// before bootstrap and /settings/preferences finish loading.
class ThemePreferenceStorage {
  ThemePreferenceStorage._();

  static const String _key = 'learnova_theme_mode';
  static const String fallbackThemeMode = 'light';

  static final KeyValueStore _local = createLocalStore();

  static String normalize(String? value) {
    switch ((value ?? fallbackThemeMode).trim().toLowerCase()) {
      case 'dark':
        return 'dark';
      case 'system':
        return 'system';
      case 'light':
      default:
        return 'light';
    }
  }

  static String readThemeMode() {
    return normalize(_local.getString(_key));
  }

  static void saveThemeMode(String? value) {
    _local.setString(_key, normalize(value));
  }

  static ThemeMode toThemeMode(String? value) {
    switch (normalize(value)) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  static bool shouldUseDark({
    required String? themeMode,
    required Brightness platformBrightness,
  }) {
    final normalized = normalize(themeMode);
    return normalized == 'dark' ||
        (normalized == 'system' && platformBrightness == Brightness.dark);
  }
}
