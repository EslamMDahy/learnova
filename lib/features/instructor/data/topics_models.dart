// ─────────────────────────────────────────────────────────────────────────────
//  Topics — extended models with material context and instructor metadata
// ─────────────────────────────────────────────────────────────────────────────

enum TopicSource { ai, manual }

enum TopicDifficulty { beginner, intermediate, advanced }

enum TopicReadiness { draft, review, ready }

extension TopicDifficultyX on TopicDifficulty {
  String get label {
    switch (this) {
      case TopicDifficulty.beginner:
        return 'Beginner';
      case TopicDifficulty.intermediate:
        return 'Intermediate';
      case TopicDifficulty.advanced:
        return 'Advanced';
    }
  }

  static TopicDifficulty fromString(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'intermediate':
        return TopicDifficulty.intermediate;
      case 'advanced':
        return TopicDifficulty.advanced;
      default:
        return TopicDifficulty.beginner;
    }
  }
}

extension TopicSourceX on TopicSource {
  String get label => this == TopicSource.ai ? 'AI' : 'Manual';

  static TopicSource fromString(String? s) {
    return (s ?? '').toLowerCase() == 'manual'
        ? TopicSource.manual
        : TopicSource.ai;
  }
}

extension TopicReadinessX on TopicReadiness {
  String get label {
    switch (this) {
      case TopicReadiness.draft:
        return 'Draft';
      case TopicReadiness.review:
        return 'Needs Review';
      case TopicReadiness.ready:
        return 'Ready';
    }
  }

  static TopicReadiness fromString(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'ready':
        return TopicReadiness.ready;
      case 'review':
      case 'needs_review':
      case 'needs review':
        return TopicReadiness.review;
      default:
        return TopicReadiness.draft;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TopicItem — mirrors backend TopicListItem / TopicCreateResponse exactly,
// plus UI-only helpers kept for the presentation layer (not sent to backend).
//
// Backend fields: id, material_id, title, description, order_index,
//                 parent_topic_id, is_ai_generated, is_reviewed,
//                 created_at, updated_at
//
// UI-only fields (never serialised to the backend):
//   moduleId, source, difficulty, readiness, linkedOutcomeId,
//   linkedOutcomeIds (String list for UI), learningOutcomeIds (int list for API),
//   instructorNotes, estimatedDurationMinutes, isRequired
// ─────────────────────────────────────────────────────────────────────────────
class TopicItem {
  // ── Backend fields ──────────────────────────────────────────────────────
  final int id;
  final int materialId;
  final String title;
  final String? description;
  final int orderIndex;
  final int? parentTopicId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isAiGenerated;
  final bool isReviewed;

  // ── UI-only helpers ─────────────────────────────────────────────────────
  /// The module this topic belongs to (for local state indexing).
  final int moduleId;

  final TopicSource source;
  final TopicDifficulty difficulty;
  final TopicReadiness readiness;

  /// Single LO id — legacy / UI convenience (String for UI dropdowns).
  final String? linkedOutcomeId;

  /// Multiple LO ids as strings (UI-side representation).
  final List<String> linkedOutcomeIds;

  /// LO ids as ints — used when calling the backend API.
  final List<int> learningOutcomeIds;

  final String? instructorNotes;

  /// UI-only estimated duration (backend doesn't have this field yet).
  final int? estimatedDurationMinutes;

  /// UI-only required flag (backend doesn't have this field yet).
  final bool isRequired;

  const TopicItem({
    required this.id,
    required this.materialId,
    required this.title,
    this.description,
    required this.orderIndex,
    this.parentTopicId,
    required this.createdAt,
    required this.updatedAt,
    this.isAiGenerated = false,
    this.isReviewed = false,
    // UI-only
    this.moduleId = 0,
    this.source = TopicSource.manual,
    this.difficulty = TopicDifficulty.beginner,
    this.readiness = TopicReadiness.draft,
    this.linkedOutcomeId,
    this.linkedOutcomeIds = const [],
    this.learningOutcomeIds = const [],
    this.instructorNotes,
    this.estimatedDurationMinutes,
    this.isRequired = true,
  });

  TopicItem copyWith({
    int? id,
    int? materialId,
    String? title,
    String? description,
    int? orderIndex,
    int? parentTopicId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAiGenerated,
    bool? isReviewed,
    int? moduleId,
    TopicSource? source,
    TopicDifficulty? difficulty,
    TopicReadiness? readiness,
    String? linkedOutcomeId,
    List<String>? linkedOutcomeIds,
    List<int>? learningOutcomeIds,
    String? instructorNotes,
    int? estimatedDurationMinutes,
    bool? isRequired,
  }) {
    return TopicItem(
      id: id ?? this.id,
      materialId: materialId ?? this.materialId,
      title: title ?? this.title,
      description: description ?? this.description,
      orderIndex: orderIndex ?? this.orderIndex,
      parentTopicId: parentTopicId ?? this.parentTopicId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      isReviewed: isReviewed ?? this.isReviewed,
      moduleId: moduleId ?? this.moduleId,
      source: source ?? this.source,
      difficulty: difficulty ?? this.difficulty,
      readiness: readiness ?? this.readiness,
      linkedOutcomeId: linkedOutcomeId ?? this.linkedOutcomeId,
      linkedOutcomeIds: linkedOutcomeIds ?? this.linkedOutcomeIds,
      learningOutcomeIds: learningOutcomeIds ?? this.learningOutcomeIds,
      instructorNotes: instructorNotes ?? this.instructorNotes,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      isRequired: isRequired ?? this.isRequired,
    );
  }

  factory TopicItem.fromJson(Map<String, dynamic> json) {
    DateTime dt(dynamic v) =>
        DateTime.tryParse((v ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);

    // Backend sends learning_outcome_ids as List<int>
    final intOutcomeIds = ((json['learning_outcome_ids'] as List?) ?? const [])
        .map((e) => (e as num).toInt())
        .toList();

    // Derive UI string list from the int list
    final strOutcomeIds = intOutcomeIds.map((e) => e.toString()).toList();

    final isAi = (json['is_ai_generated'] as bool?) ?? false;

    return TopicItem(
      id: (json['id'] as num).toInt(),
      materialId: (json['material_id'] as num).toInt(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
      parentTopicId: json['parent_topic_id'] == null
          ? null
          : (json['parent_topic_id'] as num).toInt(),
      createdAt: dt(json['created_at']),
      updatedAt: dt(json['updated_at']),
      isAiGenerated: isAi,
      isReviewed: (json['is_reviewed'] as bool?) ?? false,
      // UI-only
      source: isAi ? TopicSource.ai : TopicSource.manual,
      learningOutcomeIds: intOutcomeIds,
      linkedOutcomeIds: strOutcomeIds,
      linkedOutcomeId: strOutcomeIds.isNotEmpty ? strOutcomeIds.first : null,
      readiness: (json['is_reviewed'] as bool? ?? false)
          ? TopicReadiness.ready
          : TopicReadiness.draft,
    );
  }

  /// Serialise only the backend-relevant fields for logging / caching.
  Map<String, dynamic> toJson() => {
        'id': id,
        'material_id': materialId,
        'title': title,
        if (description != null) 'description': description,
        'order_index': orderIndex,
        if (parentTopicId != null) 'parent_topic_id': parentTopicId,
        'is_ai_generated': isAiGenerated,
        'is_reviewed': isReviewed,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        if (learningOutcomeIds.isNotEmpty)
          'learning_outcome_ids': learningOutcomeIds,
        // UI-only fields — kept so mock_services can round-trip through JSON
        'module_id': moduleId,
        'source': source.name,
        'difficulty': difficulty.name,
        'readiness': readiness.name,
        if (linkedOutcomeId != null) 'linked_outcome_id': linkedOutcomeId,
        if (linkedOutcomeIds.isNotEmpty) 'linked_outcome_ids': linkedOutcomeIds,
        if (instructorNotes != null) 'instructor_notes': instructorNotes,
        if (estimatedDurationMinutes != null)
          'estimated_duration_minutes': estimatedDurationMinutes,
        'is_required': isRequired,
      };
}

// ─── List response ────────────────────────────────────────────────────────────
class TopicListResponse {
  final int courseId;
  final int moduleId;
  final int materialId;
  final List<TopicItem> topics;

  const TopicListResponse({
    required this.courseId,
    required this.moduleId,
    required this.materialId,
    required this.topics,
  });

  factory TopicListResponse.fromJson(Map<String, dynamic> json) {
    final raw = (json['topics'] as List?) ?? const [];
    return TopicListResponse(
      courseId: (json['course_id'] as num).toInt(),
      moduleId: (json['module_id'] as num).toInt(),
      materialId: (json['material_id'] as num).toInt(),
      topics: raw
          .whereType<Map>()
          .map((e) => TopicItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

// ─── Reorder response ─────────────────────────────────────────────────────────
class TopicReorderResponse {
  final int courseId;
  final int moduleId;
  final int materialId;
  final List<int> topicIds;

  const TopicReorderResponse({
    required this.courseId,
    required this.moduleId,
    required this.materialId,
    required this.topicIds,
  });

  factory TopicReorderResponse.fromJson(Map<String, dynamic> json) {
    return TopicReorderResponse(
      courseId: (json['course_id'] as num).toInt(),
      moduleId: (json['module_id'] as num).toInt(),
      materialId: (json['material_id'] as num).toInt(),
      topicIds: ((json['topic_ids'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }
}

// ─── Create request ───────────────────────────────────────────────────────────
// What gets SENT to backend: title, description, parent_topic_id, learning_outcome_ids
// UI-only fields (source, difficulty, linkedOutcomeId, linkedOutcomeIds) are
// kept so the presentation layer can build the object without changes.
class TopicCreateRequest {
  final String title;
  final String? description;
  final int? parentTopicId;

  // UI-only (not sent to backend directly — learningOutcomeIds is sent instead)
  final TopicSource source;
  final TopicDifficulty difficulty;
  final String? linkedOutcomeId;
  final List<String> linkedOutcomeIds;

  // Backend field: int ids derived from linkedOutcomeIds when calling the API
  final List<int> learningOutcomeIds;

  const TopicCreateRequest({
    required this.title,
    this.description,
    this.parentTopicId,
    this.source = TopicSource.manual,
    this.difficulty = TopicDifficulty.beginner,
    this.linkedOutcomeId,
    this.linkedOutcomeIds = const [],
    this.learningOutcomeIds = const [],
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'title': title};
    if (description != null && description!.trim().isNotEmpty) {
      m['description'] = description;
    }
    if (parentTopicId != null) m['parent_topic_id'] = parentTopicId;
    // Send int outcome ids to backend (prefer explicit learningOutcomeIds,
    // fall back to parsing linkedOutcomeIds strings if int list is empty)
    final ids = learningOutcomeIds.isNotEmpty
        ? learningOutcomeIds
        : linkedOutcomeIds
            .map((s) => int.tryParse(s))
            .whereType<int>()
            .toList();
    if (ids.isNotEmpty) m['learning_outcome_ids'] = ids;
    return m;
  }
}

// ─── Update request ───────────────────────────────────────────────────────────
// Backend accepts: title, description, parent_topic_id, learning_outcome_ids (all optional)
class TopicUpdateRequest {
  final String? title;
  final String? description;
  final int? parentTopicId;
  final List<int>? learningOutcomeIds;

  const TopicUpdateRequest({
    this.title,
    this.description,
    this.parentTopicId,
    this.learningOutcomeIds,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (title != null) m['title'] = title;
    if (description != null) m['description'] = description;
    if (parentTopicId != null) m['parent_topic_id'] = parentTopicId;
    if (learningOutcomeIds != null) m['learning_outcome_ids'] = learningOutcomeIds;
    return m;
  }
}

// ─── Get single response ──────────────────────────────────────────────────────
// Backend returns the topic plus its linked learning outcomes.
class TopicLinkedOutcome {
  final int id;
  final String title;
  const TopicLinkedOutcome({required this.id, required this.title});

  factory TopicLinkedOutcome.fromJson(Map<String, dynamic> json) =>
      TopicLinkedOutcome(
        id:    (json['id'] as num).toInt(),
        title: json['title']?.toString() ?? '',
      );
}

class TopicGetResponse {
  final TopicItem topic;
  final List<TopicLinkedOutcome> learningOutcomes;

  const TopicGetResponse({required this.topic, required this.learningOutcomes});

  factory TopicGetResponse.fromJson(Map<String, dynamic> json) {
    final raw = (json['learning_outcomes'] as List?) ?? const [];
    return TopicGetResponse(
      topic: TopicItem.fromJson(json),
      learningOutcomes: raw
          .whereType<Map>()
          .map((e) => TopicLinkedOutcome.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
