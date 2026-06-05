import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import 'exam_correction_models.dart';

class ExamCorrectionApi {
  final ApiClient _client;

  ExamCorrectionApi(this._client);

  Future<ExamScanAnalyzeResponse> analyzeExamScan({
    required List<ExamCorrectionUploadFile> files,
    required String language,
    int? examId,
    int? courseId,
    int studentIdDigits = 6,
    CancelToken? cancelToken,
  }) async {
    if (files.isEmpty) {
      throw ArgumentError('Select at least one solved exam scan.');
    }

    final form = FormData();
    for (final file in files) {
      form.files.add(
        MapEntry(
          'files',
          MultipartFile.fromBytes(
            file.bytes,
            filename: file.name.isNotEmpty ? file.name : 'exam-scan.png',
          ),
        ),
      );
    }

    form.fields.add(MapEntry('lang', language));
    form.fields.add(MapEntry('student_id_digits', studentIdDigits.toString()));
    if (examId != null) form.fields.add(MapEntry('exam_id', examId.toString()));
    if (courseId != null) form.fields.add(MapEntry('course_id', courseId.toString()));

    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.examScanAnalyze,
      data: form,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(minutes: 3),
        receiveTimeout: const Duration(minutes: 6),
      ),
      cancelToken: cancelToken,
    );

    final data = res.data;
    if (data is Map<String, dynamic>) {
      return ExamScanAnalyzeResponse.fromJson(data);
    }
    throw const FormatException('Invalid response from exam scan analyzer.');
  }

  Future<ExamScanSubmitResponse> submitExamScan({
    required ExamScanAnalyzeResponse scan,
    required int examId,
    required int studentUserId,
    CancelToken? cancelToken,
  }) async {
    final totalScore = scan.answers.fold<double>(0, (sum, answer) => sum + (answer.pointsEarned ?? 0));
    final percentage = scan.gradePreview.totalScore > 0 ? (totalScore / scan.gradePreview.totalScore) * 100 : null;

    final res = await _client.post<Map<String, dynamic>>(
      Endpoints.examScanSubmit,
      data: {
        'scan_id': scan.scanId,
        'exam_id': examId,
        'student_id': studentUserId,
        'answers': scan.answers
            .where((answer) => answer.examQuestionId != null)
            .map((answer) => answer.toSubmitJson())
            .toList(growable: false),
        'total_score': totalScore,
        'percentage_score': percentage,
      },
      options: Options(
        sendTimeout: const Duration(minutes: 1),
        receiveTimeout: const Duration(minutes: 2),
      ),
      cancelToken: cancelToken,
    );

    final data = res.data;
    if (data is Map<String, dynamic>) {
      return ExamScanSubmitResponse.fromJson(data);
    }
    throw const FormatException('Invalid response from exam scan submit endpoint.');
  }
}
