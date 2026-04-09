class VerifyEmailState {
  final bool loading;
  final bool success;
  final String? error;

  const VerifyEmailState({
    this.loading = false,
    this.success = false,
    this.error,
  });

  VerifyEmailState copyWith({
    bool? loading,
    bool? success,
    String? error,
  }) {
    return VerifyEmailState(
      loading: loading ?? this.loading,
      success: success ?? this.success,
      error: error ?? this.error,
    );
  }
}
