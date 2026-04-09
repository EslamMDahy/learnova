import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_error_bus.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/network/error_mapper.dart';
import '../../data/auth_providers.dart';
import '../../domain/i_auth_repository.dart';
import 'login_state.dart';

/// Auth controller for the login screen.
/// Uses the Riverpod 2.x [Notifier] API with [AsyncValue]-backed [LoginState].
final loginControllerProvider =
    NotifierProvider<LoginController, LoginState>(LoginController.new);

class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  IAuthRepository get _repo => ref.read(authRepositoryProvider);

  void clearError() {
    if (state.async.hasError) {
      state = state.clearError();
    }
  }

  Future<LoginResult> login(
    String email,
    String password, {
    required bool persist,
  }) async {
    clearError();
    state = state.toLoading();

    try {
      await _repo.login(
        email: email.trim(),
        password: password,
        persist: persist,
      );

      state = state.toSuccess();
      return LoginResult.success;
    } catch (e, st) {
      final failure = mapApiFailure(e, email: email.trim());

      // Email not verified → store pending email + redirect to verify screen.
      if (failure.isEmailNotVerified) {
        TokenStorage.setPendingVerificationEmail(email.trim());
        state = state.clearError();
        return LoginResult.emailNotVerified;
      }

      // Stale session + auth issue → global handler (logout + login redirect).
      if (TokenStorage.hasToken && failure.isAuthIssue) {
        state = state.clearError();
        AppErrorReporter.report(ref, failure);
        return LoginResult.authError;
      }

      state = state.toError(failure, st);
      return LoginResult.error;
    }
  }
}

enum LoginResult { success, emailNotVerified, authError, error }
