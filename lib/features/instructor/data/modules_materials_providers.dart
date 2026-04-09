import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_providers.dart';
import 'modules_api.dart';
import 'materials_api.dart';
import 'topics_api.dart';
import 'questions_api.dart';
import 'learning_outcomes_api.dart';

final modulesApiProvider = Provider<ModulesApi>((ref) {
  return ModulesApi(ref.read(apiClientProvider));
});

final materialsApiProvider = Provider<MaterialsApi>((ref) {
  return MaterialsApi(ref.read(apiClientProvider));
});

final topicsApiProvider = Provider<TopicsApi>((ref) {
  return TopicsApi(ref.read(apiClientProvider));
});

// NEW — wires the batch question-create endpoint (G-01/G-02/G-03)
final questionsApiProvider = Provider<QuestionsApi>((ref) {
  return QuestionsApi(ref.read(apiClientProvider));
});
final learningOutcomesApiProvider = Provider<LearningOutcomesApi>((ref) {
  return LearningOutcomesApi(ref.read(apiClientProvider));
});
