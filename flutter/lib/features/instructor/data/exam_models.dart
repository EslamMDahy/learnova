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

class ExamSectionCreatePayload {
  final String title;
  final String? description;
  final String questionType;
  final int? timeLimitMinutes;
  final bool mustComplete;

  const ExamSectionCreatePayload({
    required this.title,
    this.description,
    required this.questionType,
    this.timeLimitMinutes,
    this.mustComplete = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'question_type': questionType,
      'time_limit_minutes': timeLimitMinutes,
      'must_complete': mustComplete,
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
    return ExamModel(
      id: _asInt(json['id']),
      courseId: _asInt(json['course_id']),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      instructions: json['instructions']?.toString(),
      examType: (json['exam_type'] ?? 'quiz').toString(),
      durationMinutes: _nullableInt(json['duration_minutes']),
      maxAttempts: _nullableInt(json['max_attempts']) ?? 1,
      passingScore: _nullableDouble(json['passing_score']),
      totalQuestions: _nullableInt(json['total_questions']) ?? 0,
      totalScore: _nullableDouble(json['total_score']) ?? 0,
      isPublished: (json['is_published'] as bool?) ?? false,
      shuffleQuestions: (json['shuffle_questions'] as bool?) ?? false,
      shuffleOptions: (json['shuffle_options'] as bool?) ?? false,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
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
      courseId: _nullableInt(json['course_id']) ?? 0,
      total: _nullableInt(json['total']) ?? raw.length,
      exams: raw
          .whereType<Map>()
          .map((item) => ExamModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class ExamSectionModel {
  final int id;
  final int examId;
  final String title;
  final String? description;
  final String questionType;
  final int orderIndex;
  final int questionCount;
  final double sectionScore;
  final int? timeLimitMinutes;
  final bool mustComplete;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExamSectionModel({
    required this.id,
    required this.examId,
    required this.title,
    this.description,
    required this.questionType,
    required this.orderIndex,
    required this.questionCount,
    required this.sectionScore,
    this.timeLimitMinutes,
    required this.mustComplete,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExamSectionModel.fromJson(Map<String, dynamic> json) {
    return ExamSectionModel(
      id: _asInt(json['id']),
      examId: _asInt(json['exam_id']),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      questionType: (json['question_type'] ?? 'multiple_choice').toString(),
      orderIndex: _nullableInt(json['order_index']) ?? 0,
      questionCount: _nullableInt(json['question_count']) ?? 0,
      sectionScore: _nullableDouble(json['section_score']) ?? 0,
      timeLimitMinutes: _nullableInt(json['time_limit_minutes']),
      mustComplete: (json['must_complete'] as bool?) ?? true,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }
}

class ExamSectionDetailsModel extends ExamSectionModel {
  final List<ExamQuestionDetail> questions;

  const ExamSectionDetailsModel({
    required super.id,
    required super.examId,
    required super.title,
    super.description,
    required super.questionType,
    required super.orderIndex,
    required super.questionCount,
    required super.sectionScore,
    super.timeLimitMinutes,
    required super.mustComplete,
    required super.createdAt,
    required super.updatedAt,
    required this.questions,
  });

  factory ExamSectionDetailsModel.fromJson(Map<String, dynamic> json) {
    final rawQuestions = (json['questions'] as List?) ?? const [];
    return ExamSectionDetailsModel(
      id: _asInt(json['id']),
      examId: _asInt(json['exam_id']),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      questionType: (json['question_type'] ?? 'multiple_choice').toString(),
      orderIndex: _nullableInt(json['order_index']) ?? 0,
      questionCount: _nullableInt(json['question_count']) ?? rawQuestions.length,
      sectionScore: _nullableDouble(json['section_score']) ?? 0,
      timeLimitMinutes: _nullableInt(json['time_limit_minutes']),
      mustComplete: (json['must_complete'] as bool?) ?? true,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      questions: rawQuestions
          .whereType<Map>()
          .map((item) => ExamQuestionDetail.fromJson(Map<String, dynamic>.from(item)))
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
  final int sectionId;
  final int addedCount;
  final int sectionQuestionCount;
  final double sectionScore;
  final int totalQuestions;
  final double totalScore;

  const ExamAddQuestionsResponse({
    required this.examId,
    required this.courseId,
    required this.sectionId,
    required this.addedCount,
    required this.sectionQuestionCount,
    required this.sectionScore,
    required this.totalQuestions,
    required this.totalScore,
  });

  factory ExamAddQuestionsResponse.fromJson(Map<String, dynamic> json) {
    return ExamAddQuestionsResponse(
      examId: _asInt(json['exam_id']),
      courseId: _asInt(json['course_id']),
      sectionId: _nullableInt(json['section_id']) ?? 0,
      addedCount: _nullableInt(json['added_count']) ?? 0,
      sectionQuestionCount: _nullableInt(json['section_question_count']) ?? 0,
      sectionScore: _nullableDouble(json['section_score']) ?? 0,
      totalQuestions: _nullableInt(json['exam_total_questions']) ??
          _nullableInt(json['total_questions']) ??
          0,
      totalScore: _nullableDouble(json['exam_total_score']) ??
          _nullableDouble(json['total_score']) ??
          0,
    );
  }
}

class ExamQuestionDetail {
  final int examQuestionId;
  final int sectionId;
  final double points;
  final QuestionModel question;

  const ExamQuestionDetail({
    required this.examQuestionId,
    required this.sectionId,
    required this.points,
    required this.question,
  });

  factory ExamQuestionDetail.fromJson(Map<String, dynamic> json) {
    return ExamQuestionDetail(
      examQuestionId: _asInt(json['exam_question_id']),
      sectionId: _nullableInt(json['section_id']) ?? 0,
      points: _nullableDouble(json['points']) ?? _nullableDouble(json['max_score']) ?? 0,
      question: QuestionModel.fromJson({
        ...json,
        if (json['id'] == null && json['question_id'] != null) 'id': json['question_id'],
      }),
    );
  }
}

class ExamDetailsModel {
  final ExamModel exam;
  final List<ExamSectionDetailsModel> sections;
  final List<ExamQuestionDetail> questions;

  const ExamDetailsModel({
    required this.exam,
    required this.sections,
    required this.questions,
  });

  factory ExamDetailsModel.fromJson(Map<String, dynamic> json) {
    final rawSections = (json['sections'] as List?) ?? const [];
    final sections = rawSections
        .whereType<Map>()
        .map((item) => ExamSectionDetailsModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    final rawFlatQuestions = (json['questions'] as List?) ?? const [];
    final flatQuestions = rawFlatQuestions
        .whereType<Map>()
        .map((item) => ExamQuestionDetail.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    final questions = sections.isNotEmpty
        ? sections.expand((section) => section.questions).toList()
        : flatQuestions;

    return ExamDetailsModel(
      exam: ExamModel.fromJson(json),
      sections: sections,
      questions: questions,
    );
  }
}

class ExamPublishResponse {
  final int examId;
  final int courseId;
  final bool isPublished;
  final int totalQuestions;
  final double totalScore;
  final String message;

  const ExamPublishResponse({
    required this.examId,
    required this.courseId,
    required this.isPublished,
    required this.totalQuestions,
    required this.totalScore,
    required this.message,
  });

  factory ExamPublishResponse.fromJson(Map<String, dynamic> json) {
    return ExamPublishResponse(
      examId: _asInt(json['exam_id']),
      courseId: _asInt(json['course_id']),
      isPublished: (json['is_published'] as bool?) ?? false,
      totalQuestions: _nullableInt(json['total_questions']) ?? 0,
      totalScore: _nullableDouble(json['total_score']) ?? 0,
      message: (json['message'] ?? '').toString(),
    );
  }
}

class ExamRemoveQuestionResponse {
  final int examId;
  final int courseId;
  final int sectionId;
  final int removedExamQuestionId;
  final int totalQuestions;
  final double totalScore;
  final String message;

  const ExamRemoveQuestionResponse({
    required this.examId,
    required this.courseId,
    required this.sectionId,
    required this.removedExamQuestionId,
    required this.totalQuestions,
    required this.totalScore,
    required this.message,
  });

  factory ExamRemoveQuestionResponse.fromJson(Map<String, dynamic> json) {
    return ExamRemoveQuestionResponse(
      examId: _asInt(json['exam_id']),
      courseId: _asInt(json['course_id']),
      sectionId: _nullableInt(json['section_id']) ?? 0,
      removedExamQuestionId: _asInt(json['removed_exam_question_id']),
      totalQuestions: _nullableInt(json['total_questions']) ?? 0,
      totalScore: _nullableDouble(json['total_score']) ?? 0,
      message: (json['message'] ?? '').toString(),
    );
  }
}

int _asInt(dynamic value) {
  final parsed = _nullableInt(value);
  if (parsed == null) throw FormatException('Expected integer value, got $value');
  return parsed;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _nullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime _parseDate(dynamic value) {
  return DateTime.tryParse((value ?? '').toString()) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
