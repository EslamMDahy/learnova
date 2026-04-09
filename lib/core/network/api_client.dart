import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/env.dart';
import '../log/app_logger.dart';
import '../storage/token_storage.dart';
import '../ui/global_loading_bus.dart';
import 'api_exceptions.dart';
import 'dio_adapter_config.dart';
import 'endpoints.dart';
import 'refresh_client.dart';

class ApiClient {
  ApiClient({Dio? dio, RefreshClient? refreshClient})
      : _dio = dio ?? Dio(),
        _refreshClient = refreshClient ?? createRefreshClient() {
    _dio.options = BaseOptions(
      baseUrl: Env.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
    configureDioAdapter(_dio);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          GlobalLoadingBus.beginIfNeeded(options);

          final token = TokenStorage.token;
          if (token != null && token.trim().isNotEmpty) {
            options.headers['Authorization'] = 'Bearer ${token.trim()}';
          }

          handler.next(options);
        },
        onResponse: (response, handler) {
          GlobalLoadingBus.endIfNeeded(response.requestOptions);
          handler.next(response);
        },
        onError: (DioException e, handler) async {
          // Optional: retry GET once on transient network errors
          if (_shouldRetryGetOnce(e)) {
            try {
              final res = await _retryOnce(e.requestOptions);
              return handler.resolve(res);
            } catch (_) {
              // continue to normal error handling
            }
          }

          final status = e.response?.statusCode;

          // Conditions to attempt a token refresh:
          // – refresh feature enabled in env
          // – 401 response
          // – we have a token (otherwise the user is already logged out)
          // – not an auth endpoint (avoid refresh-loops)
          // – not already retried for this request
          final shouldTryRefresh =
              Env.enableRefreshToken &&
              status == 401 &&
              TokenStorage.hasToken &&
              !_isAuthPath(e.requestOptions.path) &&
              !_hasAuthRetried(e.requestOptions);

          if (shouldTryRefresh) {
            try {
              final newAccess = await _refreshAccessToken();

              TokenStorage.saveSession(
                accessToken: newAccess,
                persist: TokenStorage.isPersisted,
              );

              // Reschedule proactive refresh for the new token lifetime.
              scheduleProactiveRefresh(newAccess);

              final retryResponse =
                  await _retryWithNewToken(e.requestOptions, newAccess);

              return handler.resolve(retryResponse);
            } catch (_) {
              // Refresh failed → clear session, propagate 401.
              TokenStorage.clear();
              GlobalLoadingBus.endIfNeeded(e.requestOptions);

              return handler.reject(
                DioException(
                  requestOptions: e.requestOptions,
                  response: e.response,
                  type: e.type,
                  error: ApiException(
                    'Your session expired. Please login again.',
                    statusCode: status,
                    code: 'TOKEN_EXPIRED',
                  ),
                  message: e.message,
                ),
              );
            }
          }

          // Normal error mapping
          GlobalLoadingBus.endIfNeeded(e.requestOptions);

          final msg = _pickErrorMessage(e);

          return handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              response: e.response,
              type: e.type,
              error: ApiException(
                msg,
                statusCode: status,
                code: _mapCode(status, e.response?.data),
              ),
              message: msg,
            ),
          );
        },
      ),
    );
  }

  final Dio _dio;
  final RefreshClient _refreshClient;

  // ── Proactive refresh timer ─────────────────────────────────────────────────
  //
  // Fires 2 minutes before the JWT expires so the user never hits a 401 mid-
  // session. After every successful refresh (reactive or proactive) we cancel
  // the old timer and schedule a new one for the replacement token.
  //
  // Guard: if the token is already expired (or within 30 s of expiry) when
  // scheduleProactiveRefresh is called we delay 30 s instead of firing
  // immediately.  This prevents a burst of refresh calls on page load when
  // the stored token is very close to expiry.

  Timer? _proactiveTimer;

  /// Call once after login / bootstrap with the raw JWT so the timer knows
  /// when to schedule the next silent refresh.
  void scheduleProactiveRefresh(String accessToken) {
    _proactiveTimer?.cancel();
    _proactiveTimer = null;

    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) return;

      // Base64url → base64 padding
      String pad(String s) {
        final rem = s.length % 4;
        return rem == 0 ? s : s + '=' * (4 - rem);
      }

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(pad(parts[1]))),
      ) as Map<String, dynamic>;

      final exp = payload['exp'];
      if (exp == null) return;

      final expiry = DateTime.fromMillisecondsSinceEpoch(
        (exp as num).toInt() * 1000,
        isUtc: true,
      );
      final now = DateTime.now().toUtc();

      // Token already expired — don't schedule; let the reactive interceptor
      // handle the next 401.
      if (expiry.isBefore(now)) return;

      // Fire 2 minutes before expiry.
      // If we're already within 2 min (but not expired), wait at least 30 s
      // to avoid immediately hammering the refresh endpoint on page load.
      final fireAt = expiry.subtract(const Duration(minutes: 2));
      final delay = fireAt.isAfter(now)
          ? fireAt.difference(now)
          : const Duration(seconds: 30);

      _proactiveTimer = Timer(delay, _proactiveRefresh);
    } catch (_) {
      // Unparseable token → rely on the reactive interceptor.
    }
  }

  void cancelProactiveRefresh() {
    _proactiveTimer?.cancel();
    _proactiveTimer = null;
  }

  void dispose() {
    cancelProactiveRefresh();
  }

  Future<void> _proactiveRefresh() async {
    if (!TokenStorage.hasToken) return;

    try {
      final newToken = await _refreshAccessToken();

      TokenStorage.saveSession(
        accessToken: newToken,
        persist: TokenStorage.isPersisted,
      );

      // Reschedule for the new token's lifetime.
      scheduleProactiveRefresh(newToken);
    } catch (_) {
      // Proactive refresh failed (e.g. no network, cookie expired).
      // Don't log the user out here — the reactive 401 interceptor will
      // handle the next failed request and show the session-expired message.
    }
  }

  // ── Public HTTP methods ─────────────────────────────────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

  // ── Retry helpers ───────────────────────────────────────────────────────────

  bool _shouldRetryGetOnce(DioException e) {
    if (e.requestOptions.method.toUpperCase() != 'GET') return false;
    if (e.requestOptions.extra['__getRetried'] == true) return false;

    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  Future<Response<dynamic>> _retryOnce(RequestOptions o) async {
    final opts = Options(
      method: o.method,
      headers: o.headers,
      responseType: o.responseType,
      contentType: o.contentType,
      followRedirects: o.followRedirects,
      validateStatus: o.validateStatus,
      receiveDataWhenStatusError: o.receiveDataWhenStatusError,
      extra: {
        ...o.extra,
        '__getRetried': true,
      },
    );

    return _dio.request<dynamic>(
      o.path,
      data: o.data,
      queryParameters: o.queryParameters,
      options: opts,
      cancelToken: o.cancelToken,
      onReceiveProgress: o.onReceiveProgress,
      onSendProgress: o.onSendProgress,
    );
  }

  // ── Refresh token (single-flight) ───────────────────────────────────────────
  //
  // A Completer ensures that if multiple requests get a 401 simultaneously,
  // only ONE refresh call is made to the backend.  All waiting requests share
  // the same future and retry with the single new token.

  Completer<String>? _refreshCompleter;

  Future<String> _refreshAccessToken() async {
    if (_refreshCompleter != null) return _refreshCompleter!.future;

    final c = Completer<String>();
    _refreshCompleter = c;

    try {
      final newToken = await _callRefreshEndpoint();
      c.complete(newToken);
      return newToken;
    } catch (e) {
      c.completeError(e);
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<String> _callRefreshEndpoint() async {
    final url = '${Env.baseUrl}${Endpoints.refresh}';
    try {
      return await _refreshClient.refresh(url: url);
    } catch (e, st) {
      AppLogger.log(
        'Refresh token call failed.',
        level: LogLevel.warn,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  bool _hasAuthRetried(RequestOptions o) => o.extra['__authRetried'] == true;

  Future<Response<dynamic>> _retryWithNewToken(
    RequestOptions o,
    String accessToken,
  ) async {
    final opts = Options(
      method: o.method,
      headers: {
        ...o.headers,
        'Authorization': 'Bearer ${accessToken.trim()}',
      },
      responseType: o.responseType,
      contentType: o.contentType,
      followRedirects: o.followRedirects,
      validateStatus: o.validateStatus,
      receiveDataWhenStatusError: o.receiveDataWhenStatusError,
      extra: {
        ...o.extra,
        '__authRetried': true,
      },
    );

    return _dio.request<dynamic>(
      o.path,
      data: o.data,
      queryParameters: o.queryParameters,
      options: opts,
      cancelToken: o.cancelToken,
      onReceiveProgress: o.onReceiveProgress,
      onSendProgress: o.onSendProgress,
    );
  }

  bool _isAuthPath(String path) {
    return path.contains(Endpoints.login) ||
        path.contains(Endpoints.signup) ||
        path.contains(Endpoints.refresh);
  }

  String _pickErrorMessage(DioException e) {
    final data = e.response?.data;

    try {
      if (data is Map) {
        final m = data.cast<String, dynamic>();
        final direct = (m['message'] ?? m['error'])?.toString();
        if (direct != null && direct.trim().isNotEmpty) return direct.trim();

        final inner = m['data'];
        if (inner is Map) {
          final innerMsg = (inner['message'] ?? inner['error'])?.toString();
          if (innerMsg != null && innerMsg.trim().isNotEmpty) {
            return innerMsg.trim();
          }
        }

        final errs = m['errors'];
        if (errs is List && errs.isNotEmpty) {
          final first = errs.first;
          if (first is Map) {
            final msg = first['message']?.toString();
            if (msg != null && msg.trim().isNotEmpty) return msg.trim();
          }
        }
      }
    } catch (_) {}

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Request timed out. Please try again.';
    }

    if (e.type == DioExceptionType.connectionError) {
      return 'Network error. Check your connection and try again.';
    }

    return e.message?.trim().isNotEmpty ?? false
        ? e.message!.trim()
        : 'Something went wrong. Please try again.';
  }

  String _mapCode(int? status, dynamic data) {
    if (status == null) return 'UNKNOWN';
    if (status == 400) return 'BAD_REQUEST';
    if (status == 401) return 'UNAUTHORIZED';
    if (status == 403) return 'FORBIDDEN';
    if (status == 404) return 'NOT_FOUND';
    if (status >= 500) return 'SERVER_ERROR';

    try {
      if (data is Map) {
        final m = data.cast<String, dynamic>();
        final code = m['code']?.toString();
        if (code != null && code.trim().isNotEmpty) return code.trim();
      }
    } catch (_) {}
    return 'HTTP_$status';
  }
}
