import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_error_bus.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/network/error_mapper.dart';
import '../../data/auth_providers.dart';
import '../../data/auth_repository.dart';
import 'login_state.dart';

final loginControllerProvider =
    StateNotifierProvider<LoginController, LoginState>(
  (ref) => LoginController(ref),
);

class LoginController extends StateNotifier<LoginState> {
  LoginController(this.ref) : super(const LoginState());

  final Ref ref;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  Future<LoginResult> login(
    String email,
    String password, {
    required bool persist,
  }) async {
    clearError();
    state = state.copyWith(loading: true);

    try {
      await _repo.login(
        email: email.trim(),
        password: password,
        persist: persist,
      );

      state = state.copyWith(loading: false);
      return LoginResult.success;
    } catch (e) {
      final failure = mapApiFailure(e, email: email.trim());

      // Email not verified → store pending email + redirect to verify screen.
      if (failure.isEmailNotVerified) {
        TokenStorage.setPendingVerificationEmail(email.trim());
        state = state.copyWith(loading: false, clearError: true);
        return LoginResult.emailNotVerified;
      }

      // Stale session + auth issue → global handler (logout + login redirect).
      if (TokenStorage.hasToken && failure.isAuthIssue) {
        state = state.copyWith(loading: false, clearError: true);
        AppErrorReporter.report(ref, failure);
        return LoginResult.authError;
      }

      state = state.copyWith(
        loading: false,
        error: failure.message,
      );
      return LoginResult.error;
    }
  }
}

enum LoginResult { success, emailNotVerified, authError, error }
