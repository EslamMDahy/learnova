// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void applyBrowserThemeChromeImpl({required bool dark}) {
  final bg = dark ? '#0F172A' : '#F6F7F8';
  final surface = dark ? '#0F172A' : '#FFFFFF';

  html.document.documentElement?.style.backgroundColor = bg;
  html.document.body?.style.backgroundColor = bg;

  final head = html.document.head;
  if (head == null) return;

  html.MetaElement? themeColor;
  for (final element in head.querySelectorAll('meta[name="theme-color"]')) {
    if (element is html.MetaElement) {
      themeColor = element;
      break;
    }
  }

  themeColor ??= html.MetaElement()
    ..name = 'theme-color'
    ..attributes['data-learnova-managed'] = 'true';

  themeColor.content = surface;

  if (themeColor.parent == null) {
    head.append(themeColor);
  }
}
