class VerifyEmailSentState {
  final bool loading;           // resend in progress
  final bool checkingVerification; // "I've verified" check in progress
  final String? error;
  final String? successMessage;

  const VerifyEmailSentState({
    this.loading = false,
    this.checkingVerification = false,
    this.error,
    this.successMessage,
  });

  VerifyEmailSentState copyWith({
    bool? loading,
    bool? checkingVerification,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return VerifyEmailSentState(
      loading: loading ?? this.loading,
      checkingVerification: checkingVerification ?? this.checkingVerification,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}
