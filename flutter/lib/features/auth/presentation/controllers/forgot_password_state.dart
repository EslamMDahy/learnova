import 'package:equatable/equatable.dart';

class ForgotPasswordState extends Equatable {
  final bool loading;
  final bool sent;
  final String? successMessage;
  final String? error;
  final String? lastEmail;

  const ForgotPasswordState({
    this.loading = false,
    this.sent = false,
    this.successMessage,
    this.error,
    this.lastEmail,
  });

  ForgotPasswordState copyWith({
    bool? loading,
    bool? sent,
    String? successMessage,
    String? error,
    String? lastEmail,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ForgotPasswordState(
      loading: loading ?? this.loading,
      sent: sent ?? this.sent,
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      error: clearError ? null : (error ?? this.error),
      lastEmail: lastEmail ?? this.lastEmail,
    );
  }

  @override
  List<Object?> get props => [loading, sent, successMessage, error, lastEmail];
}
