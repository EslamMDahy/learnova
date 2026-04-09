// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

typedef BeforeUnloadShouldBlock = bool Function();

/// Web-only: Adds a beforeunload handler when there are unsaved changes.
/// Returns a disposer to remove the listener.
VoidCallback registerBeforeUnload(BeforeUnloadShouldBlock shouldBlock) {
  final sub = html.window.onBeforeUnload.listen((event) {
    if (!shouldBlock()) return;

    final e = event as html.BeforeUnloadEvent;
    e.preventDefault();
    e.returnValue = '';
  });

  return () => sub.cancel();
}
