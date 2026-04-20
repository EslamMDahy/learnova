import '../../data/question_models.dart';

class QuestionDraftItem {
  final String id;
  final int topicId;
  final QuestionType type;
  final QuestionDifficulty difficulty;
  final String questionText;
  final List<String> options;
  final int? correctOptionIndex;
  final bool? correctBool;
  final String explanation;
  final String expectedAnswer;

  const QuestionDraftItem({
    required this.id,
    required this.topicId,
    required this.type,
    required this.difficulty,
    required this.questionText,
    required this.options,
    required this.correctOptionIndex,
    required this.correctBool,
    required this.explanation,
    required this.expectedAnswer,
  });

  factory QuestionDraftItem.empty(int topicId) {
    return QuestionDraftItem(
      id: 'draft-${topicId}-${DateTime.now().microsecondsSinceEpoch}',
      topicId: topicId,
      type: QuestionType.multipleChoice,
      difficulty: QuestionDifficulty.medium,
      questionText: '',
      options: const ['', '', '', ''],
      correctOptionIndex: 0,
      correctBool: null,
      explanation: '',
      expectedAnswer: '',
    );
  }

  QuestionDraftItem copyWith({
    String? id,
    int? topicId,
    QuestionType? type,
    QuestionDifficulty? difficulty,
    String? questionText,
    List<String>? options,
    Object? correctOptionIndex = _unset,
    Object? correctBool = _unset,
    String? explanation,
    String? expectedAnswer,
  }) {
    return QuestionDraftItem(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      type: type ?? this.type,
      difficulty: difficulty ?? this.difficulty,
      questionText: questionText ?? this.questionText,
      options: options ?? this.options,
      correctOptionIndex: identical(correctOptionIndex, _unset)
          ? this.correctOptionIndex
          : correctOptionIndex as int?,
      correctBool: identical(correctBool, _unset)
          ? this.correctBool
          : correctBool as bool?,
      explanation: explanation ?? this.explanation,
      expectedAnswer: expectedAnswer ?? this.expectedAnswer,
    );
  }

  QuestionDraftItem withType(QuestionType nextType) {
    if (nextType == QuestionType.multipleChoice) {
      return copyWith(
        type: nextType,
        options: options.length >= 2 ? options : const ['', '', '', ''],
        correctOptionIndex: 0,
        correctBool: null,
      );
    }
    if (nextType == QuestionType.trueFalse) {
      return copyWith(
        type: nextType,
        correctBool: true,
        correctOptionIndex: null,
      );
    }
    return copyWith(
      type: nextType,
      correctOptionIndex: null,
      correctBool: null,
    );
  }

  String? validate() {
    if (questionText.trim().isEmpty) return 'Question text is required.';
    if (topicId <= 0) return 'Each question must be assigned to a topic.';
    if (type == QuestionType.multipleChoice) {
      final cleaned = options.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (cleaned.length < 2) return 'Multiple-choice questions need at least 2 options.';
      if (correctOptionIndex == null) return 'Choose the correct answer option.';
      if (correctOptionIndex! >= options.length || options[correctOptionIndex!].trim().isEmpty) {
        return 'The correct option must point to a non-empty answer.';
      }
    }
    if ((type == QuestionType.shortAnswer || type == QuestionType.essay) && expectedAnswer.trim().isEmpty) {
      return 'Provide an expected answer or rubric note.';
    }
    if (type == QuestionType.trueFalse && correctBool == null) {
      return 'Choose whether the statement is true or false.';
    }
    return null;
  }

  String get expectedAnswerText => expectedAnswer.trim();
}

const _unset = Object();
