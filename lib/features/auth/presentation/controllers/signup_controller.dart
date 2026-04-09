import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_error_bus.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/network/error_mapper.dart';
import '../../data/auth_providers.dart';
import '../../data/auth_repository.dart';
import 'signup_state.dart';

final signupControllerProvider =
    StateNotifierProvider<SignupController, SignupState>(
  (ref) => SignupController(ref),
);

class SignupController extends StateNotifier<SignupState> {
  SignupController(this.ref) : super(const SignupState());

  final Ref ref;
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  void clearError() {
    if (state.error != null) {
      state = state.copyWith();
    }
  }

  void reset() {
    
    clearError();
    state = const SignupState();
  }

  bool _looksLikeEmail(String v) {
    final s = v.trim();
    return s.isNotEmpty && s.contains('@') && s.contains('.');
  }


  /// full_name, email, password, system_role
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
        loading: false,
        error: 'Please enter a valid email.',
      );
      return false;
    }

    if (password.trim().length < 8) {
      state = state.copyWith(
        loading: false,
        error: 'Password must be at least 8 characters.',
      );
      return false;
    }

    
    const allowed = {'student', 'instructor', 'assistant', 'owner'};
    if (!allowed.contains(cleanSystemRole)) {
      state = state.copyWith(
        loading: false,
        error: 'Invalid System Role.',
      );
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

      state = state.copyWith(
        loading: false,
        error: failure.message,
      );
      return false;
    }
  }
}
