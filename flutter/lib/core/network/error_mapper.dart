import 'package:dio/dio.dart';

import '../error/app_failure.dart';
import 'api_exceptions.dart';

AppFailure mapApiFailure(Object e, {String? email}) {
  // 1) ApiClient wraps into DioException.error as ApiException
  if (e is DioException && e.error is ApiException) {
    final ex = e.error as ApiException;
    return _fromStatus(
      statusCode: ex.statusCode,
      message: ex.message,
      debug: ex.toString(),
      code: ex.cleanCode,
      email: email,
    );
  }

  // 2) Direct DioException
  if (e is DioException) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    final serverMsg = _extractServerMessage(data);
    if (serverMsg != null && serverMsg.trim().isNotEmpty) {
      return _fromStatus(
        statusCode: status,
        message: serverMsg.trim(),
        debug: e.toString(),
        email: email,
      );
    }

    switch (e.type) {
      case DioExceptionType.cancel:
        return const AppFailure(
          type: AppFailureType.unknown,
          message: 'Request cancelled.',
        );
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const AppFailure(
          type: AppFailureType.timeout,
          message: 'Connection timeout. Please try again.',
        );
      case DioExceptionType.connectionError:
        return const AppFailure(
          type: AppFailureType.network,
          message: 'No internet connection.',
        );
      case DioExceptionType.badCertificate:
        return const AppFailure(
          type: AppFailureType.unknown,
          message: 'Secure connection failed. Please try again.',
        );
      case DioExceptionType.badResponse:
        break;
      case DioExceptionType.unknown:
        break;
    }

    return _fromStatus(
      statusCode: status,
      message: 'Something went wrong. Please try again.',
      debug: e.toString(),
      email: email,
    );
  }

  // 3) ApiException (non-dio)
  if (e is ApiException) {
    return _fromStatus(
      statusCode: e.statusCode,
      message: e.message,
      debug: e.toString(),
      code: e.cleanCode,
      email: email,
    );
  }

  // 4) fallback
  return AppFailure(
    type: AppFailureType.unknown,
    message: 'Unexpected error. Please try again.',
    debugMessage: e.toString(),
  );
}

String mapApiError(Object e) => mapApiFailure(e).message;

AppFailure _fromStatus({
  required int? statusCode,
  required String message,
  required String debug,
  String? code,
  String? email,
}) {
  final sc = statusCode;

  // Custom codes take priority.
  if (code == 'TOKEN_EXPIRED') {
    return AppFailure(
      type: AppFailureType.unauthorized,
      message: 'Your session expired. Please login again.',
      debugMessage: debug,
      statusCode: sc,
      code: code,
    );
  }

  if (code == 'AUTH_RETRY_FAILED') {
    return AppFailure(
      type: AppFailureType.warning,
      message: message.isNotEmpty
          ? message
          : 'Request could not be completed. Please try again.',
      debugMessage: debug,
      statusCode: sc,
      code: code,
    );
  }

  // Detect email-not-verified: 403 + any of these backend messages/codes.
  if (sc == 403) {
    final lowerMsg = message.toLowerCase();
    final isEmailNotVerified = code == 'EMAIL_NOT_VERIFIED' ||
        lowerMsg.contains('not verified') ||
        lowerMsg.contains('email not verified') ||
        lowerMsg.contains('verify your email');

    if (isEmailNotVerified) {
      return AppFailure(
        type: AppFailureType.emailNotVerified,
        message: message.isNotEmpty
            ? message
            : 'Please verify your email before logging in.',
        debugMessage: debug,
        statusCode: sc,
        code: code ?? 'EMAIL_NOT_VERIFIED',
        extra: email,
      );
    }

    // Generic 403 (access denied, not email-related).
    return AppFailure(
      type: AppFailureType.forbidden,
      message: message.isNotEmpty ? message : 'Access denied.',
      debugMessage: debug,
      statusCode: sc,
      code: code,
    );
  }

  if (sc == null) {
    return AppFailure(
      type: AppFailureType.unknown,
      message: message.isNotEmpty
          ? message
          : 'Something went wrong. Please try again.',
      debugMessage: debug,
      statusCode: sc,
      code: code,
    );
  }

  switch (sc) {
    case 400:
      return AppFailure(
        type: AppFailureType.validation,
        message: message.isNotEmpty
            ? message
            : 'Invalid request. Please check your input.',
        debugMessage: debug,
        statusCode: sc,
        code: code,
      );
    case 401:
      return AppFailure(
        type: AppFailureType.unauthorized,
        message: message.isNotEmpty
            ? message
            : 'Your session expired. Please login again.',
        debugMessage: debug,
        statusCode: sc,
        code: code,
      );
    case 404:
      return AppFailure(
        type: AppFailureType.notFound,
        message: message.isNotEmpty ? message : 'Service not found.',
        debugMessage: debug,
        statusCode: sc,
        code: code,
      );
    case 409:
      return AppFailure(
        type: AppFailureType.validation,
        message: message.isNotEmpty ? message : 'Conflict. Please try again.',
        debugMessage: debug,
        statusCode: sc,
        code: code,
      );
    case 422:
      return AppFailure(
        type: AppFailureType.validation,
        message: message.isNotEmpty
            ? message
            : 'Some fields are invalid. Please check your input.',
        debugMessage: debug,
        statusCode: sc,
        code: code,
      );
    case 429:
      return AppFailure(
        type: AppFailureType.server,
        message: message.isNotEmpty
            ? message
            : 'Too many requests. Please try again later.',
        debugMessage: debug,
        statusCode: sc,
        code: code,
      );
    case 500:
    case 502:
    case 503:
    case 504:
      return AppFailure(
        type: AppFailureType.server,
        message: message.isNotEmpty
            ? message
            : 'Server error. Please try again later.',
        debugMessage: debug,
        statusCode: sc,
        code: code,
      );
    default:
      return AppFailure(
        type: AppFailureType.unknown,
        message: message.isNotEmpty
            ? message
            : 'Something went wrong. Please try again.',
        debugMessage: debug,
        statusCode: sc,
        code: code,
      );
  }
}

String? _extractServerMessage(dynamic data) {
  if (data == null) return null;
  if (data is String && data.trim().isNotEmpty) return data.trim();
  if (data is! Map) return null;

  final detail = data['detail'];

  if (detail is String && detail.trim().isNotEmpty) return detail.trim();

  if (detail is List) {
    final msgs = <String>[];
    for (final item in detail) {
      if (item is Map) {
        final msg = item['msg']?.toString().trim();
        final loc = item['loc'];
        String? field;
        if (loc is List && loc.isNotEmpty) field = loc.last?.toString();
        if (msg != null && msg.isNotEmpty) {
          msgs.add((field != null && field.isNotEmpty) ? '$field: $msg' : msg);
        }
      } else if (item != null) {
        final s = item.toString().trim();
        if (s.isNotEmpty) msgs.add(s);
      }
    }
    if (msgs.isNotEmpty) return msgs.join('\n');
  }

  final message = data['message']?.toString().trim();
  if (message != null && message.isNotEmpty) return message;

  return null;
}
