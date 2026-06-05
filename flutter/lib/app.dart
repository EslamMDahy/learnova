import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/session/app_bootstrap_controller.dart';
import 'core/session/session_providers.dart';
import 'core/session/session_snapshot.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/browser_theme_bootstrap.dart';
import 'core/theme/theme_preference_storage.dart';
import 'core/ui/global_loading_overlay.dart';
import 'core/ui/global_loading_bus_binder.dart';
import 'features/settings/presentation/controllers/settings_controller.dart';
import 'shared/pages/splash_screen.dart';

/// Root of the application.
///
/// Bootstrap flow:
///   1. AppBootstrapController.bootstrap() runs once (checks token, loads /me)
///   2. SplashScreen is shown on top of everything while state == inProgress
///   3. When bootstrap completes → splash fades out → GoRouter takes over
///   4. Router redirects to: LandingPage (guest) or Dashboard (authenticated)
///
/// The splash screen is a Stack overlay above MaterialApp.router, so it is
/// NEVER part of the navigation stack and NEVER shown during normal navigation.
class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  late final ProviderSubscription<AppBootstrapState> _bootstrapSub;
  late final ProviderSubscription<SessionSnapshot> _sessionSub;
  final _splashKey = GlobalKey<SplashScreenState>();
  bool _splashVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen once for the bootstrap transition → triggers splash fade-out.
    _bootstrapSub = ref.listenManual<AppBootstrapState>(
      appBootstrapControllerProvider,
      (prev, next) {
        if (next == AppBootstrapState.done && _splashVisible) {
          _onBootstrapDone();
        }
      },
    );

    _sessionSub = ref.listenManual<SessionSnapshot>(
      sessionSnapshotProvider,
      (prev, next) {
        final becameAuthenticated =
            next.isAuthed &&
            next.hasMe &&
            (prev?.isAuthed != true || prev?.hasMe != true);
        if (becameAuthenticated) {
          _loadSettingsPreferences();
        }
      },
    );

    // Run bootstrap exactly once, on the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appBootstrapControllerProvider.notifier).bootstrap();
    });
  }

  void _onBootstrapDone() {
    // Bootstrap just completed → trigger the splash fade-out.
    _splashKey.currentState?.fadeOut();
    _loadSettingsPreferences();
  }

  Future<void> _loadSettingsPreferences() async {
    final session = ref.read(sessionSnapshotProvider);
    if (!session.isAuthed || !session.hasMe) return;
    await ref.read(settingsControllerProvider.notifier).load();
  }

  void _onSplashFadeDone() {
    // Fade animation finished → remove splash widget entirely.
    if (mounted) setState(() => _splashVisible = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bootstrapSub.close();
    _sessionSub.close();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final settingsThemeMode = ref.watch(
      settingsControllerProvider.select((s) => s.preferences?.themeMode),
    );
    final themePreference = ThemePreferenceStorage.normalize(
      settingsThemeMode ?? ThemePreferenceStorage.readThemeMode(),
    );
    final themeMode = ThemePreferenceStorage.toThemeMode(themePreference);
    final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final useDarkTokens = ThemePreferenceStorage.shouldUseDark(
      themeMode: themePreference,
      platformBrightness: platformBrightness,
    );

    if (settingsThemeMode != null) {
      ThemePreferenceStorage.saveThemeMode(settingsThemeMode);
    }
    AppThemeRuntime.setDark(useDarkTokens);
    applyBrowserThemeChrome(dark: useDarkTokens);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      builder: (context, child) {
        return GlobalLoadingBusBinder(
          child: Stack(
            children: [
              // ── App content (router) ──────────────────────────────────
              child ?? const SizedBox.shrink(),
              const GlobalLoadingOverlay(),

              // ── Splash screen (shown only during bootstrap) ───────────
              if (_splashVisible)
                SplashScreen(
                  key: _splashKey,
                  onDone: _onSplashFadeDone,
                ),
            ],
          ),
        );
      },
    );
  }
}
