/// Abstract contract for the auth repository.
/// Controllers depend on this interface, not the concrete implementation.
/// This allows swapping implementations (e.g. mock for tests) without changing
/// any controller or provider code.
abstract class IAuthRepository {
  /// Login with email and password.
  /// [persist] = true saves the session across app restarts (remember me).
  Future<void> login({
    required String email,
    required String password,
    required bool persist,
  });

  /// Register a new user account.
  Future<void> signup({
    required String fullName,
    required String email,
    required String password,
    required String systemRole,
  });

  // ── Email verification ────────────────────────────────────────────────────

  Future<String> verifyEmail(String token);
  Future<String> resendVerificationEmail(String email);

  /// Returns true if the backend confirms the email is verified.
  Future<bool> checkEmailVerified(String email);

  // ── Password ──────────────────────────────────────────────────────────────

  Future<String> forgotPassword(String email);

  Future<String> resetPassword({
    required String token,
    required String newPassword,
  });

  // ── Session ───────────────────────────────────────────────────────────────

  Future<void> logout();
}
