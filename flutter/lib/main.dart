import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/browser_theme_bootstrap.dart';
import 'core/theme/theme_preference_storage.dart';
import 'core/ui/global_error_toast_listener.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final initialThemeMode = ThemePreferenceStorage.readThemeMode();
  final initialDark = ThemePreferenceStorage.shouldUseDark(
    themeMode: initialThemeMode,
    platformBrightness: WidgetsBinding.instance.platformDispatcher.platformBrightness,
  );
  AppThemeRuntime.setDark(initialDark);
  applyBrowserThemeChrome(dark: initialDark);

  runApp(
    const ProviderScope(
      child: GlobalErrorToastListener(
        child: App(),
      ),
    ),
  );
}
