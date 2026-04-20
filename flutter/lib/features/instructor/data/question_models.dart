// ─────────────────────────────────────────────────────────────────────────────
//  Question Bank — models
//  In-memory + backend-ready (fromJson / toJson wired to real DB schema).
// ─────────────────────────────────────────────────────────────────────────────

import 'question_vocabulary.dart';

enum QuestionType { multipleChoice, trueFalse, shortAnswer, essay, multiSelect, fillInTheBlank, numeric, code }
enum QuestionDifficulty { easy, medium, hard }
enum QuestionSource { manual, aiGenerated, imported }
enum QuestionApprovalStatus { pending, approved, rejected }

class QuestionOption {
  final String id;
  final String text;
  final bool isCorrect;
  final String? explanation;
  final int orderIndex;

  const QuestionOption({
    required this.id,
    required this.text,
    this.isCorrect = false,
    this.explanation,
    this.orderIndex = 0,
  });

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      id: json['id']?.toString() ?? json['order_index']?.toString() ?? '0',
      text: (json['option_text'] ?? json['text'] ?? '').toString(),
      isCorrect: (json['is_correct'] as bool?) ?? false,
      explanation: json['explanation']?.toString(),
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'option_text': text,
    'is_correct': isCorrect,
    'order_index': orderIndex,
    if (explanation != null) 'explanation': explanation,
  };
}

class QuestionModel {
  // IDs — local uses String (uuid), remote uses int
  final String id;
  final int? remoteId;         // null until synced with backend

  final String text;           // question_text in DB
  final QuestionType type;
  final QuestionDifficulty difficulty;
  final QuestionSource source;
  final QuestionApprovalStatus approvalStatus;

  final List<QuestionOption> options; // MC / multi-select
  final String? correctOptionId;      // MC only
  final bool? correctBool;            // true_false
  final String? sampleAnswer;         // short_answer / essay / fill_in_blank
  final String? explanation;
  final String? expectedAnswer;
  final List<String> tags;

  // Statistics (from backend)
  final int usageCount;
  final double? successRate;
  final int maxScore;
  final bool autoGradable;

  // Hierarchy context
  final int? courseId;
  final int? moduleId;
  final String? moduleName;
  final int? materialId;
  final String? materialName;
  final int? topicId;
  final String? topicName;

  final DateTime createdAt;

  const QuestionModel({
    required this.id,
    this.remoteId,
    required this.text,
    required this.type,
    required this.difficulty,
    this.source = QuestionSource.manual,
    this.approvalStatus = QuestionApprovalStatus.approved,
    this.options = const [],
    this.correctOptionId,
    this.correctBool,
    this.sampleAnswer,
    this.explanation,
    this.expectedAnswer,
    this.tags = const [],
    this.usageCount = 0,
    this.successRate,
    this.maxScore = 1,
    this.autoGradable = true,
    this.courseId,
    this.moduleId,
    this.moduleName,
    this.materialId,
    this.materialName,
    this.topicId,
    this.topicName,
    required this.createdAt,
  });

  String get typeLabel => type.label;

  String get difficultyLabel => difficulty.label;

  String get contextLabel {
    if (topicName != null)    return topicName!;
    if (materialName != null) return materialName!;
    if (moduleName != null)   return moduleName!;
    return 'General';
  }

  /// Parse a backend Question row into a QuestionModel.
  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    DateTime dt(dynamic v) =>
        DateTime.tryParse((v ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);


    QuestionSource parseSource(String raw) {
      switch (raw) {
        case 'ai_generated': return QuestionSource.aiGenerated;
        case 'imported':     return QuestionSource.imported;
        default:             return QuestionSource.manual;
      }
    }

    QuestionApprovalStatus parseApproval(String raw) {
      switch (raw) {
        case 'pending':  return QuestionApprovalStatus.pending;
        case 'rejected': return QuestionApprovalStatus.rejected;
        default:         return QuestionApprovalStatus.approved;
      }
    }

    final rawOptions = (json['options'] as List?) ?? const [];
    final options = rawOptions
        .whereType<Map>()
        .map((e) => QuestionOption.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final remoteId = json['id'] == null ? null : (json['id'] as num).toInt();
    final rawTags = (json['tags'] as List?) ?? const [];

    return QuestionModel(
      id: remoteId?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      remoteId: remoteId,
      text: (json['question_text'] ?? '').toString(),
      type: parseQuestionType((json['type'] ?? 'multiple_choice').toString()),
      difficulty: parseQuestionDifficulty((json['difficulty'] ?? 'medium').toString()),
      source: parseSource((json['source'] ?? 'manual').toString()),
      approvalStatus: parseApproval((json['approval_status'] ?? 'approved').toString()),
      options: options,
      explanation: json['explanation']?.toString(),
      expectedAnswer: json['expected_answer']?.toString(),
      tags: rawTags.map((e) => e.toString()).toList(),
      usageCount: (json['usage_count'] as num?)?.toInt() ?? 0,
      successRate: json['success_rate'] == null ? null : (json['success_rate'] as num).toDouble(),
      maxScore: (json['max_score'] as num?)?.toInt() ?? 1,
      autoGradable: (json['auto_gradable'] as bool?) ?? true,
      courseId: json['course_id'] == null ? null : (json['course_id'] as num).toInt(),
      moduleId: json['module_id'] == null ? null : (json['module_id'] as num).toInt(),
      materialId: json['material_id'] == null ? null : (json['material_id'] as num).toInt(),
      topicId: json['topic_id'] == null ? null : (json['topic_id'] as num).toInt(),
      createdAt: dt(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_text': text,
      'type': type.backendValue,
      'difficulty': difficulty.backendValue,
      if (options.isNotEmpty) 'options': options.map((o) => o.toJson()).toList(),
      if (explanation != null) 'explanation': explanation,
      if (expectedAnswer != null) 'expected_answer': expectedAnswer,
      if (tags.isNotEmpty) 'tags': tags,
      if (moduleId != null) 'module_id': moduleId,
      if (materialId != null) 'material_id': materialId,
      if (topicId != null) 'topic_id': topicId,
    };
  }
}

/// Lightweight quiz built from selected questions (in-memory)
class QuizDraft {
  final String id;
  final String title;
  final String? description;
  final List<QuestionModel> questions;
  final int timeLimitMinutes;
  final bool shuffleQuestions;

  const QuizDraft({
    required this.id,
    required this.title,
    this.description,
    this.questions = const [],
    this.timeLimitMinutes = 60,
    this.shuffleQuestions = true,
  });
}
