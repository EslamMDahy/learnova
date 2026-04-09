import 'package:equatable/equatable.dart';

class ResetPasswordState extends Equatable {
  final bool loading;
  final bool success;
  final String? successMessage;
  final String? error;

  const ResetPasswordState({
    this.loading = false,
    this.success = false,
    this.successMessage,
    this.error,
  });

  ResetPasswordState copyWith({
    bool? loading,
    bool? success,
    String? successMessage,
    String? error,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ResetPasswordState(
      loading: loading ?? this.loading,
      success: success ?? this.success,
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [loading, success, successMessage, error];
}
