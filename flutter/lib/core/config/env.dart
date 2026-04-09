import 'package:flutter/foundation.dart';

class Env {
  Env._();

  static const bool isProd = bool.fromEnvironment('dart.vm.product');
  static const bool enableRefreshToken = true;

  /// Optional override, intended for build-time configuration:
  /// `flutter run/build --dart-define=API_BASE_URL=https://...`
  static const String _overrideBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  /// IMPORTANT (web dev):
  /// To make HttpOnly refresh cookies work, frontend and backend must share the SAME host.
  /// We therefore build the API URL using the current page hostname (localhost vs 127.0.0.1).
  static String get baseUrl {
    if (_overrideBaseUrl.trim().isNotEmpty) {
      return _overrideBaseUrl.trim();
    }

    if (isProd) return 'https://api.learnova.app';

    if (kIsWeb) {
      final proto = Uri.base.scheme;
      final host = Uri.base.host;
      if (proto.isNotEmpty && host.isNotEmpty) {
        return '$proto://$host:8000';
      }
    }

    // Non-web development fallback.
    return 'http://localhost:8000';
  }
}
