import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import 'dto/login_request.dart';
import 'dto/login_response.dart';
import 'dto/signup_request.dart';

class AuthApi {
  final ApiClient _client;
  AuthApi(this._client);

  // ─── Auth ─────────────────────────────────────────────────────────────────

  Future<LoginResponse> login(LoginRequest request) async {
    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.login,
      data: request.toJson(),
    );

    final payload = (res.data ?? <String, dynamic>{}).cast<String, dynamic>();
    return LoginResponse.fromJson(payload);
  }

  /// POST /auth/register
  ///
  /// Accepts a typed [SignupRequest] DTO so field names are validated at
  /// compile time — no more silent bugs from raw Map key typos.
  Future<void> signup(SignupRequest request) async {
    await _client.post(
      Endpoints.signup,
      data: request.toJson(),
    );
  }

  Future<String> verifyEmail(String token) async {
    final res = await _client.get<Map<String, dynamic>>(
      Endpoints.verifyEmail,
      queryParameters: {'token': token.trim()},
    );
    return _readMessage(res.data);
  }

  Future<String> resendVerificationEmail(String email) async {
    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.resendVerification,
      data: {'email': email.trim()},
    );
    return _readMessage(res.data);
  }

  Future<bool> checkEmailVerified(String email) async {
    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.checkEmailVerified,
      data: {'email': email.trim()},
    );

    final payload = (res.data ?? <String, dynamic>{}).cast<String, dynamic>();
    final root = (payload['data'] is Map<String, dynamic>)
        ? payload['data'] as Map<String, dynamic>
        : payload;

    return root['is_verified'] == true;
  }

  // ─── Password ─────────────────────────────────────────────────────────────

  Future<String> forgotPassword(String email) async {
    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.forgotPassword,
      data: {'email': email.trim()},
    );
    return _readMessage(res.data);
  }

  Future<String> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.resetPassword,
      data: {
        'token': token.trim(),
        'new_password': newPassword,
      },
    );
    return _readMessage(res.data);
  }

  // ─── Session ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> me({CancelToken? cancelToken}) async {
    final res = await _client.get<Map<String, dynamic>>(
      Endpoints.me,
      cancelToken: cancelToken,
    );
    return (res.data ?? <String, dynamic>{}).cast<String, dynamic>();
  }

  Future<String> refresh() => _client.refreshAccessToken();

  Future<void> logout() async {
    await _client.post(Endpoints.logout);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _readMessage(Map<String, dynamic>? data) {
    final v = data?['message'] ?? data?['msg'];
    return v?.toString() ?? '';
  }
}
