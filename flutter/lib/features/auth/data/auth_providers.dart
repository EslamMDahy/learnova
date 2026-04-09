import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/i_token_refresh_scheduler.dart';
import '../domain/i_auth_repository.dart';
import 'auth_api.dart';
import 'auth_repository.dart';

/// Single shared ApiClient instance.
/// Disposed automatically when the provider is destroyed.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.dispose);
  return client;
});

/// Exposes ApiClient as ITokenRefreshScheduler so the repository
/// never has to import the full ApiClient class.
final tokenRefreshSchedulerProvider = Provider<ITokenRefreshScheduler>((ref) {
  return ref.watch(apiClientProvider);
});

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(apiClientProvider));
});

/// Exposes the concrete AuthRepository behind the IAuthRepository interface.
/// Controllers and other consumers depend only on [IAuthRepository],
/// making them trivially testable with a mock.
final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  return AuthRepository(
    ref.watch(authApiProvider),
    ref.watch(tokenRefreshSchedulerProvider),
  );
});
