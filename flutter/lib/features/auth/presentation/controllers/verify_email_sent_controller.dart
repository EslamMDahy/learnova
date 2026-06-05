import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/error_mapper.dart';
import '../../data/auth_providers.dart';
import '../../domain/i_auth_repository.dart';
import 'verify_email_sent_state.dart';

/// Auth controller for the verify-email-sent screen.
/// Uses the Riverpod 2.x [Notifier] API.
final verifyEmailSentControllerProvider =
    NotifierProvider<VerifyEmailSentController, VerifyEmailSentState>(
        VerifyEmailSentController.new,);

class VerifyEmailSentController extends Notifier<VerifyEmailSentState> {
  @override
  VerifyEmailSentState build() => const VerifyEmailSentState();

  IAuthRepository get _repo => ref.read(authRepositoryProvider);

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  /// Short alias used by [VerifyEmailSentPage].
  Future<bool> resend(String email) => resendVerificationEmail(email);

  /// Short alias used by [VerifyEmailSentPage].
  Future<bool> checkVerified(String email) => checkEmailVerified(email);

  Future<bool> resendVerificationEmail(String email) async {
    clearError();
    state = state.copyWith(loading: true);

    try {
      final message = await _repo.resendVerificationEmail(email.trim());
      state = state.copyWith(
        loading: false,
        successMessage: message,
        resendCount: state.resendCount + 1,
      );
      return true;
    } catch (e) {
      final failure = mapApiFailure(e);
      state = state.copyWith(loading: false, error: failure.message);
      return false;
    }
  }

  Future<bool> checkEmailVerified(String email) async {
    state = state.copyWith(checkingVerification: true, clearError: true);

    try {
      final verified = await _repo.checkEmailVerified(email.trim());
      state = state.copyWith(checkingVerification: false);
      return verified;
    } catch (e) {
      final failure = mapApiFailure(e);
      state = state.copyWith(
          checkingVerification: false, error: failure.message,);
      return false;
    }
  }
}
