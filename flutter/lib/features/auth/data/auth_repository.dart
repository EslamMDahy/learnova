import '../../../core/network/i_token_refresh_scheduler.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/storage/user_storage.dart';
import 'auth_api.dart';
import 'dto/login_request.dart';
import 'dto/signup_request.dart';
import '../domain/i_auth_repository.dart';

class AuthRepository implements IAuthRepository {
  final AuthApi _api;

  /// Narrow interface — the repository only needs to schedule/cancel the
  /// proactive token refresh. It no longer depends on the full [ApiClient],
  /// which keeps this class independently testable.
  final ITokenRefreshScheduler _tokenScheduler;

  AuthRepository(this._api, this._tokenScheduler);

  // ─── Login ────────────────────────────────────────────────────────────────

  @override
  Future<void> login({
    required String email,
    required String password,
    required bool persist,
  }) async {
    final res = await _api.login(
      LoginRequest(
        email: email.trim(),
        password: password,
        rememberMe: persist,
      ),
    );

    final userId = res.user?.id;
    if (userId == null || userId.trim().isEmpty) {
      throw Exception('Missing user in login response');
    }

    final meToStore = <String, dynamic>{
      'user': res.user!.toJson(),
      'organizations': res.organizations
          .map((o) => {
                'id': _toIntOrString(o.id),
                'name': o.name,
                'description': o.description,
                'logo_url': o.logoUrl,
                'invite_code': o.inviteCode,
                'subscription_status': o.subscriptionStatus,
              },)
          .toList(),
    };

    if (res.organizations.isNotEmpty) {
      meToStore['selected_organization_id'] =
          _toIntOrString(res.organizations.first.id);
    }

    UserStorage.saveMe(meToStore, persist: persist);
    TokenStorage.saveSession(accessToken: res.accessToken, persist: persist);

    // Start proactive refresh timer — fires 2 min before the token expires
    // so the user is never interrupted by a 401 during active use.
    _tokenScheduler.scheduleProactiveRefresh(res.accessToken);
  }

  dynamic _toIntOrString(String id) => int.tryParse(id) ?? id;

  // ─── Signup ───────────────────────────────────────────────────────────────

  @override
  Future<void> signup({
    required String fullName,
    required String email,
    required String password,
    required String systemRole,
  }) async {
    await _api.signup(
      SignupRequest(
        fullName: fullName.trim(),
        email: email.trim(),
        password: password,
        systemRole: systemRole,
      ),
    );
  }

  // ─── Email verification ───────────────────────────────────────────────────

  @override
  Future<String> verifyEmail(String token) => _api.verifyEmail(token);

  @override
  Future<String> resendVerificationEmail(String email) =>
      _api.resendVerificationEmail(email.trim());

  @override
  Future<bool> checkEmailVerified(String email) =>
      _api.checkEmailVerified(email.trim());

  // ─── Password ─────────────────────────────────────────────────────────────

  @override
  Future<String> forgotPassword(String email) =>
      _api.forgotPassword(email.trim());

  @override
  Future<String> resetPassword({
    required String token,
    required String newPassword,
  }) =>
      _api.resetPassword(token: token, newPassword: newPassword);

  // ─── Session ──────────────────────────────────────────────────────────────

  @override
  Future<void> logout() async {
    _tokenScheduler.cancelProactiveRefresh();
    try {
      await _api.logout();
    } catch (_) {
      // Best-effort — always clear local state.
    }
    TokenStorage.clear();
    UserStorage.clear();
  }
}
