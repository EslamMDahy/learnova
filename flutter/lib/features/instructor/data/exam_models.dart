import 'question_models.dart';

class ExamCreatePayload {
  final String title;
  final String? description;
  final String? instructions;
  final String examType;
  final int? durationMinutes;
  final int maxAttempts;
  final double? passingScore;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final DateTime? availableFrom;
  final DateTime? availableTo;
  final String? accessCode;

  const ExamCreatePayload({
    required this.title,
    this.description,
    this.instructions,
    this.examType = 'quiz',
    this.durationMinutes,
    this.maxAttempts = 1,
    this.passingScore,
    this.shuffleQuestions = true,
    this.shuffleOptions = false,
    this.availableFrom,
    this.availableTo,
    this.accessCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'instructions': instructions,
      'exam_type': examType,
      'duration_minutes': durationMinutes,
      'max_attempts': maxAttempts,
      'passing_score': passingScore,
      'shuffle_questions': shuffleQuestions,
      'shuffle_options': shuffleOptions,
      'available_from': availableFrom?.toIso8601String(),
      'available_to': availableTo?.toIso8601String(),
      'access_code': accessCode,
    }..removeWhere((_, value) => value == null);
  }
}

class ExamModel {
  final int id;
  final int courseId;
  final String title;
  final String? description;
  final String? instructions;
  final String examType;
  final int? durationMinutes;
  final int maxAttempts;
  final double? passingScore;
  final int totalQuestions;
  final double totalScore;
  final bool isPublished;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExamModel({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    this.instructions,
    required this.examType,
    this.durationMinutes,
    required this.maxAttempts,
    this.passingScore,
    required this.totalQuestions,
    required this.totalScore,
    required this.isPublished,
    required this.shuffleQuestions,
    required this.shuffleOptions,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      return DateTime.tryParse((value ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    return ExamModel(
      id: (json['id'] as num).toInt(),
      courseId: (json['course_id'] as num).toInt(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      instructions: json['instructions']?.toString(),
      examType: (json['exam_type'] ?? 'quiz').toString(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      maxAttempts: (json['max_attempts'] as num?)?.toInt() ?? 1,
      passingScore: (json['passing_score'] as num?)?.toDouble(),
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      totalScore: (json['total_score'] as num?)?.toDouble() ?? 0,
      isPublished: (json['is_published'] as bool?) ?? false,
      shuffleQuestions: (json['shuffle_questions'] as bool?) ?? false,
      shuffleOptions: (json['shuffle_options'] as bool?) ?? false,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }
}

class ExamListResponse {
  final int courseId;
  final int total;
  final List<ExamModel> exams;

  const ExamListResponse({
    required this.courseId,
    required this.total,
    required this.exams,
  });

  factory ExamListResponse.fromJson(Map<String, dynamic> json) {
    final raw = (json['exams'] as List?) ?? const [];
    return ExamListResponse(
      courseId: (json['course_id'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? raw.length,
      exams: raw
          .whereType<Map>()
          .map((item) => ExamModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class ExamAddQuestionsPayload {
  final List<int> questionIds;

  const ExamAddQuestionsPayload({required this.questionIds});

  Map<String, dynamic> toJson() => {'question_ids': questionIds};
}

class ExamAddQuestionsResponse {
  final int examId;
  final int courseId;
  final int addedCount;
  final int totalQuestions;
  final double totalScore;

  const ExamAddQuestionsResponse({
    required this.examId,
    required this.courseId,
    required this.addedCount,
    required this.totalQuestions,
    required this.totalScore,
  });

  factory ExamAddQuestionsResponse.fromJson(Map<String, dynamic> json) {
    return ExamAddQuestionsResponse(
      examId: (json['exam_id'] as num).toInt(),
      courseId: (json['course_id'] as num).toInt(),
      addedCount: (json['added_count'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      totalScore: (json['total_score'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ExamQuestionDetail {
  final int examQuestionId;
  final QuestionModel question;

  const ExamQuestionDetail({
    required this.examQuestionId,
    required this.question,
  });

  factory ExamQuestionDetail.fromJson(Map<String, dynamic> json) {
    return ExamQuestionDetail(
      examQuestionId: (json['exam_question_id'] as num).toInt(),
      question: QuestionModel.fromJson(json),
    );
  }
}

class ExamDetailsModel {
  final ExamModel exam;
  final List<ExamQuestionDetail> questions;

  const ExamDetailsModel({required this.exam, required this.questions});

  factory ExamDetailsModel.fromJson(Map<String, dynamic> json) {
    final raw = (json['questions'] as List?) ?? const [];
    return ExamDetailsModel(
      exam: ExamModel.fromJson(json),
      questions: raw
          .whereType<Map>()
          .map((item) => ExamQuestionDetail.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}
