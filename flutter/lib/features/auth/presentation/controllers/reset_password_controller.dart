import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/error_mapper.dart';
import '../../data/auth_providers.dart';
import '../../domain/i_auth_repository.dart';
import 'reset_password_state.dart';

/// Auth controller for the reset-password screen.
/// Uses the Riverpod 2.x [Notifier] API.
final resetPasswordControllerProvider =
    NotifierProvider<ResetPasswordController, ResetPasswordState>(
        ResetPasswordController.new,);

class ResetPasswordController extends Notifier<ResetPasswordState> {
  @override
  ResetPasswordState build() => const ResetPasswordState();

  IAuthRepository get _repo => ref.read(authRepositoryProvider);

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  Future<bool> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    clearError();
    state = state.copyWith(loading: true);

    try {
      final message = await _repo.resetPassword(
        token: token,
        newPassword: newPassword,
      );
      state = state.copyWith(
        loading: false,
        success: true,
        successMessage: message,
      );
      return true;
    } catch (e) {
      final failure = mapApiFailure(e);
      state = state.copyWith(loading: false, error: failure.message);
      return false;
    }
  }
}
