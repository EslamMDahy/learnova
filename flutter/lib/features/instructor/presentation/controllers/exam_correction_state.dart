import '../../data/exam_correction_models.dart';

class ExamCorrectionState {
  final List<ExamCorrectionUploadFile> files;
  final String language;
  final String examIdText;
  final String courseIdText;
  final int studentIdDigits;
  final bool loading;
  final bool submitting;
  final String? error;
  final String? submitMessage;
  final ExamScanAnalyzeResponse? response;

  const ExamCorrectionState({
    this.files = const [],
    this.language = 'eng',
    this.examIdText = '',
    this.courseIdText = '',
    this.studentIdDigits = 6,
    this.loading = false,
    this.submitting = false,
    this.error,
    this.submitMessage,
    this.response,
  });

  bool get canAnalyze => files.isNotEmpty && !loading && !submitting;
  bool get canSubmit {
    final scan = response;
    return scan != null &&
        !loading &&
        !submitting &&
        scan.exam.examId != null &&
        scan.student.userId != null &&
        scan.answers.isNotEmpty;
  }

  ExamCorrectionState copyWith({
    List<ExamCorrectionUploadFile>? files,
    String? language,
    String? examIdText,
    String? courseIdText,
    int? studentIdDigits,
    bool? loading,
    bool? submitting,
    String? error,
    String? submitMessage,
    ExamScanAnalyzeResponse? response,
    bool clearError = false,
    bool clearSubmitMessage = false,
    bool clearResponse = false,
  }) {
    return ExamCorrectionState(
      files: files ?? this.files,
      language: language ?? this.language,
      examIdText: examIdText ?? this.examIdText,
      courseIdText: courseIdText ?? this.courseIdText,
      studentIdDigits: studentIdDigits ?? this.studentIdDigits,
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      error: clearError ? null : error ?? this.error,
      submitMessage: clearSubmitMessage ? null : submitMessage ?? this.submitMessage,
      response: clearResponse ? null : response ?? this.response,
    );
  }
}
