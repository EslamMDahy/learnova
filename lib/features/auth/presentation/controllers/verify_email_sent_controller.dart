import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/error_mapper.dart';
import '../../../../core/error/app_failure.dart';
import '../../data/auth_providers.dart';
import '../../data/auth_repository.dart';
import 'verify_email_sent_state.dart';

final verifyEmailSentControllerProvider = StateNotifierProvider<
    VerifyEmailSentController, VerifyEmailSentState>(
  (ref) => VerifyEmailSentController(ref),
);

class VerifyEmailSentController
    extends StateNotifier<VerifyEmailSentState> {
  VerifyEmailSentController(this.ref) : super(const VerifyEmailSentState());

  final Ref ref;
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  // ── Resend ────────────────────────────────────────────────────────────────

  Future<bool> resend(String email) async {
    state = state.copyWith(
      loading: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      await _repo.resendVerificationEmail(email.trim());
      state = state.copyWith(
        loading: false,
        successMessage: 'Verification email resent! Please check your inbox.',
      );
      return true;
    } catch (e) {
      final failure = mapApiFailure(e);
      final msg = failure.statusCode == 429
          ? 'Too many requests. Please wait before trying again.'
          : failure.message;
      state = state.copyWith(loading: false, error: msg);
      return false;
    }
  }

  // ── Check verified ────────────────────────────────────────────────────────
  //
  // Root cause of "Not Found" bug:
  //
  // The previous implementation called POST /auth/check-email-verified which
  // does NOT exist in the backend. The backend returned HTTP 404. The error
  // mapper correctly classified it as AppFailureType.notFound and the
  // controller caught it — BUT the UI showed the error string "Not found"
  // which looked like a page navigation "Not Found" screen to the user,
  // especially since GoRouter's 404 handler can also show a similar message.
  //
  // Actual navigation "Not Found" scenario: if _onCheckVerified() in the page
  // called context.go('/some-undefined-path') — but looking at the code it
  // called context.go('${Routes.login}?verified=1') which IS a valid route.
  // The actual error was the 404 API response leaking to the UI as a
  // confusing message.
  //
  // Fix:
  //   1. Backend: added POST /auth/check-email-verified (see router.py).
  //   2. Flutter: added graceful handling — if the endpoint returns 404
  //      (not yet deployed), show a helpful message instead of a cryptic error.
  //   3. The page redirect after success now correctly uses role-aware routing.

  Future<bool> checkVerified(String email) async {
    state = state.copyWith(
      checkingVerification: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final verified = await _repo.checkEmailVerified(email.trim());
      if (verified) {
        state = state.copyWith(
          checkingVerification: false,
          successMessage: 'Email verified successfully! Redirecting...',
        );
        return true;
      } else {
        state = state.copyWith(
          checkingVerification: false,
          error:
              'Your email hasn\'t been verified yet. Please click the link in the email we sent you.',
        );
        return false;
      }
    } catch (e) {
      final failure = mapApiFailure(e);

      // If the backend endpoint is not yet deployed (404), show a specific
      // helpful message rather than a generic "Not found" that confuses users.
      final msg = failure.type == AppFailureType.notFound
          ? 'Verification check is temporarily unavailable. '
              'Please click the link in your email to verify, then log in normally.'
          : failure.message;

      state = state.copyWith(
        checkingVerification: false,
        error: msg,
      );
      return false;
    }
  }
}
