import 'package:flutter/material.dart';
import 'app_failure.dart';

class AppFailurePresenter {
  const AppFailurePresenter._();

  static String title(AppFailure f) {
    switch (f.type) {
      case AppFailureType.network:
        return 'No internet';
      case AppFailureType.timeout:
        return 'Connection timeout';
      case AppFailureType.unauthorized:
        return 'Session expired';
      case AppFailureType.forbidden:
        return 'Access denied';
      case AppFailureType.emailNotVerified:
        return 'Email not verified';
      case AppFailureType.validation:
        return 'Invalid input';
      case AppFailureType.notFound:
        return 'Not found';
      case AppFailureType.server:
        return 'Server error';
      case AppFailureType.warning:
        return 'Warning';
      case AppFailureType.unknown:
        return 'Something went wrong';
    }
  }

  static IconData icon(AppFailure f) {
    switch (f.type) {
      case AppFailureType.network:
        return Icons.wifi_off_rounded;
      case AppFailureType.timeout:
        return Icons.timer_outlined;
      case AppFailureType.unauthorized:
        return Icons.lock_outline_rounded;
      case AppFailureType.forbidden:
        return Icons.block_rounded;
      case AppFailureType.emailNotVerified:
        return Icons.mark_email_unread_outlined;
      case AppFailureType.validation:
        return Icons.error_outline;
      case AppFailureType.notFound:
        return Icons.search_off_rounded;
      case AppFailureType.server:
        return Icons.cloud_off_rounded;
      case AppFailureType.warning:
        return Icons.warning_amber_rounded;
      case AppFailureType.unknown:
        return Icons.warning_amber_rounded;
    }
  }

  static String? primaryActionLabel(AppFailure f) {
    if (f.type == AppFailureType.unauthorized) return 'Login';
    if (f.type == AppFailureType.emailNotVerified) return 'Verify Email';
    if (f.isNetworkLike || f.type == AppFailureType.server) return 'Retry';
    return null;
  }

  static String? secondaryActionLabel(AppFailure f) {
    if (f.type == AppFailureType.unauthorized) return 'Dismiss';
    return null;
  }
}
