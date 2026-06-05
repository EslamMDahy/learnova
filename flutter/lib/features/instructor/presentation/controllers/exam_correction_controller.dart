import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_error_bus.dart';
import '../../../../core/network/error_mapper.dart';
import '../../../../core/utils/browser_file_picker.dart';
import '../../data/exam_correction_models.dart';
import '../../data/exam_correction_providers.dart';
import 'exam_correction_state.dart';

final examCorrectionControllerProvider = StateNotifierProvider.autoDispose<
    ExamCorrectionController, ExamCorrectionState>(
  (ref) => ExamCorrectionController(ref),
);

class ExamCorrectionController extends StateNotifier<ExamCorrectionState> {
  ExamCorrectionController(this._ref) : super(const ExamCorrectionState());

  static const int _maxFiles = 12;
  static const int _maxFileBytes = 15 * 1024 * 1024;

  final Ref _ref;
  CancelToken? _cancel;

  Future<void> pickFiles() async {
    final picked = await pickBrowserFiles(
      acceptedExtensions: const ['.pdf', '.png', '.jpg', '.jpeg', '.webp', '.tif', '.tiff', '.bmp'],
      multiple: true,
    );

    if (picked.isEmpty) return;

    final next = List<ExamCorrectionUploadFile>.from(state.files);
    final rejected = <String>[];

    for (final file in picked) {
      final upload = ExamCorrectionUploadFile(
        name: file.name,
        mimeType: file.mimeType,
        sizeBytes: file.sizeBytes,
        bytes: file.bytes,
      );

      if (next.length >= _maxFiles) {
        rejected.add('${file.name}: maximum $_maxFiles files per run');
        continue;
      }
      if (!upload.isSupported) {
        rejected.add('${file.name}: unsupported file type');
        continue;
      }
      if (upload.sizeBytes > _maxFileBytes) {
        rejected.add('${file.name}: file is larger than 15 MB');
        continue;
      }
      next.add(upload);
    }

    state = state.copyWith(
      files: List.unmodifiable(next),
      error: rejected.isEmpty ? null : rejected.join('\n'),
      clearError: rejected.isEmpty,
      clearSubmitMessage: true,
      clearResponse: true,
    );
  }

  void removeFile(int index) {
    if (index < 0 || index >= state.files.length) return;
    final next = List<ExamCorrectionUploadFile>.from(state.files)..removeAt(index);
    state = state.copyWith(files: List.unmodifiable(next), clearError: true, clearSubmitMessage: true, clearResponse: true);
  }

  void clearFiles() {
    _cancel?.cancel();
    state = state.copyWith(files: const [], loading: false, submitting: false, clearError: true, clearSubmitMessage: true, clearResponse: true);
  }

  void setLanguage(String value) => state = state.copyWith(language: value, clearError: true, clearSubmitMessage: true);
  void setExamIdText(String value) => state = state.copyWith(examIdText: value, clearError: true, clearSubmitMessage: true, clearResponse: true);
  void setCourseIdText(String value) => state = state.copyWith(courseIdText: value, clearError: true, clearSubmitMessage: true, clearResponse: true);
  void setStudentIdDigits(int value) => state = state.copyWith(studentIdDigits: value.clamp(4, 12).toInt(), clearError: true, clearSubmitMessage: true, clearResponse: true);

  Future<void> analyzeScan() async {
    if (!state.canAnalyze) return;

    final examId = _optionalInt(state.examIdText, 'Exam ID');
    if (examId == _invalidInt) return;
    final courseId = _optionalInt(state.courseIdText, 'Course ID');
    if (courseId == _invalidInt) return;

    _cancel?.cancel();
    _cancel = CancelToken();
    state = state.copyWith(loading: true, clearError: true, clearSubmitMessage: true, clearResponse: true);

    try {
      final response = await _ref.read(examCorrectionApiProvider).analyzeExamScan(
            files: state.files,
            language: state.language,
            examId: examId,
            courseId: courseId,
            studentIdDigits: state.studentIdDigits,
            cancelToken: _cancel,
          );
      state = state.copyWith(loading: false, response: response, clearError: true);
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(_ref, failure);
      state = state.copyWith(loading: false, error: failure.message);
    }
  }

  Future<void> submitCorrection() async {
    final scan = state.response;
    if (scan == null || !state.canSubmit) return;

    _cancel?.cancel();
    _cancel = CancelToken();
    state = state.copyWith(submitting: true, clearError: true, clearSubmitMessage: true);

    try {
      final result = await _ref.read(examCorrectionApiProvider).submitExamScan(
            scan: scan,
            examId: scan.exam.examId!,
            studentUserId: scan.student.userId!,
            cancelToken: _cancel,
          );
      state = state.copyWith(
        submitting: false,
        submitMessage: 'Correction saved as graded attempt #${result.attemptId}.',
        clearError: true,
      );
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(_ref, failure);
      state = state.copyWith(submitting: false, error: failure.message);
    }
  }

  static const int _invalidInt = -9223372036854775808;

  int? _optionalInt(String raw, String label) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final parsed = int.tryParse(value);
    if (parsed == null || parsed <= 0) {
      state = state.copyWith(error: '$label must be a positive integer.');
      return _invalidInt;
    }
    return parsed;
  }

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }
}
