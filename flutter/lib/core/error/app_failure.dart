enum AppFailureType {
  network,
  timeout,
  unauthorized,
  forbidden,
  emailNotVerified, // 403 specifically for unverified email during login
  notFound,
  validation,
  server,
  unknown, warning,
}

class AppFailure {
  final AppFailureType type;

  /// User-friendly message (safe to show).
  final String message;

  /// Optional debug info (logs only; never show in production UI).
  final String? debugMessage;

  final int? statusCode;

  /// Optional machine-readable code (e.g. TOKEN_EXPIRED, EMAIL_NOT_VERIFIED)
  final String? code;

  /// Optional extra payload (e.g. email for EMAIL_NOT_VERIFIED case).
  final String? extra;

  const AppFailure({
    required this.type,
    required this.message,
    this.debugMessage,
    this.statusCode,
    this.code,
    this.extra,
  });

  /// True only for 401 token expiry — triggers logout + login redirect.
  bool get isAuthIssue =>
      type == AppFailureType.unauthorized && code == 'TOKEN_EXPIRED';

  /// True for the specific "email not verified" 403 case.
  bool get isEmailNotVerified => type == AppFailureType.emailNotVerified;

  /// True for server/network errors that should show the global error page.
  bool get isServerOrNetworkError =>
      type == AppFailureType.server ||
      type == AppFailureType.network ||
      type == AppFailureType.timeout;

  bool get isNetworkLike =>
      type == AppFailureType.network || type == AppFailureType.timeout;

  AppFailure copyWith({
    AppFailureType? type,
    String? message,
    String? debugMessage,
    int? statusCode,
    String? code,
    String? extra,
  }) {
    return AppFailure(
      type: type ?? this.type,
      message: message ?? this.message,
      debugMessage: debugMessage ?? this.debugMessage,
      statusCode: statusCode ?? this.statusCode,
      code: code ?? this.code,
      extra: extra ?? this.extra,
    );
  }
}
