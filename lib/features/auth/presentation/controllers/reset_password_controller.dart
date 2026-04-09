import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_error_bus.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/network/error_mapper.dart';
import '../../data/auth_providers.dart';
import '../../data/auth_repository.dart';
import 'reset_password_state.dart';

final resetPasswordControllerProvider =
    StateNotifierProvider<ResetPasswordController, ResetPasswordState>(
  (ref) => ResetPasswordController(ref),
);

class ResetPasswordController extends StateNotifier<ResetPasswordState> {
  ResetPasswordController(this.ref) : super(const ResetPasswordState());

  final Ref ref;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  void reset() {
    
    clearError();
    state = const ResetPasswordState();
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith();
    }
  }

  Future<bool> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final t = token.trim();

    
    clearError();

    state = state.copyWith(
      loading: true,
      success: false,
    );

    if (t.isEmpty) {
      state = state.copyWith(
        loading: false,
        success: false,
        error: 'Invalid reset link. Please request a new one.',
      );
      return false;
    }

    try {
      final msg = await _repo.resetPassword(
        token: t,
        newPassword: newPassword,
      );

      state = state.copyWith(
        loading: false,
        success: true,
        message: msg.trim().isNotEmpty
            ? msg.trim()
            : 'Password reset successfully. You can now log in.',
      );

      return true;
    } catch (err) {
      final failure = mapApiFailure(err);

      if (TokenStorage.hasToken && failure.isAuthIssue) {
        state = state.copyWith(loading: false);
        AppErrorReporter.report(ref, failure);
        return false;
      }

      state = state.copyWith(
        loading: false,
        error: failure.message,
      );
      return false;
    }
  }
}
