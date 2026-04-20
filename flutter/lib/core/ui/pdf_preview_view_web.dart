// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui_web;

final _registeredPdfViews = <String>{};
final _registeredPdfIframes = <String, html.IFrameElement>{};

void registerPdfPreviewView({
  required String viewType,
  required String url,
  required bool interactive,
}) {
  if (_registeredPdfViews.contains(viewType)) return;
  _registeredPdfViews.add(viewType);

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
    final pdfUrl = '${url}#toolbar=0&navpanes=0&scrollbar=1';
    final iframe = html.IFrameElement()
      ..src = pdfUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.overflow = 'auto'
      ..style.backgroundColor = '#FFFFFF';
    _registeredPdfIframes[viewType] = iframe;
    iframe.style.pointerEvents = interactive ? 'auto' : 'none';
    return iframe;
  });
}

void updatePdfPreviewInteractivity({
  required String viewType,
  required bool interactive,
}) {
  final iframe = _registeredPdfIframes[viewType];
  if (iframe == null) return;
  iframe.style.pointerEvents = interactive ? 'auto' : 'none';
  iframe.style.overflow = 'auto';
}
