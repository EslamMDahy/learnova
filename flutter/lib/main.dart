import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/ui/global_error_toast_listener.dart';

void main() {
  runApp(
    const ProviderScope(
      child: GlobalErrorToastListener(
        child: App(),
      ),
    ),
  );
}
