import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/error_mapper.dart';
import '../../data/auth_providers.dart';
import '../../domain/i_auth_repository.dart';
import 'forgot_password_state.dart';

/// Auth controller for the forgot-password screen.
/// Uses the Riverpod 2.x [Notifier] API.
final forgotPasswordControllerProvider =
    NotifierProvider<ForgotPasswordController, ForgotPasswordState>(
        ForgotPasswordController.new,);

class ForgotPasswordController extends Notifier<ForgotPasswordState> {
  @override
  ForgotPasswordState build() => const ForgotPasswordState();

  IAuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Resets the state back to the initial empty form.
  void reset() {
    state = const ForgotPasswordState();
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  /// Sends a password-reset link to [email].
  /// Aliased as [sendResetLink] for widget call-sites.
  Future<bool> sendResetLink(String email) => forgotPassword(email);

  /// Resends the reset link using the last known email.
  Future<bool> resend() {
    final email = state.lastEmail ?? '';
    if (email.isEmpty) return Future.value(false);
    return forgotPassword(email);
  }

  Future<bool> forgotPassword(String email) async {
    clearError();
    state = state.copyWith(loading: true, lastEmail: email);

    try {
      final message = await _repo.forgotPassword(email.trim());
      state = state.copyWith(
        loading: false,
        sent: true,
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
