import 'question_models.dart';

extension QuestionTypeVocabulary on QuestionType {
  String get backendValue {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'multiple_choice';
      case QuestionType.trueFalse:
        return 'true_false';
      case QuestionType.shortAnswer:
        return 'short_answer';
      case QuestionType.essay:
        return 'essay';
      case QuestionType.multiSelect:
        return 'multi_select';
      case QuestionType.fillInTheBlank:
        return 'fill_in_the_blank';
      case QuestionType.numeric:
        return 'numeric';
      case QuestionType.code:
        return 'code';
    }
  }

  String get label {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.trueFalse:
        return 'True / False';
      case QuestionType.shortAnswer:
        return 'Short Answer';
      case QuestionType.essay:
        return 'Essay';
      case QuestionType.multiSelect:
        return 'Multi-Select';
      case QuestionType.fillInTheBlank:
        return 'Fill in the Blank';
      case QuestionType.numeric:
        return 'Numeric';
      case QuestionType.code:
        return 'Code';
    }
  }
}

extension QuestionDifficultyVocabulary on QuestionDifficulty {
  String get backendValue {
    switch (this) {
      case QuestionDifficulty.easy:
        return 'easy';
      case QuestionDifficulty.medium:
        return 'medium';
      case QuestionDifficulty.hard:
        return 'hard';
    }
  }

  String get label {
    switch (this) {
      case QuestionDifficulty.easy:
        return 'Easy';
      case QuestionDifficulty.medium:
        return 'Medium';
      case QuestionDifficulty.hard:
        return 'Hard';
    }
  }
}

QuestionType parseQuestionType(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'multiple_choice':
    case 'multiplechoice':
    case 'mcq':
      return QuestionType.multipleChoice;
    case 'true_false':
    case 'truefalse':
    case 'boolean':
      return QuestionType.trueFalse;
    case 'short_answer':
    case 'shortanswer':
      return QuestionType.shortAnswer;
    case 'essay':
      return QuestionType.essay;
    case 'multi_select':
    case 'multiselect':
      return QuestionType.multiSelect;
    case 'fill_in_the_blank':
    case 'fillintheblank':
      return QuestionType.fillInTheBlank;
    case 'numeric':
      return QuestionType.numeric;
    case 'code':
      return QuestionType.code;
    default:
      return QuestionType.multipleChoice;
  }
}

QuestionDifficulty parseQuestionDifficulty(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'easy':
      return QuestionDifficulty.easy;
    case 'hard':
      return QuestionDifficulty.hard;
    default:
      return QuestionDifficulty.medium;
  }
}
