part of 'course_details_controller.dart';



mixin _CourseDetailsModulesMixin on StateNotifier<CourseDetailsState> {
  Ref get ref;
  int get courseId;
  Future<void> loadMaterials(int moduleId, {bool force = false});
  Future<void> loadTopics(int moduleId, {bool force = false});
  CancelToken? get cancelToken;
  set cancelToken(CancelToken? value);
// ── Modules ──────────────────────────────────────────────────────────────

  Future<void> loadModules({bool force = false}) async {
    if (state.modulesLoading) return;
    if (state.modules.isNotEmpty && !force) return;
    cancelToken?.cancel();
    cancelToken = CancelToken();

    state = state.copyWith(modulesLoading: true);

    try {
      final res = await ref.read(modulesApiProvider).listModules(
            courseId: courseId,
            cancelToken: cancelToken,
          );
      state = state.copyWith(modulesLoading: false, modules: res.modules);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      final failure = mapApiFailure(e);
      AppErrorReporter.report(ref, failure);
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
      final module = await ref.read(modulesApiProvider).createModule(
            courseId: courseId,
            payload: ModuleCreateRequest(title: title, description: description),
          );
      state = state.copyWith(modules: [...state.modules, module]);
      return module;
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(ref, failure);
      return null;
    }
  }

  /// Copies [moduleId] into [targetCourseId].
  ///
  /// [sourceCourseId] is still accepted because the UI needs to know where the
  /// module was chosen from, but persistence is driven by the target course.
  Future<ModuleItem?> copyModule({
    required int sourceCourseId,
    required int moduleId,
    int? targetCourseId,
  }) async {
    final destinationCourseId = targetCourseId ?? courseId;
    try {
      final copied = await ref.read(modulesApiProvider).copyModule(
            sourceCourseId: sourceCourseId,
            moduleId: moduleId,
            targetCourseId: destinationCourseId,
          );
      if (destinationCourseId == courseId) {
        await loadModules(force: true);
        for (final module in state.modules) {
          if (module.id == copied.id) return module;
        }
      }
      return copied;
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(ref, failure);
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
      final updated = await ref.read(modulesApiProvider).updateModule(
            courseId: courseId,
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
      AppErrorReporter.report(ref, failure);
      return null;
    }
  }

  Future<bool> deleteModule(int moduleId) async {
    try {
      await ref.read(modulesApiProvider).deleteModule(
            courseId: courseId,
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
      AppErrorReporter.report(ref, failure);
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
      await ref.read(modulesApiProvider).reorderModules(
            courseId: courseId,
            moduleIds: normalized.map((module) => module.id).toList(),
          );
      return true;
    } catch (e) {
      state = state.copyWith(modules: previousModules);
      final failure = mapApiFailure(e);
      AppErrorReporter.report(ref, failure);
      return false;
    }
  }

  
}
