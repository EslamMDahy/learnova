import 'browser_theme_bootstrap_stub.dart'
    if (dart.library.html) 'browser_theme_bootstrap_web.dart';

void applyBrowserThemeChrome({required bool dark}) {
  applyBrowserThemeChromeImpl(dark: dark);
}
