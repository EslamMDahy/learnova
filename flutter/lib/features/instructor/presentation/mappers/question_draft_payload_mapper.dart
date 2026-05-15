import '../../data/question_models.dart';
import '../../data/question_vocabulary.dart';
import '../../data/questions_api.dart';
import '../models/question_draft_item.dart';

CreateQuestionPayload mapDraftToCreateQuestionPayload(QuestionDraftItem draft) {
  final cleanedOptions = draft.options
      .asMap()
      .entries
      .where((entry) => entry.value.trim().isNotEmpty)
      .map((entry) => CreateQuestionOption(
            id: String.fromCharCode(65 + entry.key),
            text: entry.value.trim(),
          ))
      .toList();

  Object? expectedAnswer;
  if (draft.type == QuestionType.multipleChoice && draft.correctOptionIndex != null) {
    expectedAnswer = String.fromCharCode(65 + draft.correctOptionIndex!);
  } else if (draft.type == QuestionType.multiSelect) {
    expectedAnswer = draft.correctOptionIndexes
        .map((index) => String.fromCharCode(65 + index))
        .toList();
  } else if (draft.type == QuestionType.trueFalse) {
    expectedAnswer = (draft.correctBool ?? false).toString();
  } else if (draft.type == QuestionType.shortAnswer || draft.type == QuestionType.essay) {
    expectedAnswer = draft.expectedAnswerText;
  }

  return CreateQuestionPayload(
    topicId: draft.topicId,
    questionText: draft.questionText.trim(),
    type: draft.type.backendValue,
    difficulty: draft.difficulty.backendValue,
    explanation: draft.explanation.trim().isEmpty ? null : draft.explanation.trim(),
    options: cleanedOptions.isEmpty ? null : cleanedOptions,
    expectedAnswer: expectedAnswer,
  );
}
