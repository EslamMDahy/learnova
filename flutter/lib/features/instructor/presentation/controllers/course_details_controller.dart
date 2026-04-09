import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_error_bus.dart';
import '../../../../core/network/error_mapper.dart';

import '../../data/modules_models.dart';
import '../../data/materials_models.dart';
import '../../data/topics_models.dart';
import '../../data/question_models.dart';
import '../../data/mock_services.dart';
import '../../data/modules_materials_providers.dart';

import 'course_details_state.dart';

final courseDetailsControllerProvider = StateNotifierProvider
    .family<CourseDetailsController, CourseDetailsState, int>(
  (ref, courseId) => CourseDetailsController(ref, courseId),
);

class CourseDetailsController extends StateNotifier<CourseDetailsState> {
  CourseDetailsController(this._ref, this._courseId)
      : super(const CourseDetailsState());

  final Ref _ref;
  final int _courseId;
  CancelToken? _cancel;

  // ── Modules ──────────────────────────────────────────────────────────────

  Future<void> loadModules({bool force = false}) async {
    if (state.modulesLoading) return;
    if (state.modules.isNotEmpty && !force) return;
    _cancel?.cancel();
    _cancel = CancelToken();

    state = state.copyWith(modulesLoading: true);

    try {
      final res = await _ref.read(modulesApiProvider).listModules(
            courseId: _courseId,
            cancelToken: _cancel,
          );
      state = state.copyWith(modulesLoading: false, modules: res.modules);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      final failure = mapApiFailure(e);
      AppErrorReporter.report(_ref, failure);
      state = state.copyWith(modulesLoading: false, modulesError: failure.message);
    }
  }

  /// Loads modules then eagerly loads materials + topics for all modules so
  /// Overview statistics are immediately available.
  Future<void> loadModulesAndAllMaterials({bool force = false}) async {
    await loadModules(force: force);
    final modulesToLoad = state.modules
        .where((m) => force || !state.materials.containsKey(m.id) || !state.topics.containsKey(m.id))
        .toList();

    for (final module in modulesToLoad) {
      await loadMaterials(module.id, force: force);
      await loadTopics(module.id, force: force);
    }
  }

  Future<ModuleItem?> createModule(String title, {String? description}) async {
    try {
      final module = await _ref.read(modulesApiProvider).createModule(
            courseId: _courseId,
            payload: ModuleCreateRequest(title: title, description: description),
          );
      state = state.copyWith(modules: [...state.modules, module]);
      return module;
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(_ref, failure);
      return null;
    }
  }

  /// Copies [moduleId] from [sourceCourseId] into [targetCourseId].
  ///
  /// - [sourceCourseId]: the course the module currently lives in.
  /// - [moduleId]: the id of the module to copy.
  /// - [targetCourseId]: where the copy should land (defaults to this course).
  ///
  /// Bug fix: previously [sourceCourseId] was ignored and [targetCourseId] was
  /// sent as the URL course id, meaning the API received a module id that had
  /// no relation to the destination course and returned a 404 / wrong result.
  Future<ModuleItem?> copyModule({
    required int sourceCourseId,
    required int moduleId,
    int? targetCourseId,
  }) async {
    final destinationCourseId = targetCourseId ?? _courseId;
    try {
      final copied = await _ref.read(modulesApiProvider).copyModule(
            sourceCourseId: sourceCourseId,
            moduleId: moduleId,
            targetCourseId: destinationCourseId,
          );
      if (destinationCourseId == _courseId) {
        final nextModules = [...state.modules, copied]
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        state = state.copyWith(modules: nextModules);
      }
      return copied;
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(_ref, failure);
      return null;
    }
  }

  Future<ModuleItem?> updateModule({
    required int moduleId,
    String? title,
    String? description,
    bool? isPublished,
  }) async {
    try {
      final updated = await _ref.read(modulesApiProvider).updateModule(
            courseId: _courseId,
            moduleId: moduleId,
            payload: ModuleUpdateRequest(
              title: title,
              description: description,
              isPublished: isPublished,
            ),
          );

      final nextModules = state.modules
          .map((module) => module.id == moduleId ? updated : module)
          .toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      state = state.copyWith(modules: nextModules);
      return updated;
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(_ref, failure);
      return null;
    }
  }

  Future<bool> deleteModule(int moduleId) async {
    try {
      await _ref.read(modulesApiProvider).deleteModule(
            courseId: _courseId,
            moduleId: moduleId,
          );

      final nextModules = state.modules.where((module) => module.id != moduleId).toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      final nextMaterials = Map<int, List<MaterialItem>>.from(state.materials)..remove(moduleId);
      final nextTopics = Map<int, List<TopicItem>>.from(state.topics)..remove(moduleId);
      final nextMaterialLoading = Map<int, bool>.from(state.materialsLoading)..remove(moduleId);
      final nextTopicLoading = Map<int, bool>.from(state.topicsLoading)..remove(moduleId);

      state = state.copyWith(
        modules: nextModules,
        materials: nextMaterials,
        topics: nextTopics,
        materialsLoading: nextMaterialLoading,
        topicsLoading: nextTopicLoading,
      );
      return true;
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(_ref, failure);
      return false;
    }
  }

  Future<bool> reorderModule({
    required int moduleId,
    required int newPosition,
  }) async {
    final previousModules = [...state.modules]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final currentIndex = previousModules.indexWhere((module) => module.id == moduleId);
    if (currentIndex == -1) return false;

    final targetIndex = newPosition.clamp(0, previousModules.length - 1);
    if (targetIndex == currentIndex) return true;

    final reorderedModules = [...previousModules];
    final moved = reorderedModules.removeAt(currentIndex);
    reorderedModules.insert(targetIndex, moved);
    final normalized = [
      for (var i = 0; i < reorderedModules.length; i++)
        reorderedModules[i].copyWith(orderIndex: i),
    ];

    state = state.copyWith(modules: normalized);

    try {
      await _ref.read(modulesApiProvider).reorderModules(
            courseId: _courseId,
            moduleIds: normalized.map((module) => module.id).toList(),
          );
      return true;
    } catch (e) {
      state = state.copyWith(modules: previousModules);
      final failure = mapApiFailure(e);
      AppErrorReporter.report(_ref, failure);
      return false;
    }
  }

  // ── Materials ─────────────────────────────────────────────────────────────

  Future<void> loadMaterials(int moduleId, {bool force = false}) async {
    if (state.materialsLoading[moduleId] ?? false) return;
    if (state.materials.containsKey(moduleId) && !force) return;

    final newLoading = Map<int, bool>.from(state.materialsLoading)
      ..[moduleId] = true;
    state = state.copyWith(materialsLoading: newLoading);

    try {
      final res = await _ref.read(materialsApiProvider).listMaterials(
            courseId: _courseId,
            moduleId: moduleId,
          );
      final newMats = Map<int, List<MaterialItem>>.from(state.materials)
        ..[moduleId] = res.materials;
      final newLoad = Map<int, bool>.from(state.materialsLoading)
        ..[moduleId] = false;
      state = state.copyWith(materials: newMats, materialsLoading: newLoad);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      final failure = mapApiFailure(e);
      AppErrorReporter.report(_ref, failure);
      final newLoad = Map<int, bool>.from(state.materialsLoading)
        ..[moduleId] = false;
      state = state.copyWith(materialsLoading: newLoad);
    }
  }

  // ── Topics ──────────────────────────────────────────────────────────────

  Future<void> loadTopics(int moduleId, {bool force = false}) async {
    if (state.topicsLoading[moduleId] ?? false) return;
    if (state.topics.containsKey(moduleId) && !force) return;

    final newLoading = Map<int, bool>.from(state.topicsLoading)
      ..[moduleId] = true;
    state = state.copyWith(topicsLoading: newLoading);

    List<TopicItem> backendTopics = const [];
    try {
      // Topics are nested under materials — ensure materials are loaded first.
      if ((state.materials[moduleId] ?? const <MaterialItem>[]).isEmpty) {
        await loadMaterials(moduleId, force: force);
      }
      final materials = state.materials[moduleId] ?? const <MaterialItem>[];
      final allTopics = <TopicItem>[];
      for (final mat in materials) {
        final res = await _ref.read(topicsApiProvider).listTopics(
              courseId: _courseId,
              moduleId: moduleId,
              materialId: mat.id,
            );
        allTopics.addAll(res.topics);
      }
      backendTopics = allTopics;
    } catch (_) {
      // Non-fatal — topic authoring is currently handled via local fallback storage.
    }

    final localTopics = await _ref.read(topicMockServiceProvider).listTopics(moduleId);
    final merged = <int, TopicItem>{
      for (final topic in backendTopics) topic.id: topic,
      for (final topic in localTopics) topic.id: topic,
    }.values.toList()
      ..sort((a, b) {
        final materialCmp = a.materialId.compareTo(b.materialId);
        if (materialCmp != 0) return materialCmp;
        return a.orderIndex.compareTo(b.orderIndex);
      });

    final newTopics = Map<int, List<TopicItem>>.from(state.topics)
      ..[moduleId] = merged;
    final newLoad = Map<int, bool>.from(state.topicsLoading)
      ..[moduleId] = false;
    state = state.copyWith(topicsLoading: newLoad, topics: newTopics);
  }

  Future<TopicItem?> createTopic({
    required int moduleId,
    required int materialId,
    required TopicCreateRequest payload,
  }) async {
    try {
      final topic = await _ref.read(topicsApiProvider).createTopic(
            courseId:   _courseId,
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
      AppErrorReporter.report(_ref, failure);
      return null;
    }
  }

  Future<void> updateTopic(TopicItem topic) async {
    try {
      final updated = await _ref.read(topicsApiProvider).updateTopic(
            courseId:   _courseId,
            moduleId:   topic.moduleId,
            materialId: topic.materialId,
            topicId:    topic.id,
            payload:    TopicUpdateRequest(
              title:              topic.title,
              description:        topic.description,
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
      AppErrorReporter.report(_ref, failure);
    }
  }

  Future<void> deleteTopic({required int moduleId, required int topicId, int? materialId}) async {
    // materialId is required for the backend URL — find it from state if not provided
    final matId = materialId ??
        (state.topics[moduleId] ?? const [])
            .firstWhere((t) => t.id == topicId,
                orElse: () => TopicItem(
                    id: 0,
                    materialId: 0,
                    title: '',
                    orderIndex: 0,
                    createdAt: DateTime(0),
                    updatedAt: DateTime(0)))
            .materialId;
    try {
      await _ref.read(topicsApiProvider).deleteTopic(
            courseId:   _courseId,
            moduleId:   moduleId,
            materialId: matId,
            topicId:    topicId,
          );
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(_ref, failure);
      return;
    }
    final existing = List<TopicItem>.from(state.topics[moduleId] ?? const []);
    final newTopics = Map<int, List<TopicItem>>.from(state.topics)
      ..[moduleId] = existing.where((t) => t.id != topicId).toList();
    state = state.copyWith(topics: newTopics);
  }

  // ── Download URLs ───────────────────────────────────────────────────────────

  /// Fetches (or returns cached) a fresh signed download URL for a material.
  Future<String?> fetchDownloadUrl({
    required int moduleId,
    required int materialId,
    bool force = false,
  }) async {
    if (!force && state.downloadUrls.containsKey(materialId)) {
      return state.downloadUrls[materialId];
    }
    if (state.downloadUrlLoading[materialId] ?? false) return null;

    final loadingMap = Map<int, bool>.from(state.downloadUrlLoading)
      ..[materialId] = true;
    state = state.copyWith(downloadUrlLoading: loadingMap);

    try {
      final url = await _ref.read(materialsApiProvider).getDownloadUrl(
            courseId: _courseId,
            moduleId: moduleId,
            materialId: materialId,
          );
      final urlMap = Map<int, String>.from(state.downloadUrls);
      if (url != null) urlMap[materialId] = url;
      final doneLoading = Map<int, bool>.from(state.downloadUrlLoading)
        ..[materialId] = false;
      state = state.copyWith(downloadUrls: urlMap, downloadUrlLoading: doneLoading);
      return url;
    } catch (_) {
      final doneLoading = Map<int, bool>.from(state.downloadUrlLoading)
        ..[materialId] = false;
      state = state.copyWith(downloadUrlLoading: doneLoading);
      return null;
    }
  }

  // ── Upload ──────────────────────────────────────────────────────────────

  Future<bool> uploadMaterial({
    required int moduleId,
    required Uint8List bytes,
    required String filename,
    required String contentType,
    String? title,
  }) async {
    state = state.copyWith(uploading: true, uploadProgress: 0.0);

    try {
      final initResp = await _ref.read(materialsApiProvider).initUpload(
            courseId: _courseId,
            moduleId: moduleId,
            payload: MaterialInitUploadRequest(
              filename: filename,
              contentType: contentType,
              fileSizeBytes: bytes.length,
              title: title ?? filename,
            ),
          );

      state = state.copyWith(uploadProgress: 0.3);

      await _ref.read(materialsApiProvider).uploadToPresignedUrl(
            uploadUrl: initResp.uploadUrl,
            bytes: bytes,
            contentType: contentType,
            onSendProgress: (sent, total) {
              if (total <= 0) return;
              final p = (0.3 + (0.4 * sent / total)).clamp(0.0, 0.7);
              state = state.copyWith(uploadProgress: p);
            },
          );

      state = state.copyWith(uploadProgress: 0.7);

      await _ref.read(materialsApiProvider).confirmUpload(
            materialId: initResp.materialId,
          );

      state = state.copyWith(uploading: false, uploadProgress: 1.0);
      await loadMaterials(moduleId);
      return true;
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(_ref, failure);
      state = state.copyWith(uploading: false, uploadError: failure.message);
      return false;
    }
  }

  // ── Question Bank (in-memory) ────────────────────────────────────────────

  void addQuestion(QuestionModel question) {
    state = state.copyWith(questions: [question, ...state.questions]);
  }

  void deleteQuestion(String questionId) {
    state = state.copyWith(
      questions: state.questions.where((q) => q.id != questionId).toList(),
    );
  }

  // ── Question Bank (backend sync) ────────────────────────────────────────────────

  /// Syncs the in-memory MCQ questions to the backend for a specific material.
  ///
  /// [moduleId] and [materialId] identify the parent context in the course tree.
  /// Only [QuestionType.multipleChoice] questions are sent — the backend batch
  /// endpoint currently only accepts MCQ.
  ///
  /// On success: [CourseDetailsState.lastSyncedCount] is updated and each
  /// synced question's [QuestionModel.remoteId] is set from the backend response.
  /// Returns true if at least one question was created successfully.
  Future<bool> syncQuestionsToBackend({
    required int moduleId,
    required int materialId,
  }) async {
    final mcqQuestions = state.questions
        .where((q) => q.type == QuestionType.multipleChoice)
        .toList();

    if (mcqQuestions.isEmpty) return false;

    state = state.copyWith(
      questionsLoading: true,
    );

    try {
      final resp = await _ref.read(questionsApiProvider).batchCreateQuestions(
            courseId: _courseId,
            moduleId: moduleId,
            materialId: materialId,
            questions: mcqQuestions,
          );

      // Stamp each MCQ question with its new remote id (matched by question text).
      // Non-MCQ questions are passed through unmodified.
      final updatedQuestions = state.questions.map((q) {
        if (q.type != QuestionType.multipleChoice) return q;
        final match = resp.questions
            .where((r) => r.questionText == q.text)
            .toList();
        if (match.isEmpty) return q;
        return QuestionModel(
          id: q.id,
          remoteId: match.first.id,
          text: q.text,
          type: q.type,
          difficulty: q.difficulty,
          source: q.source,
          approvalStatus: q.approvalStatus,
          options: q.options,
          correctOptionId: q.correctOptionId,
          correctBool: q.correctBool,
          sampleAnswer: q.sampleAnswer,
          explanation: q.explanation,
          expectedAnswer: q.expectedAnswer,
          tags: q.tags,
          usageCount: q.usageCount,
          successRate: q.successRate,
          maxScore: q.maxScore,
          autoGradable: q.autoGradable,
          courseId: _courseId,
          moduleId: moduleId,
          moduleName: q.moduleName,
          materialId: materialId,
          materialName: q.materialName,
          topicId: q.topicId,
          topicName: q.topicName,
          createdAt: q.createdAt,
        );
      }).toList();

      state = state.copyWith(
        questionsLoading: false,
        questions: updatedQuestions,
        lastSyncedCount: resp.createdCount,
      );

      return resp.createdCount > 0;
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(_ref, failure);
      state = state.copyWith(
        questionsLoading: false,
        questionsError: failure.message,
      );
      return false;
    }
  }

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }
}
