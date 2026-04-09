/// App-level exception used across the data layer.
///
/// We wrap Dio errors into this so UI & controllers can behave consistently.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// Optional app-level code (useful for UI decisions)
  /// e.g. TOKEN_EXPIRED, VALIDATION_ERROR, SERVER_ERROR
  final String? code;

  ApiException(
    String message, {
    this.statusCode,
    this.code,
  }) : message = (message.trim().isEmpty)
            ? 'Something went wrong. Please try again.'
            : message.trim();

  String? get cleanCode {
    final c = code?.trim();
    return (c == null || c.isEmpty) ? null : c;
  }

  int? get statusFamily => (statusCode == null) ? null : (statusCode! ~/ 100);

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidation => statusCode == 422;

  bool get isClientError => statusFamily == 4;
  bool get isServerError => statusFamily == 5;

  ApiException copyWith({
    String? message,
    int? statusCode,
    String? code,
  }) {
    return ApiException(
      message ?? this.message,
      statusCode: statusCode ?? this.statusCode,
      code: code ?? this.code,
    );
  }

  @override
  String toString() {
    final sc = statusCode == null ? '' : 'statusCode: $statusCode, ';
    final c = cleanCode == null ? '' : 'code: ${cleanCode!}, ';
    return 'ApiException($c${sc}message: $message)';
  }
}
