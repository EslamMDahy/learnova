class VerifyEmailSentState {
  final bool loading;              // resend in progress
  final bool checkingVerification; // "I've verified" check in progress
  final int resendCount;           // how many times the user has resent
  final String? error;
  final String? successMessage;

  const VerifyEmailSentState({
    this.loading = false,
    this.checkingVerification = false,
    this.resendCount = 0,
    this.error,
    this.successMessage,
  });

  VerifyEmailSentState copyWith({
    bool? loading,
    bool? checkingVerification,
    int? resendCount,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return VerifyEmailSentState(
      loading: loading ?? this.loading,
      checkingVerification: checkingVerification ?? this.checkingVerification,
      resendCount: resendCount ?? this.resendCount,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}
