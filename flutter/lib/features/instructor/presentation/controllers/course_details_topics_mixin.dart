part of 'course_details_controller.dart';



mixin _CourseDetailsTopicsMixin on StateNotifier<CourseDetailsState> {
  Ref get ref;
  int get courseId;
  Future<void> loadMaterials(int moduleId, {bool force = false});
// ── Topics ──────────────────────────────────────────────────────────────

  Future<void> loadTopics(int moduleId, {bool force = false}) async {
    if (state.topicsLoading[moduleId] ?? false) return;
    if (state.topics.containsKey(moduleId) && !force) return;

    final newLoading = Map<int, bool>.from(state.topicsLoading)
      ..[moduleId] = true;
    state = state.copyWith(topicsLoading: newLoading);

    try {
      // Topics are nested under materials — ensure materials are loaded first.
      if ((state.materials[moduleId] ?? const <MaterialItem>[]).isEmpty) {
        await loadMaterials(moduleId, force: force);
      }
      final materials = state.materials[moduleId] ?? const <MaterialItem>[];
      final allTopics = <TopicItem>[];
      for (final mat in materials) {
        final res = await ref.read(topicsApiProvider).listTopics(
              courseId: courseId,
              moduleId: moduleId,
              materialId: mat.id,
            );
        allTopics.addAll(res.topics);
      }

      final sortedTopics = [...allTopics]
        ..sort((a, b) {
          final materialCmp = a.materialId.compareTo(b.materialId);
          if (materialCmp != 0) return materialCmp;
          return a.orderIndex.compareTo(b.orderIndex);
        });

      final newTopics = Map<int, List<TopicItem>>.from(state.topics)
        ..[moduleId] = sortedTopics;
      final newLoad = Map<int, bool>.from(state.topicsLoading)
        ..[moduleId] = false;
      state = state.copyWith(topicsLoading: newLoad, topics: newTopics);
      return;
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(ref, failure);
      final newTopics = Map<int, List<TopicItem>>.from(state.topics)
        ..[moduleId] = const [];
      final newLoad = Map<int, bool>.from(state.topicsLoading)
        ..[moduleId] = false;
      state = state.copyWith(topicsLoading: newLoad, topics: newTopics);
      return;
    }
  }

  Future<TopicItem?> createTopic({
    required int moduleId,
    required int materialId,
    required TopicCreateRequest payload,
  }) async {
    try {
      final topic = await ref.read(topicsApiProvider).createTopic(
            courseId:   courseId,
            moduleId:   moduleId,
            materialId: materialId,
            payload:    payload,
          );
      final existing = List<TopicItem>.from(state.topics[moduleId] ?? []);
      existing.add(topic);
      existing.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      final newTopics = Map<int, List<TopicItem>>.from(state.topics)
        ..[moduleId] = existing;
      state = state.copyWith(topics: newTopics);
      return topic;
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(ref, failure);
      return null;
    }
  }

  Future<void> updateTopic(TopicItem topic) async {
    try {
      final updated = await ref.read(topicsApiProvider).updateTopic(
            courseId:   courseId,
            moduleId:   topic.moduleId,
            materialId: topic.materialId,
            topicId:    topic.id,
            payload:    TopicUpdateRequest(
              title:              topic.title,
              description:        topic.description,
              parentTopicId:      topic.parentTopicId,
              learningOutcomeIds: topic.learningOutcomeIds.isNotEmpty
                  ? topic.learningOutcomeIds
                  : topic.linkedOutcomeIds
                      .map((s) => int.tryParse(s))
                      .whereType<int>()
                      .toList(),
            ),
          );
      final mergedUpdated = updated.copyWith(
        moduleId: topic.moduleId,
        materialId: topic.materialId,
        difficulty: topic.difficulty,
        readiness: topic.readiness,
        linkedOutcomeId: topic.linkedOutcomeId,
        linkedOutcomeIds: topic.linkedOutcomeIds,
        learningOutcomeIds: topic.learningOutcomeIds,
        parentTopicId: topic.parentTopicId,
        instructorNotes: topic.instructorNotes,
        estimatedDurationMinutes: topic.estimatedDurationMinutes,
        isRequired: topic.isRequired,
        source: topic.source,
      );
      final existing = List<TopicItem>.from(state.topics[topic.moduleId] ?? const []);
      final idx = existing.indexWhere((t) => t.id == topic.id);
      if (idx >= 0) {
        existing[idx] = mergedUpdated;
      } else {
        existing.add(mergedUpdated);
      }
      final newTopics = Map<int, List<TopicItem>>.from(state.topics)
        ..[topic.moduleId] = existing;
      state = state.copyWith(topics: newTopics);
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(ref, failure);
    }
  }

  Future<void> deleteTopic({
    required int moduleId,
    required int topicId,
    required int materialId,
  }) async {
    if (materialId <= 0) {
      throw ArgumentError.value(materialId, 'materialId', 'materialId is required for deleting a topic');
    }

    try {
      await ref.read(topicsApiProvider).deleteTopic(
            courseId: courseId,
            moduleId: moduleId,
            materialId: materialId,
            topicId: topicId,
          );
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(ref, failure);
      return;
    }
    final existing = List<TopicItem>.from(state.topics[moduleId] ?? const []);
    final newTopics = Map<int, List<TopicItem>>.from(state.topics)
      ..[moduleId] = existing.where((t) => t.id != topicId).toList();
    state = state.copyWith(topics: newTopics);
  }

  
}
