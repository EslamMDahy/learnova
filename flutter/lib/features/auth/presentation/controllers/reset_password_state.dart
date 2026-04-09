import 'package:equatable/equatable.dart';

class ResetPasswordState extends Equatable {
  final bool loading;
  final bool success;
  final String? message;
  final String? error;

  const ResetPasswordState({
    this.loading = false,
    this.success = false,
    this.message,
    this.error,
  });

  ResetPasswordState copyWith({
    bool? loading,
    bool? success,
    String? message,
    String? error,
  }) {
    return ResetPasswordState(
      loading: loading ?? this.loading,
      success: success ?? this.success,
      message: message ?? this.message,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [loading, success, message, error];
}
