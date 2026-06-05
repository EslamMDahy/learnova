import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'api_exceptions.dart';
import 'refresh_client.dart';

class _XhrRefreshClient implements RefreshClient {
  @override
  Future<String> refresh({required String url}) {
    final completer = Completer<String>();

    final xhr = html.HttpRequest()
      ..open('POST', url)
      ..setRequestHeader('Content-Type', 'application/json')
      ..setRequestHeader('Accept', 'application/json')
      ..setRequestHeader('ngrok-skip-browser-warning', 'true')
      ..withCredentials = true; // sends HttpOnly cookie cross-origin

    xhr.onLoad.listen((_) {
      try {
        final status = xhr.status ?? 0;
        if (status < 200 || status >= 400) {
          completer.completeError(
            ApiException(
              'Refresh failed: HTTP $status',
              statusCode: status,
              code: 'REFRESH_FAILED',
            ),
          );
          return;
        }

        final body = xhr.responseText ?? '';
        final decoded = _parseJsonBody(body);
        final root = (decoded['data'] is Map)
            ? (decoded['data'] as Map).cast<String, dynamic>()
            : decoded;

        final token =
            (root['access_token'] ?? root['token'] ?? root['accessToken'])
                ?.toString();

        if (token == null || token.trim().isEmpty) {
          completer.completeError(
            ApiException(
              'Invalid refresh response.',
              statusCode: status,
              code: 'REFRESH_INVALID',
            ),
          );
          return;
        }

        completer.complete(token.trim());
      } catch (e) {
        completer.completeError(e);
      }
    });

    xhr.onError.listen((_) {
      completer.completeError(
        ApiException('Network error during token refresh.', code: 'REFRESH_NET'),
      );
    });

    xhr.send(); // no body needed — cookie is sent automatically
    return completer.future;
  }

  Map<String, dynamic> _parseJsonBody(String body) {
    try {
      return (jsonDecode(body) as Map).cast<String, dynamic>();
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}

/// Used by conditional import factory.
RefreshClient createRefreshClientImpl() => _XhrRefreshClient();
