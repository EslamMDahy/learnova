import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/error_mapper.dart';
import '../../data/auth_providers.dart';
import '../../domain/i_auth_repository.dart';
import 'forgot_password_state.dart';

/// Auth controller for the forgot-password screen.
/// Uses the Riverpod 2.x [Notifier] API.
final forgotPasswordControllerProvider =
    NotifierProvider<ForgotPasswordController, ForgotPasswordState>(
        ForgotPasswordController.new);

class ForgotPasswordController extends Notifier<ForgotPasswordState> {
  @override
  ForgotPasswordState build() => const ForgotPasswordState();

  IAuthRepository get _repo => ref.read(authRepositoryProvider);

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  Future<bool> forgotPassword(String email) async {
    clearError();
    state = state.copyWith(loading: true);

    try {
      final message = await _repo.forgotPassword(email.trim());
      state = state.copyWith(loading: false, successMessage: message);
      return true;
    } catch (e) {
      final failure = mapApiFailure(e);
      state = state.copyWith(loading: false, error: failure.message);
      return false;
    }
  }
}
