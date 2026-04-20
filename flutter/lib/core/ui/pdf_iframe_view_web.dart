// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Object createPdfIframeElement({required String url, required bool interactive}) {
  final iframe = html.IFrameElement()
    ..src = url
    ..style.border = 'none'
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.overflow = 'auto'
    ..style.backgroundColor = '#FFFFFF';

  updatePdfIframePointerEvents(iframe, interactive: interactive);
  return iframe;
}

void updatePdfIframePointerEvents(Object element, {required bool interactive}) {
  final iframe = element as html.IFrameElement;
  iframe.style.pointerEvents = interactive ? 'auto' : 'none';
  iframe.style.overflow = 'auto';
}
