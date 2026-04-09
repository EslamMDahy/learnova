class VerifyEmailState {
  final bool loading;
  final bool success;
  final String? successMessage;
  final String? error;

  const VerifyEmailState({
    this.loading = false,
    this.success = false,
    this.successMessage,
    this.error,
  });

  VerifyEmailState copyWith({
    bool? loading,
    bool? success,
    String? successMessage,
    String? error,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return VerifyEmailState(
      loading: loading ?? this.loading,
      success: success ?? this.success,
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      error: clearError ? null : (error ?? this.error),
    );
  }
}
