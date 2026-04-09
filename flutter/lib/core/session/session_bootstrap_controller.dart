import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/app_error_bus.dart';
import '../network/error_mapper.dart';
import '../storage/token_storage.dart';
import '../storage/user_storage.dart';
import '../../features/auth/data/auth_providers.dart';

/// Bootstraps the session on cold start / hard-refresh / tab re-open.
///
/// ── Scenario A ──  Normal in-tab navigation
///   sessionStorage token present → call /me → populate UserStorage.
///
/// ── Scenario B ──  Remember-Me cold start (tab closed & re-opened)
///   sessionStorage is gone (cleared by browser), but the access token
///   AND the persist flag are still in localStorage.
///   → Try a silent POST /auth/refresh (sends the HttpOnly cookie).
///   → On success  : save new token + call /me.
///   → On failure  : clear everything → send to login.
///
/// ── Scenario C ──  Remember-Me hard-refresh (F5 / Ctrl-R)
///   Exactly like Scenario B EXCEPT the sessionStorage token IS present
///   because the browser kept it alive across the reload (Chrome/Edge do
///   this for F5; they only clear sessionStorage on a "new tab").
///   We do NOT attempt a silent refresh here — the token is still valid,
///   so we just call /me directly with the existing token.
///
/// This gives us:
///   • Always-fresh /me data on every reload.
///   • No unnecessary refresh call when the token is still valid.
///   • Automatic session restore after tab close (if Remember Me is on).
final sessionBootstrapControllerProvider =
    NotifierProvider<SessionBootstrapController, AsyncValue<void>>(
  SessionBootstrapController.new,
);

class SessionBootstrapController extends Notifier<AsyncValue<void>> {
  CancelToken? _cancelToken;
  String? _lastToken;

  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> ensureBootstrapped() async {
    // ── Scenario B: Remember-Me, no live session token ──────────────────────
    // sessionStorage was wiped (tab close). Try silent refresh first.
    if (!TokenStorage.hasToken && TokenStorage.isPersisted) {
      await _silentRefreshThenBoot();
      return;
    }

    // ── Scenario A / C: live token in memory or sessionStorage ──────────────
    final token = TokenStorage.token?.trim() ?? '';
    if (token.isEmpty) {
      _reset();
      return;
    }

    // Already bootstrapped with this exact token — nothing to do.
    if (UserStorage.hasMe && _lastToken == token) {
      state = const AsyncData(null);
      return;
    }

    // Prevent duplicate in-flight bootstraps for the same token.
    if (_lastToken == token && state.isLoading) return;

    // Fetch /me with the existing valid token (no refresh needed).
    await _fetchMe(token);
  }

  // ─── Scenario B: silent refresh ───────────────────────────────────────────

  Future<void> _silentRefreshThenBoot() async {
    state = const AsyncLoading();

    try {
      final api = ref.read(authApiProvider);

      // withCredentials=true → browser sends the HttpOnly refresh cookie.
      final newToken = await api.refresh();

      TokenStorage.saveSession(accessToken: newToken, persist: true);

      // Start proactive refresh timer for the new token.
      ref.read(apiClientProvider).scheduleProactiveRefresh(newToken);

      await _fetchMe(newToken);
    } catch (e) {
      // Refresh cookie expired or revoked during a silent restore attempt.
      // Treat this as a guest state on web instead of showing a session-expired
      // dialog on public pages.
      TokenStorage.clear();
      UserStorage.clear();
      state = const AsyncData(null);
    }
  }

  // ─── /me fetch ─────────────────────────────────────────────────────────────

  Future<void> _fetchMe(String token) async {
    _cancelToken?.cancel('superseded');
    final ct = CancelToken();
    _cancelToken = ct;
    _lastToken = token;

    state = const AsyncLoading();

    try {
      final api = ref.read(authApiProvider);
      final raw = await api.me(cancelToken: ct);
      if (ct.isCancelled) return;

      final persist = TokenStorage.isPersisted;
      final normalized = _normalizeMePayload(raw);

      // ── Merge with existing UserStorage to preserve login fields ──────────
      // /auth/me only returns 4 fields (id, email, full_name, system_role).
      // Login saves the full profile (phone, bio, avatar_url, created_at…).
      // We must NOT overwrite rich login data with the sparse /me response.
      final existing = UserStorage.meJson;
      final Map<String, dynamic> merged;

      if (existing != null) {
        final existingUser = (existing['user'] is Map)
            ? (existing['user'] as Map).cast<String, dynamic>()
            : <String, dynamic>{};
        final newUser = (normalized['user'] is Map)
            ? (normalized['user'] as Map).cast<String, dynamic>()
            : <String, dynamic>{};

        // New data from /me takes priority, but nulls don't overwrite existing values
        final mergedUser = <String, dynamic>{...existingUser};
        newUser.forEach((k, v) {
          if (v != null) mergedUser[k] = v;
        });

        merged = {
          ...existing,
          ...normalized,
          'user': mergedUser,
        };
      } else {
        merged = normalized;
      }

      // Save to the correct storage tier so data survives hard-refresh when
      // Remember Me is on.
      UserStorage.saveMe(merged, persist: persist);

      // Schedule proactive refresh so the token never expires silently while
      // the user is active. Only needed after a cold bootstrap — subsequent
      // token rotations re-schedule this themselves.
      if (persist) {
        ref.read(apiClientProvider).scheduleProactiveRefresh(token);
      }

      state = const AsyncData(null);
    } catch (e, st) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        state = const AsyncData(null);
        return;
      }

      final failure = mapApiFailure(e);
      AppErrorReporter.report(ref, failure);
      state = AsyncError(e, st);
    }
  }

  // ─── helpers ───────────────────────────────────────────────────────────────

  Map<String, dynamic> _normalizeMePayload(Map<String, dynamic> raw) {
    Map<String, dynamic> root = raw;
    final data = root['data'];
    if (data is Map) root = data.cast<String, dynamic>();

    Map<String, dynamic> user;
    final u = root['user'];
    if (u is Map) {
      user = u.cast<String, dynamic>();
    } else {
      user = root;
    }

    final out = <String, dynamic>{'user': user};

    final orgs = root['organizations'];
    if (orgs is List) {
      out['organizations'] =
          orgs.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } else if (orgs is Map) {
      out['organizations'] = [orgs.cast<String, dynamic>()];
    }

    final list =
        (out['organizations'] is List) ? out['organizations'] as List : const [];
    if (list.isNotEmpty && out['selected_organization_id'] == null) {
      final first = list.first;
      if (first is Map) {
        final id = first['id'];
        if (id != null) out['selected_organization_id'] = id;
      }
    }

    return out;
  }

  void _reset() {
    _cancelToken?.cancel('reset');
    _cancelToken = null;
    _lastToken = null;
    state = const AsyncData(null);
  }
}
