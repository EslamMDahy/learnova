import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_error_bus.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/network/error_mapper.dart';
import '../../data/auth_providers.dart';
import '../../domain/i_auth_repository.dart';
import 'signup_state.dart';

/// Auth controller for the signup screen.
/// Uses the Riverpod 2.x [Notifier] API.
final signupControllerProvider =
    NotifierProvider<SignupController, SignupState>(SignupController.new);

class SignupController extends Notifier<SignupState> {
  @override
  SignupState build() => const SignupState();

  IAuthRepository get _repo => ref.read(authRepositoryProvider);

  void clearError() {
    if (state.error != null) {
      state = state.copyWith();
    }
  }

  void reset() {
    state = const SignupState();
  }

  bool _looksLikeEmail(String v) {
    final s = v.trim();
    return s.isNotEmpty && s.contains('@') && s.contains('.');
  }

  Future<bool> signup({
    required String fullName,
    required String email,
    required String password,
    required String systemRole,
  }) async {
    clearError();
    state = state.copyWith(loading: true);

    final cleanFullName = fullName.trim();
    final cleanEmail = email.trim();
    final cleanSystemRole = systemRole.trim().toLowerCase();

    if (cleanFullName.isEmpty) {
      state = state.copyWith(loading: false, error: 'Full name is required.');
      return false;
    }

    if (!_looksLikeEmail(cleanEmail)) {
      state = state.copyWith(
          loading: false, error: 'Please enter a valid email.',);
      return false;
    }

    if (password.trim().length < 8) {
      state = state.copyWith(
          loading: false,
          error: 'Password must be at least 8 characters.',);
      return false;
    }

    const allowed = {'student', 'instructor', 'assistant', 'owner'};
    if (!allowed.contains(cleanSystemRole)) {
      state = state.copyWith(loading: false, error: 'Invalid System Role.');
      return false;
    }

    try {
      await _repo.signup(
        fullName: cleanFullName,
        email: cleanEmail,
        password: password,
        systemRole: cleanSystemRole,
      );

      state = state.copyWith(loading: false);
      return true;
    } catch (e) {
      final failure = mapApiFailure(e);

      if (TokenStorage.hasToken && failure.isAuthIssue) {
        state = state.copyWith(loading: false);
        AppErrorReporter.report(ref, failure);
        return false;
      }

      state = state.copyWith(loading: false, error: failure.message);
      return false;
    }
  }
}
