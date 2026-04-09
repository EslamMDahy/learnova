import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/error_mapper.dart';
import '../../data/auth_providers.dart';
import '../../domain/i_auth_repository.dart';
import 'verify_email_state.dart';

/// Auth controller for the verify-email screen.
/// Uses the Riverpod 2.x [Notifier] API.
final verifyEmailControllerProvider =
    NotifierProvider<VerifyEmailController, VerifyEmailState>(
        VerifyEmailController.new);

class VerifyEmailController extends Notifier<VerifyEmailState> {
  @override
  VerifyEmailState build() => const VerifyEmailState();

  IAuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> verifyEmail(String token) async {
    state = state.copyWith(loading: true, clearError: true);

    try {
      final message = await _repo.verifyEmail(token);
      state = state.copyWith(loading: false, successMessage: message);
      return true;
    } catch (e) {
      final failure = mapApiFailure(e);
      state = state.copyWith(loading: false, error: failure.message);
      return false;
    }
  }
}
