import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_exceptions.dart';
import 'refresh_client.dart';

class _DioRefreshClient implements RefreshClient {
  _DioRefreshClient(this._dio);

  final Dio _dio;

  @override
  Future<String> refresh({required String url}) async {
    try {
      final res = await _dio.post<dynamic>(
        url,
        data: const {},
        options: Options(
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final data = res.data;
      Map<String, dynamic> decoded;
      if (data is Map) {
        decoded = data.cast<String, dynamic>();
      } else if (data is String) {
        decoded = (jsonDecode(data) as Map).cast<String, dynamic>();
      } else {
        decoded = <String, dynamic>{};
      }

      final root = (decoded['data'] is Map)
          ? (decoded['data'] as Map).cast<String, dynamic>()
          : decoded;

      final token =
          (root['access_token'] ?? root['token'] ?? root['accessToken'])
              ?.toString();

      if (token == null || token.trim().isEmpty) {
        throw ApiException('Invalid refresh response.', code: 'REFRESH_INVALID');
      }
      return token.trim();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      throw ApiException(
        'Refresh failed.',
        statusCode: status,
        code: 'REFRESH_FAILED',
      );
    }
  }
}

/// Used by conditional import factory.
RefreshClient createRefreshClientImpl() => _DioRefreshClient(Dio());
