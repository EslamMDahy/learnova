import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warn, error }

/// Minimal logging abstraction.
///
/// - In release builds, debug logs are dropped.
/// - No external dependencies are introduced.
/// - Callers should avoid logging sensitive data (tokens, passwords).
class AppLogger {
  AppLogger._();

  static void log(
    String message, {
    LogLevel level = LogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level == LogLevel.debug && kReleaseMode) return;

    final prefix = switch (level) {
      LogLevel.debug => '[D]',
      LogLevel.info => '[I]',
      LogLevel.warn => '[W]',
      LogLevel.error => '[E]',
    };

    // ignore: avoid_print
    debugPrint('$prefix $message');

    if (error != null) {
      // ignore: avoid_print
      debugPrint('$prefix error=$error');
    }
    if (stackTrace != null && !kReleaseMode) {
      // ignore: avoid_print
      debugPrint('$prefix stackTrace=\n$stackTrace');
    }
  }
}
