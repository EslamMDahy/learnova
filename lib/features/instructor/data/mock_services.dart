// ─────────────────────────────────────────────────────────────────────────────
//  Local fallback services for instructor authoring workflows.
//
//  These persist to browser localStorage on web and in-memory elsewhere.
//  They are used only for capabilities that are missing in the current backend
//  bundle (topic authoring metadata, topic-to-LO mapping, LO CRUD).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/key_value_store_factory.dart';
import 'topics_models.dart';
import 'modules_models.dart';
import 'learning_outcomes_models.dart';

final _localStore = createLocalStore();

const _topicStoreKey = 'learnova.instructor.topics.v2';
const _outcomeStoreKey = 'learnova.instructor.outcomes.v2';

final _allModules = <int, ModuleItem>{}; // key = moduleId
final _courseModuleLinks = <int, List<int>>{}; // courseId -> [moduleId]

int _nextTopicId = 1000;

Map<int, List<TopicItem>> _readTopicStore() {
  final raw = _localStore.getString(_topicStoreKey);
  if (raw == null || raw.trim().isEmpty) return <int, List<TopicItem>>{};
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final out = <int, List<TopicItem>>{};
    decoded.forEach((k, v) {
      final moduleId = int.tryParse(k);
      if (moduleId == null || v is! List) return;
      out[moduleId] = v
          .whereType<Map>()
          .map((e) => TopicItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
    for (final topics in out.values) {
      for (final t in topics) {
        if (t.id >= _nextTopicId) _nextTopicId = t.id + 1;
      }
    }
    return out;
  } catch (_) {
    return <int, List<TopicItem>>{};
  }
}

void _writeTopicStore(Map<int, List<TopicItem>> store) {
  final encoded = <String, dynamic>{
    for (final entry in store.entries)
      entry.key.toString(): entry.value.map((e) => e.toJson()).toList(),
  };
  _localStore.setString(_topicStoreKey, jsonEncode(encoded));
}

Map<int, List<LearningOutcome>> _readOutcomeStore() {
  final raw = _localStore.getString(_outcomeStoreKey);
  if (raw == null || raw.trim().isEmpty) return <int, List<LearningOutcome>>{};
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final out = <int, List<LearningOutcome>>{};
    decoded.forEach((k, v) {
      final courseId = int.tryParse(k);
      if (courseId == null || v is! List) return;
      out[courseId] = v
          .whereType<Map>()
          .map((e) => LearningOutcome.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
    return out;
  } catch (_) {
    return <int, List<LearningOutcome>>{};
  }
}

void _writeOutcomeStore(Map<int, List<LearningOutcome>> store) {
  final encoded = <String, dynamic>{
    for (final entry in store.entries)
      entry.key.toString(): entry.value.map((e) => e.toJson()).toList(),
  };
  _localStore.setString(_outcomeStoreKey, jsonEncode(encoded));
}

// ─────────────────────────────────────────────────────────────────────────────
//  TopicMockService
// ─────────────────────────────────────────────────────────────────────────────
class TopicMockService {
  Future<List<TopicItem>> listTopics(int moduleId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final store = _readTopicStore();
    final items = List<TopicItem>.from(store[moduleId] ?? const []);
    items.sort((a, b) {
      final materialCmp = a.materialId.compareTo(b.materialId);
      if (materialCmp != 0) return materialCmp;
      return a.orderIndex.compareTo(b.orderIndex);
    });
    return items;
  }

  Future<TopicItem> createTopic(
    int moduleId,
    TopicCreateRequest req, {
    required int materialId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 120));
    final now = DateTime.now();
    final store = _readTopicStore();
    final list = List<TopicItem>.from(store[moduleId] ?? const []);
    final materialTopics = list.where((t) => t.materialId == materialId).toList();
    final item = TopicItem(
      id: _nextTopicId++,
      moduleId: moduleId,
      materialId: materialId,
      title: req.title,
      description: req.description,
      orderIndex: materialTopics.length,
      source: req.source,
      difficulty: req.difficulty,
      linkedOutcomeId: req.linkedOutcomeId,
      linkedOutcomeIds: req.linkedOutcomeIds,
      createdAt: now,
      updatedAt: now,
    );
    list.add(item);
    store[moduleId] = list;
    _writeTopicStore(store);
    return item;
  }

  Future<TopicItem> updateTopic(int moduleId, TopicItem updated) async {
    await Future.delayed(const Duration(milliseconds: 120));
    final store = _readTopicStore();
    final list = List<TopicItem>.from(store[moduleId] ?? const []);
    final idx = list.indexWhere((t) => t.id == updated.id);
    if (idx == -1) throw Exception('Topic not found');
    list[idx] = updated.copyWith(updatedAt: DateTime.now());
    store[moduleId] = list;
    _writeTopicStore(store);
    return list[idx];
  }

  Future<void> deleteTopic(int moduleId, int topicId) async {
    await Future.delayed(const Duration(milliseconds: 120));
    final store = _readTopicStore();
    final list = List<TopicItem>.from(store[moduleId] ?? const []);
    store[moduleId] = list.where((t) => t.id != topicId).toList();
    _writeTopicStore(store);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LearningOutcomeMockService
// ─────────────────────────────────────────────────────────────────────────────
class LearningOutcomeMockService {
  List<LearningOutcome> getOutcomes(int courseId) {
    final store = _readOutcomeStore();
    return List<LearningOutcome>.from(store[courseId] ?? const []);
  }

  Future<List<LearningOutcome>> listOutcomes(int courseId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return getOutcomes(courseId);
  }

  Future<void> seedOutcomes(int courseId, List<LearningOutcome> outcomes) async {
    if (outcomes.isEmpty) return;
    final store = _readOutcomeStore();
    final existing = store[courseId] ?? const [];
    if (existing.isNotEmpty) return;
    store[courseId] = List.generate(
      outcomes.length,
      (i) => outcomes[i].copyWith(code: LearningOutcome.codeForIndex(i)),
    );
    _writeOutcomeStore(store);
  }

  Future<LearningOutcome> addOutcome(int courseId, LearningOutcome outcome) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final store = _readOutcomeStore();
    final list = List<LearningOutcome>.from(store[courseId] ?? const []);
    final normalized = outcome.copyWith(code: LearningOutcome.codeForIndex(list.length));
    list.add(normalized);
    store[courseId] = list;
    _writeOutcomeStore(store);
    return normalized;
  }

  Future<LearningOutcome> updateOutcome(int courseId, LearningOutcome updated) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final store = _readOutcomeStore();
    final list = List<LearningOutcome>.from(store[courseId] ?? const []);
    final idx = list.indexWhere((o) => o.id == updated.id);
    if (idx == -1) throw Exception('Outcome not found');
    list[idx] = updated;
    store[courseId] = list;
    _writeOutcomeStore(store);
    return updated;
  }

  Future<void> deleteOutcome(int courseId, String outcomeId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final store = _readOutcomeStore();
    final list = List<LearningOutcome>.from(store[courseId] ?? const []);
    // ignore: unrelated_type_equality_checks
    final filtered = list.where((o) => o.id != outcomeId).toList();
    store[courseId] = List.generate(
      filtered.length,
      (i) => filtered[i].copyWith(code: LearningOutcome.codeForIndex(i)),
    );
    _writeOutcomeStore(store);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ModuleSharingMockService
// ─────────────────────────────────────────────────────────────────────────────
class ModuleSharingMockService {
  Future<List<ModuleItem>> listAllInstructorModules() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return _allModules.values.toList();
  }

  void cacheModule(ModuleItem m) => _allModules[m.id] = m;

  Future<void> linkModuleToCourse(int moduleId, int courseId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final links = _courseModuleLinks[courseId] ?? [];
    if (!links.contains(moduleId)) {
      _courseModuleLinks[courseId] = [...links, moduleId];
    }
    final m = _allModules[moduleId];
    if (m != null && m.courseId != courseId) {
      final updated = m.copyWith(
        sharedWithCourseIds: [...m.sharedWithCourseIds, courseId],
      );
      _allModules[moduleId] = updated;
    }
  }

  List<int> linkedModuleIds(int courseId) {
    return _courseModuleLinks[courseId] ?? [];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Riverpod providers
// ─────────────────────────────────────────────────────────────────────────────
final topicMockServiceProvider = Provider<TopicMockService>(
  (_) => TopicMockService(),
);

final learningOutcomeMockServiceProvider =
    Provider<LearningOutcomeMockService>(
  (_) => LearningOutcomeMockService(),
);

final moduleSharingMockServiceProvider =
    Provider<ModuleSharingMockService>(
  (_) => ModuleSharingMockService(),
);
