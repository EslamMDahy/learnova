import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import 'exams_api.dart';
import 'question_models.dart';
import 'question_vocabulary.dart';

class ExamTemplateSectionModel {
  final int? id;
  final int? templateId;
  final String title;
  final String questionType;
  final int questionCount;
  final double pointsPerQuestion;
  final double sectionScore;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExamTemplateSectionModel({
    this.id,
    this.templateId,
    required this.title,
    required this.questionType,
    required this.questionCount,
    required this.pointsPerQuestion,
    required this.sectionScore,
    required this.orderIndex,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExamTemplateSectionModel.fromJson(Map<String, dynamic> json) {
    final questionCount = _nullableInt(json['question_count']) ?? 0;
    final pointsPerQuestion = _nullableDouble(json['points_per_question']) ?? 1;
    return ExamTemplateSectionModel(
      id: _nullableInt(json['id']),
      templateId: _nullableInt(json['template_id']),
      title: (json['title'] ?? 'Questions').toString(),
      questionType: (json['question_type'] ?? 'multiple_choice').toString(),
      questionCount: questionCount,
      pointsPerQuestion: pointsPerQuestion,
      sectionScore: _nullableDouble(json['section_score']) ?? questionCount * pointsPerQuestion,
      orderIndex: _nullableInt(json['order_index']) ?? 1,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }
}

class ExamTemplateModel {
  final String id;
  final int courseId;
  final String name;
  final String description;
  final String examType;
  final int questionCount;
  final int durationMinutes;
  final int maxAttempts;
  final double passingScore;
  final bool shuffleQuestions;
  final bool shuffleAnswers;
  final bool showResultImmediately;
  final bool allowReview;
  final bool publishAfterSave;
  final bool isDefault;
  final QuestionType? preferredType;
  final QuestionDifficulty? preferredDifficulty;
  final String instructions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ExamTemplateSectionModel> sections;

  const ExamTemplateModel({
    required this.id,
    required this.courseId,
    required this.name,
    required this.description,
    required this.examType,
    required this.questionCount,
    required this.durationMinutes,
    required this.maxAttempts,
    required this.passingScore,
    required this.shuffleQuestions,
    required this.shuffleAnswers,
    required this.showResultImmediately,
    required this.allowReview,
    required this.publishAfterSave,
    this.isDefault = false,
    this.preferredType,
    this.preferredDifficulty,
    required this.instructions,
    required this.createdAt,
    required this.updatedAt,
    this.sections = const [],
  });

  bool get isCustom => id == 'custom';
  bool get isLocalDraft => isCustom || id.startsWith('new-') || id.startsWith('draft-') || id.startsWith('local-');

  int? get backendId {
    if (isLocalDraft) return null;
    final parsed = int.tryParse(id);
    if (parsed == null) return null;
    // Local drafts in older builds were generated from microsecondsSinceEpoch.
    // Treat those large timestamp-like ids as unsaved templates so saving uses POST, not PATCH.
    if (parsed >= 1000000000000) return null;
    return parsed;
  }

  List<ExamTemplateSectionModel> get distributionSections {
    final active = sections.where((section) => section.questionCount > 0).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    if (active.isNotEmpty) return active;

    final preferred = preferredType;
    if (preferred == null) return const <ExamTemplateSectionModel>[];

    final questionType = preferred.backendValue;
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    return [
      ExamTemplateSectionModel(
        title: _sectionTitle(questionType),
        questionType: questionType,
        questionCount: questionCount,
        pointsPerQuestion: 1,
        sectionScore: questionCount.toDouble(),
        orderIndex: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  ExamTemplateModel copyWith({
    String? id,
    int? courseId,
    String? name,
    String? description,
    String? examType,
    int? questionCount,
    int? durationMinutes,
    int? maxAttempts,
    double? passingScore,
    bool? shuffleQuestions,
    bool? shuffleAnswers,
    bool? showResultImmediately,
    bool? allowReview,
    bool? publishAfterSave,
    bool? isDefault,
    QuestionType? preferredType,
    QuestionDifficulty? preferredDifficulty,
    bool clearPreferredType = false,
    bool clearPreferredDifficulty = false,
    String? instructions,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ExamTemplateSectionModel>? sections,
  }) {
    return ExamTemplateModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      name: name ?? this.name,
      description: description ?? this.description,
      examType: examType ?? this.examType,
      questionCount: questionCount ?? this.questionCount,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      passingScore: passingScore ?? this.passingScore,
      shuffleQuestions: shuffleQuestions ?? this.shuffleQuestions,
      shuffleAnswers: shuffleAnswers ?? this.shuffleAnswers,
      showResultImmediately: showResultImmediately ?? this.showResultImmediately,
      allowReview: allowReview ?? this.allowReview,
      publishAfterSave: publishAfterSave ?? this.publishAfterSave,
      isDefault: isDefault ?? this.isDefault,
      preferredType: clearPreferredType ? null : preferredType ?? this.preferredType,
      preferredDifficulty: clearPreferredDifficulty ? null : preferredDifficulty ?? this.preferredDifficulty,
      instructions: instructions ?? this.instructions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sections: sections ?? this.sections,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'course_id': courseId,
        'name': name,
        'description': description,
        'exam_type': examType,
        'question_count': questionCount,
        'duration_minutes': durationMinutes,
        'max_attempts': maxAttempts,
        'passing_score': passingScore,
        'shuffle_questions': shuffleQuestions,
        'shuffle_answers': shuffleAnswers,
        'shuffle_options': shuffleAnswers,
        'show_result_immediately': showResultImmediately,
        'allow_review': allowReview,
        'publish_after_save': publishAfterSave,
        'is_default': isDefault,
        'preferred_type': preferredType?.backendValue,
        'preferred_difficulty': preferredDifficulty?.backendValue,
        'instructions': instructions,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sections': sections.map((section) => {
              if (section.id != null) 'id': section.id,
              if (section.templateId != null) 'template_id': section.templateId,
              'title': section.title,
              'question_type': section.questionType,
              'question_count': section.questionCount,
              'points_per_question': section.pointsPerQuestion,
              'section_score': section.sectionScore,
              'order_index': section.orderIndex,
              'created_at': section.createdAt.toIso8601String(),
              'updated_at': section.updatedAt.toIso8601String(),
            }).toList(),
      };

  Map<String, dynamic> toBackendPayload() {
    return {
      'name': name,
      'exam_type': examType,
      'duration_minutes': durationMinutes > 0 ? durationMinutes : null,
      'max_attempts': maxAttempts,
      'passing_score': passingScore,
      'shuffle_questions': shuffleQuestions,
      'shuffle_options': shuffleAnswers,
    }..removeWhere((_, value) => value == null);
  }

  factory ExamTemplateModel.fromJson(Map<String, dynamic> json) {
    final rawSections = (json['sections'] as List?) ?? const [];
    final sections = rawSections
        .whereType<Map>()
        .map((item) => ExamTemplateSectionModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    sections.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final sectionsQuestionCount = sections.fold<int>(0, (sum, section) => sum + section.questionCount);
    final rawPreferredType = json['preferred_type']?.toString() ?? (sections.length == 1 ? sections.first.questionType : null);

    return ExamTemplateModel(
      id: (json['id'] ?? '').toString(),
      courseId: _nullableInt(json['course_id']) ?? 0,
      name: (json['name'] ?? 'Untitled template').toString(),
      description: (json['description'] ?? '').toString(),
      examType: (json['exam_type'] ?? 'quiz').toString(),
      questionCount: sectionsQuestionCount > 0
          ? sectionsQuestionCount
          : _nullableInt(json['question_count']) ??
              _nullableInt(json['total_questions']) ??
              10,
      durationMinutes: _nullableInt(json['duration_minutes']) ?? 60,
      maxAttempts: _nullableInt(json['max_attempts']) ?? 1,
      passingScore: _nullableDouble(json['passing_score']) ?? 60,
      shuffleQuestions: (json['shuffle_questions'] as bool?) ?? true,
      shuffleAnswers: (json['shuffle_options'] as bool?) ?? (json['shuffle_answers'] as bool?) ?? false,
      showResultImmediately: (json['show_result_immediately'] as bool?) ?? true,
      allowReview: (json['allow_review'] as bool?) ?? true,
      publishAfterSave: (json['publish_after_save'] as bool?) ?? false,
      isDefault: (json['is_default'] as bool?) ?? false,
      preferredType: _questionTypeFromBackend(rawPreferredType),
      preferredDifficulty: _difficultyFromBackend(json['preferred_difficulty']?.toString()),
      instructions: (json['instructions'] ?? '').toString(),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      sections: sections,
    );
  }

  static ExamTemplateModel custom(int courseId) {
    final now = DateTime.now();
    return ExamTemplateModel(
      id: 'custom',
      courseId: courseId,
      name: 'Custom exam',
      description: 'Start from scratch with manual settings.',
      examType: 'quiz',
      questionCount: 10,
      durationMinutes: 60,
      maxAttempts: 1,
      passingScore: 60,
      shuffleQuestions: true,
      shuffleAnswers: false,
      showResultImmediately: true,
      allowReview: true,
      publishAfterSave: false,
      instructions: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  static ExamTemplateModel quickQuiz(int courseId) {
    final now = DateTime.now();
    return ExamTemplateModel(
      id: 'quick_quiz',
      courseId: courseId,
      name: 'Quick quiz',
      description: 'Short formative check with lightweight grading.',
      examType: 'quiz',
      questionCount: 10,
      durationMinutes: 20,
      maxAttempts: 2,
      passingScore: 60,
      shuffleQuestions: true,
      shuffleAnswers: true,
      showResultImmediately: true,
      allowReview: true,
      publishAfterSave: false,
      preferredType: QuestionType.multipleChoice,
      instructions: 'Answer all questions. You may retry based on the attempt limit.',
      createdAt: now,
      updatedAt: now,
    );
  }

  static ExamTemplateModel midterm(int courseId) {
    final now = DateTime.now();
    return ExamTemplateModel(
      id: 'midterm',
      courseId: courseId,
      name: 'Midterm',
      description: 'Balanced checkpoint covering selected course scope.',
      examType: 'midterm',
      questionCount: 25,
      durationMinutes: 90,
      maxAttempts: 1,
      passingScore: 60,
      shuffleQuestions: true,
      shuffleAnswers: true,
      showResultImmediately: false,
      allowReview: true,
      publishAfterSave: false,
      instructions: 'Read each question carefully. Submit before the timer ends.',
      createdAt: now,
      updatedAt: now,
    );
  }

  static ExamTemplateModel finalExam(int courseId) {
    final now = DateTime.now();
    return ExamTemplateModel(
      id: 'final_exam',
      courseId: courseId,
      name: 'Final exam',
      description: 'Higher-stakes exam with stricter visibility defaults.',
      examType: 'final',
      questionCount: 40,
      durationMinutes: 120,
      maxAttempts: 1,
      passingScore: 65,
      shuffleQuestions: true,
      shuffleAnswers: true,
      showResultImmediately: false,
      allowReview: false,
      publishAfterSave: false,
      instructions: 'This exam is timed. Make sure your connection is stable before starting.',
      createdAt: now,
      updatedAt: now,
    );
  }

  static List<ExamTemplateModel> defaults(int courseId) => [
        custom(courseId),
        quickQuiz(courseId),
        midterm(courseId),
        finalExam(courseId),
      ];
}

QuestionType? _questionTypeFromBackend(String? raw) {
  switch ((raw ?? '').trim()) {
    case 'multiple_choice':
      return QuestionType.multipleChoice;
    case 'true_false':
      return QuestionType.trueFalse;
    case 'short_answer':
      return QuestionType.shortAnswer;
    case 'essay':
      return QuestionType.essay;
    case 'multi_select':
      return QuestionType.multiSelect;
    case 'fill_in_blank':
    case 'fill_in_the_blank':
      return QuestionType.fillInTheBlank;
    case 'numeric':
      return QuestionType.numeric;
    case 'code':
      return QuestionType.code;
  }
  return null;
}

QuestionDifficulty? _difficultyFromBackend(String? raw) {
  switch ((raw ?? '').trim()) {
    case 'easy':
      return QuestionDifficulty.easy;
    case 'medium':
      return QuestionDifficulty.medium;
    case 'hard':
      return QuestionDifficulty.hard;
  }
  return null;
}

class ExamTemplatesStorage {
  ExamTemplatesStorage({required ExamsApi api}) : _api = api;

  final ExamsApi _api;

  Future<List<ExamTemplateModel>> load(int courseId) async {
    final raw = await _api.listExamTemplatesRaw(courseId: courseId);
    final rows = (raw['templates'] as List?) ?? const [];
    final templates = <ExamTemplateModel>[];

    for (final row in rows.whereType<Map>()) {
      final item = Map<String, dynamic>.from(row);
      final id = _nullableInt(item['id']);
      if (id == null) continue;
      try {
        final details = await _api.getExamTemplateRaw(courseId: courseId, templateId: id);
        templates.add(ExamTemplateModel.fromJson({...details, 'course_id': courseId}));
      } catch (_) {
        templates.add(ExamTemplateModel.fromJson({...item, 'course_id': courseId}));
      }
    }

    return [ExamTemplateModel.custom(courseId), ...templates];
  }

  Future<void> saveAll(int courseId, List<ExamTemplateModel> templates) async {
    await load(courseId);
  }

  Future<List<ExamTemplateModel>> upsert(int courseId, ExamTemplateModel template) async {
    final templateId = template.backendId;
    final Map<String, dynamic> rawSaved;

    if (template.isCustom || templateId == null) {
      rawSaved = await _api.createExamTemplateRaw(
        courseId: courseId,
        payload: template.copyWith(courseId: courseId).toBackendPayload(),
      );
    } else {
      rawSaved = await _api.updateExamTemplateRaw(
        courseId: courseId,
        templateId: templateId,
        payload: template.copyWith(courseId: courseId).toBackendPayload(),
      );
    }

    final saved = ExamTemplateModel.fromJson({...rawSaved, 'course_id': courseId});
    final savedId = saved.backendId;
    if (savedId != null) {
      var currentSections = saved.sections;
      try {
        final details = await _api.getExamTemplateRaw(courseId: courseId, templateId: savedId);
        currentSections = ExamTemplateModel.fromJson({...details, 'course_id': courseId}).sections;
      } catch (_) {
        // Use the save response sections when the details endpoint is unavailable.
      }
      await _syncTemplateSections(
        courseId: courseId,
        templateId: savedId,
        currentSections: currentSections,
        desired: template,
      );
    }
    return load(courseId);
  }

  Future<List<ExamTemplateModel>> delete(int courseId, String templateId) async {
    final id = int.tryParse(templateId);
    if (id == null) return load(courseId);
    await _api.deleteExamTemplateRaw(courseId: courseId, templateId: id);
    return load(courseId);
  }

  Future<void> _syncTemplateSections({
    required int courseId,
    required int templateId,
    required List<ExamTemplateSectionModel> currentSections,
    required ExamTemplateModel desired,
  }) async {
    final desiredSections = _desiredTemplateSections(desired);
    final current = currentSections.where((section) => section.id != null).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final usedCurrentIds = <int>{};

    for (var i = 0; i < desiredSections.length; i++) {
      final desiredSection = desiredSections[i];
      final questionType = _normalizeTemplateQuestionType(desiredSection.questionType);
      final payload = {
        'title': desiredSection.title.trim().isNotEmpty ? desiredSection.title.trim() : _sectionTitle(questionType),
        'question_type': questionType,
        'question_count': desiredSection.questionCount,
        'points_per_question': desiredSection.pointsPerQuestion > 0 ? desiredSection.pointsPerQuestion : 1.0,
      };

      final matchingCurrent = _matchingCurrentSection(
        desiredSection: desiredSection,
        currentSections: current,
        usedIds: usedCurrentIds,
        fallbackIndex: i,
      );
      final sectionId = matchingCurrent?.id;

      if (sectionId == null) {
        final created = await _api.createExamTemplateSectionRaw(
          courseId: courseId,
          templateId: templateId,
          payload: payload,
        );
        final createdId = _nullableInt(created['id']);
        if (createdId != null) usedCurrentIds.add(createdId);
      } else {
        usedCurrentIds.add(sectionId);
        await _api.updateExamTemplateSectionRaw(
          courseId: courseId,
          templateId: templateId,
          sectionId: sectionId,
          payload: payload,
        );
      }
    }

    for (final section in current) {
      final sectionId = section.id;
      if (sectionId == null || usedCurrentIds.contains(sectionId)) continue;
      await _api.deleteExamTemplateSectionRaw(
        courseId: courseId,
        templateId: templateId,
        sectionId: sectionId,
      );
    }
  }
}

ExamTemplateSectionModel? _matchingCurrentSection({
  required ExamTemplateSectionModel desiredSection,
  required List<ExamTemplateSectionModel> currentSections,
  required Set<int> usedIds,
  required int fallbackIndex,
}) {
  final desiredId = desiredSection.id;
  if (desiredId != null) {
    for (final section in currentSections) {
      if (section.id == desiredId && !usedIds.contains(desiredId)) return section;
    }
  }

  for (final section in currentSections) {
    final id = section.id;
    if (id == null || usedIds.contains(id)) continue;
    if (_normalizeTemplateQuestionType(section.questionType) == _normalizeTemplateQuestionType(desiredSection.questionType)) {
      return section;
    }
  }

  if (fallbackIndex < currentSections.length) {
    final section = currentSections[fallbackIndex];
    final id = section.id;
    if (id != null && !usedIds.contains(id)) return section;
  }

  return null;
}

List<ExamTemplateSectionModel> _desiredTemplateSections(ExamTemplateModel desired) {
  final now = DateTime.now();
  final source = desired.sections.isNotEmpty ? desired.sections : desired.distributionSections;
  final result = <ExamTemplateSectionModel>[];

  for (final section in source) {
    if (section.questionCount <= 0) continue;
    final questionType = _normalizeTemplateQuestionType(section.questionType);
    final pointsPerQuestion = section.pointsPerQuestion > 0 ? section.pointsPerQuestion : 1.0;
    result.add(ExamTemplateSectionModel(
      id: section.id,
      templateId: section.templateId,
      title: section.title.trim().isNotEmpty ? section.title.trim() : _sectionTitle(questionType),
      questionType: questionType,
      questionCount: section.questionCount,
      pointsPerQuestion: pointsPerQuestion,
      sectionScore: section.questionCount * pointsPerQuestion,
      orderIndex: result.length + 1,
      createdAt: section.createdAt,
      updatedAt: now,
    ));
  }

  if (result.isNotEmpty) return result;

  final questionType = _backendTemplateQuestionType(desired.preferredType);
  final count = desired.questionCount > 0 ? desired.questionCount : 1;
  return [
    ExamTemplateSectionModel(
      title: _sectionTitle(questionType),
      questionType: questionType,
      questionCount: count,
      pointsPerQuestion: 1,
      sectionScore: count.toDouble(),
      orderIndex: 1,
      createdAt: now,
      updatedAt: now,
    ),
  ];
}

String _normalizeTemplateQuestionType(String raw) {
  switch (raw.trim()) {
    case 'true_false':
      return 'true_false';
    case 'short_answer':
      return 'short_answer';
    case 'essay':
      return 'essay';
    case 'multi_select':
      return 'multi_select';
    default:
      return 'multiple_choice';
  }
}

final examTemplatesStorageProvider = Provider<ExamTemplatesStorage>((ref) {
  return ExamTemplatesStorage(api: ExamsApi(ref.read(apiClientProvider)));
});

String _backendTemplateQuestionType(QuestionType? type) {
  switch (type) {
    case QuestionType.multipleChoice:
      return 'multiple_choice';
    case QuestionType.trueFalse:
      return 'true_false';
    case QuestionType.shortAnswer:
      return 'short_answer';
    case QuestionType.essay:
      return 'essay';
    case QuestionType.multiSelect:
      return 'multi_select';
    case QuestionType.fillInTheBlank:
    case QuestionType.numeric:
    case QuestionType.code:
    case null:
      return 'multiple_choice';
  }
}

String _sectionTitle(String questionType) {
  switch (questionType) {
    case 'true_false':
      return 'True / False Questions';
    case 'short_answer':
      return 'Short Answer Questions';
    case 'essay':
      return 'Essay Questions';
    case 'multi_select':
      return 'Multi-Select Questions';
    default:
      return 'Multiple Choice Questions';
  }
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
  return DateTime.tryParse((value ?? '').toString()) ?? DateTime.now();
}
