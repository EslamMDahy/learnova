import 'package:equatable/equatable.dart';

class ForgotPasswordState extends Equatable {
  final bool loading;
  final bool sent;
  final String? message;
  final String? error;

  
  final String? lastEmail;

  const ForgotPasswordState({
    this.loading = false,
    this.sent = false,
    this.message,
    this.error,
    this.lastEmail,
  });

  ForgotPasswordState copyWith({
    bool? loading,
    bool? sent,
    String? message,
    String? error,
    String? lastEmail,
  }) {
    return ForgotPasswordState(
      loading: loading ?? this.loading,
      sent: sent ?? this.sent,
      message: message ?? this.message,
      error: error ?? this.error,
      lastEmail: lastEmail ?? this.lastEmail,
    );
  }

  @override
  List<Object?> get props => [loading, sent, message, error, lastEmail];
}
