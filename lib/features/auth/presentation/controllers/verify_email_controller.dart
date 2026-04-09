import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/error_mapper.dart';
import '../../data/auth_providers.dart';
import '../../data/auth_repository.dart';
import 'verify_email_state.dart';

final verifyEmailControllerProvider =
    StateNotifierProvider<VerifyEmailController, VerifyEmailState>(
  (ref) => VerifyEmailController(ref),
);

class VerifyEmailController extends StateNotifier<VerifyEmailState> {
  VerifyEmailController(this.ref) : super(const VerifyEmailState());

  final Ref ref;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  void clearError() {
    if (state.error != null) {
      state = state.copyWith();
    }
  }

  void setError(String msg) {
    state = state.copyWith(
      loading: false,
      success: false,
      error: msg,
    );
  }

  Future<bool> verify(String token) async {
    final t = token.trim();
    if (t.isEmpty) {
      setError('Invalid verification link. Please request a new one.');
      return false;
    }

    
    clearError();

    state = state.copyWith(
      loading: true,
      success: false,
    );

    try {
      await _repo.verifyEmail(t);
      state = state.copyWith(
        loading: false,
        success: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        success: false,
        error: mapApiFailure(e).message,
      );
      return false;
    }
  }

  void reset() {
    
    clearError();
    state = const VerifyEmailState();
  }
}
