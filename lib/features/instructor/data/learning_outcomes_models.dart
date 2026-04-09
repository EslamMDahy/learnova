// ─────────────────────────────────────────────────────────────────────────────
//  Learning Outcomes — data models aligned with backend schema
//
//  Backend (POST/PATCH request):  title, description?, level, topic_ids?
//  Backend (response):            id(int), course_id, title, description?,
//                                 level, is_ai_generated, is_reviewed,
//                                 created_at, updated_at
//
//  UI-only helpers (never sent to backend):
//    code       — derived from list index ("LO1", "LO2", …)
//    difficulty — mapped from level string for display
// ─────────────────────────────────────────────────────────────────────────────

enum OutcomeDifficulty { beginner, intermediate, advanced }

extension OutcomeDifficultyX on OutcomeDifficulty {
  String get label {
    switch (this) {
      case OutcomeDifficulty.beginner:     return 'Beginner';
      case OutcomeDifficulty.intermediate: return 'Intermediate';
      case OutcomeDifficulty.advanced:     return 'Advanced';
    }
  }

  /// The string the backend expects for the "level" field.
  String get backendLevel {
    switch (this) {
      case OutcomeDifficulty.beginner:     return 'beginner';
      case OutcomeDifficulty.intermediate: return 'intermediate';
      case OutcomeDifficulty.advanced:     return 'advanced';
    }
  }

  static OutcomeDifficulty fromString(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'intermediate': return OutcomeDifficulty.intermediate;
      case 'advanced':     return OutcomeDifficulty.advanced;
      default:             return OutcomeDifficulty.beginner;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class LearningOutcome {
  // ── Backend fields ────────────────────────────────────────────────────────
  final int    id;          // int on the backend
  final int?   courseId;
  final String title;       // backend field name is "title"
  final String? description;
  final bool   isAiGenerated;
  final bool   isReviewed;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── UI-only helpers (not sent to the backend) ─────────────────────────────
  final String           code;       // e.g. "LO1"
  final OutcomeDifficulty difficulty; // derived from level

  const LearningOutcome({
    required this.id,
    this.courseId,
    required this.title,
    this.description,
    this.isAiGenerated = false,
    this.isReviewed    = false,
    this.createdAt,
    this.updatedAt,
    this.code       = '',
    this.difficulty = OutcomeDifficulty.beginner,
  });

  LearningOutcome copyWith({
    int?              id,
    int?              courseId,
    String?           title,
    String?           description,
    bool?             isAiGenerated,
    bool?             isReviewed,
    DateTime?         createdAt,
    DateTime?         updatedAt,
    String?           code,
    OutcomeDifficulty? difficulty,
  }) =>
      LearningOutcome(
        id:            id            ?? this.id,
        courseId:      courseId      ?? this.courseId,
        title:         title         ?? this.title,
        description:   description   ?? this.description,
        isAiGenerated: isAiGenerated ?? this.isAiGenerated,
        isReviewed:    isReviewed    ?? this.isReviewed,
        createdAt:     createdAt     ?? this.createdAt,
        updatedAt:     updatedAt     ?? this.updatedAt,
        code:          code          ?? this.code,
        difficulty:    difficulty    ?? this.difficulty,
      );

  // ── Serialisation ─────────────────────────────────────────────────────────

  /// Payload for POST /courses/{id}/learning-outcomes
  Map<String, dynamic> toCreateJson({List<int>? topicIds}) {
    final m = <String, dynamic>{
      'title': title,
      'level': difficulty.backendLevel,
    };
    if (description != null && description!.trim().isNotEmpty) {
      m['description'] = description!.trim();
    }
    if (topicIds != null && topicIds.isNotEmpty) {
      m['topic_ids'] = topicIds;
    }
    return m;
  }

  /// Payload for PATCH /courses/{id}/learning-outcomes/{lo_id}/update
  /// All fields are optional on the backend.
  Map<String, dynamic> toUpdateJson({List<int>? topicIds}) {
    final m = <String, dynamic>{
      'title': title,
      'level': difficulty.backendLevel,
    };
    if (description != null) m['description'] = description;
    if (topicIds != null)     m['topic_ids']   = topicIds;
    return m;
  }

  /// Full JSON — used for local (mock) round-trip storage only.
  Map<String, dynamic> toJson() => {
    'id':              id,
    'course_id':       courseId,
    'title':           title,
    'description':     description,
    'level':           difficulty.backendLevel,
    'is_ai_generated': isAiGenerated,
    'is_reviewed':     isReviewed,
    'created_at':      createdAt?.toIso8601String(),
    'updated_at':      updatedAt?.toIso8601String(),
    // UI-only
    'code':            code,
  };

  factory LearningOutcome.fromJson(Map<String, dynamic> json) {
    // id — int from backend, may be stored as string in local mock
    final rawId = json['id'];
    final id = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '') ?? 0;

    // level (backend) or legacy difficulty key (local mock)
    final level = json['level']?.toString() ?? json['difficulty']?.toString();

    return LearningOutcome(
      id:            id,
      courseId:      json['course_id'] == null
          ? null
          : (json['course_id'] as num).toInt(),
      title:         json['title']?.toString() ?? '',
      description:   json['description']?.toString(),
      isAiGenerated: (json['is_ai_generated'] as bool?) ?? false,
      isReviewed:    (json['is_reviewed']     as bool?) ?? false,
      createdAt:     json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
      updatedAt:     json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'].toString()),
      code:          json['code']?.toString() ?? '',
      difficulty:    OutcomeDifficultyX.fromString(level),
    );
  }

  static String codeForIndex(int idx) => 'LO${idx + 1}';
}

// ─────────────────────────────────────────────────────────────────────────────
//  Response wrappers
// ─────────────────────────────────────────────────────────────────────────────

class LearningOutcomeListResponse {
  final int courseId;
  final List<LearningOutcome> outcomes;

  const LearningOutcomeListResponse({
    required this.courseId,
    required this.outcomes,
  });

  factory LearningOutcomeListResponse.fromJson(Map<String, dynamic> json) {
    final raw = (json['learning_outcomes'] as List?) ?? const [];
    final items = raw
        .whereType<Map>()
        .map((e) => LearningOutcome.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    // Assign auto-generated LO codes based on position
    for (var i = 0; i < items.length; i++) {
      items[i] = items[i].copyWith(code: LearningOutcome.codeForIndex(i));
    }

    return LearningOutcomeListResponse(
      courseId: (json['course_id'] as num).toInt(),
      outcomes: items,
    );
  }
}
