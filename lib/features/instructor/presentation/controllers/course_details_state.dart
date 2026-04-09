import '../../data/modules_models.dart';
import '../../data/materials_models.dart';
import '../../data/topics_models.dart';
import '../../data/question_models.dart';

class CourseDetailsState {
  // ── Modules ───────────────────────────────────────────────────────────────
  final bool modulesLoading;
  final String? modulesError;
  final List<ModuleItem> modules;

  // ── Materials per module (key = moduleId) ─────────────────────────────────
  final Map<int, bool> materialsLoading;
  final Map<int, List<MaterialItem>> materials;

  // ── Topics per module (key = moduleId) ────────────────────────────────────
  final Map<int, bool> topicsLoading;
  final Map<int, List<TopicItem>> topics;

  // ── Fresh download URLs per material (key = materialId) ───────────────────
  final Map<int, String> downloadUrls;
  final Map<int, bool> downloadUrlLoading;

  // ── In-memory question bank ───────────────────────────────────────────────
  final List<QuestionModel> questions;

  // ── Question bank backend sync (NEW — G-04/G-05) ──────────────────────────
  final bool questionsLoading;   // true while POST .../questions is in-flight
  final String? questionsError;  // non-null if last sync failed
  final int? lastSyncedCount;    // how many questions were created in last batch

  // ── Upload progress ───────────────────────────────────────────────────────
  final bool uploading;
  final String? uploadError;
  final double uploadProgress;

  const CourseDetailsState({
    this.modulesLoading = false,
    this.modulesError,
    this.modules = const [],
    this.materialsLoading = const {},
    this.materials = const {},
    this.topicsLoading = const {},
    this.topics = const {},
    this.downloadUrls = const {},
    this.downloadUrlLoading = const {},
    this.questions = const [],
    this.questionsLoading = false,
    this.questionsError,
    this.lastSyncedCount,
    this.uploading = false,
    this.uploadError,
    this.uploadProgress = 0.0,
  });

  CourseDetailsState copyWith({
    bool? modulesLoading,
    String? modulesError,
    List<ModuleItem>? modules,
    Map<int, bool>? materialsLoading,
    Map<int, List<MaterialItem>>? materials,
    Map<int, bool>? topicsLoading,
    Map<int, List<TopicItem>>? topics,
    Map<int, String>? downloadUrls,
    Map<int, bool>? downloadUrlLoading,
    List<QuestionModel>? questions,
    bool? questionsLoading,
    String? questionsError,
    int? lastSyncedCount,
    bool? uploading,
    String? uploadError,
    double? uploadProgress,
  }) {
    return CourseDetailsState(
      modulesLoading: modulesLoading ?? this.modulesLoading,
      modulesError: modulesError,
      modules: modules ?? this.modules,
      materialsLoading: materialsLoading ?? this.materialsLoading,
      materials: materials ?? this.materials,
      topicsLoading: topicsLoading ?? this.topicsLoading,
      topics: topics ?? this.topics,
      downloadUrls: downloadUrls ?? this.downloadUrls,
      downloadUrlLoading: downloadUrlLoading ?? this.downloadUrlLoading,
      questions: questions ?? this.questions,
      questionsLoading: questionsLoading ?? this.questionsLoading,
      questionsError: questionsError,
      lastSyncedCount: lastSyncedCount ?? this.lastSyncedCount,
      uploading: uploading ?? this.uploading,
      uploadError: uploadError,
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }
}
