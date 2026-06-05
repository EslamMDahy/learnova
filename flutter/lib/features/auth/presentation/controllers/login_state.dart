import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps [AsyncValue<void>] so the login screen has a single,
/// standardised source of truth for loading / success / error.
///
/// Usage in UI:
///   final state = ref.watch(loginControllerProvider);
///   state.isLoading  → show spinner
///   state.hasError   → show error banner
///   state.error      → the thrown exception (cast to AppFailure or use .toString())
class LoginState {
  final AsyncValue<void> async;

  const LoginState({this.async = const AsyncValue.data(null)});

  // ── Convenience getters ───────────────────────────────────────────────────

  bool get isLoading => async.isLoading;

  /// Returns the error message string, or null when there is no error.
  String? get errorMessage => async.hasError
      ? (async.error?.toString() ?? 'An unexpected error occurred.')
      : null;

  // ── State transitions ─────────────────────────────────────────────────────

  LoginState toLoading() =>
      const LoginState(async: AsyncValue.loading());

  LoginState toSuccess() =>
      const LoginState();

  LoginState toError(Object error, [StackTrace? stackTrace]) =>
      LoginState(async: AsyncValue.error(error, stackTrace ?? StackTrace.empty));

  LoginState clearError() =>
      const LoginState();
}
