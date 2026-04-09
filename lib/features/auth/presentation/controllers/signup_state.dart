class SignupState {
  final bool loading;
  final String? error;

  const SignupState({
    this.loading = false,
    this.error,
  });

  SignupState copyWith({
    bool? loading,
    String? error,
  }) {
    return SignupState(
      loading: loading ?? this.loading,
      error: error ?? this.error,
    );
  }
}
