import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_error_bus.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/network/error_mapper.dart';
import '../../data/auth_providers.dart';
import '../../data/auth_repository.dart';
import 'forgot_password_state.dart';

final forgotPasswordControllerProvider =
    StateNotifierProvider<ForgotPasswordController, ForgotPasswordState>(
  (ref) => ForgotPasswordController(ref),
);

class ForgotPasswordController extends StateNotifier<ForgotPasswordState> {
  ForgotPasswordController(this.ref) : super(const ForgotPasswordState());

  final Ref ref;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  void reset() {
    
    clearError();
    state = const ForgotPasswordState();
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith();
    }
  }

  bool _looksLikeEmail(String v) {
    final s = v.trim();
    return s.isNotEmpty && s.contains('@');
  }

  Future<bool> sendResetLink(String email) async {
    final e = email.trim();

    
    clearError();

    
    state = state.copyWith(
      loading: true,
      sent: false,
      lastEmail: state.lastEmail, 
    );

    if (!_looksLikeEmail(e)) {
      state = state.copyWith(
        loading: false,
        sent: false,
        error: 'Please enter a valid email address.',
      );
      return false;
    }

    try {
      final msg = await _repo.forgotPassword(e);

      final safeMsg = (msg.trim().isNotEmpty)
          ? msg.trim()
          : 'If this email exists, a reset link has been sent.';

      state = state.copyWith(
        loading: false,
        sent: true,
        message: safeMsg,
        lastEmail: e, 
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

  Future<bool> resend() async {
    final e = (state.lastEmail ?? '').trim();
    if (!_looksLikeEmail(e)) {
      state = state.copyWith(
        sent: false,
        error: 'Email is missing. Please enter your email again.',
      );
      return false;
    }
    return sendResetLink(e);
  }
}
