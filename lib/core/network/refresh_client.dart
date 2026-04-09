import 'refresh_client_stub.dart'
    if (dart.library.html) 'refresh_client_web.dart';

/// Performs a refresh-token call and returns a new access token.
///
/// Web uses XHR to guarantee `withCredentials=true` so HttpOnly cookies are sent.
/// Other platforms use Dio.
abstract class RefreshClient {
  Future<String> refresh({required String url});
}

/// Factory that chooses the correct implementation per platform.
RefreshClient createRefreshClient() => createRefreshClientImpl();
