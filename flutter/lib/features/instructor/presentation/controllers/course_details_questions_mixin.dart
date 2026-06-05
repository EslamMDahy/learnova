part of 'course_details_controller.dart';



mixin _CourseDetailsQuestionsMixin on StateNotifier<CourseDetailsState> {
  Ref get ref;
  int get courseId;
// ── Question Bank (in-memory) ────────────────────────────────────────────
  Future<QuestionModel?> createQuestion(QuestionModel question) async {
    state = state.copyWith(questionsLoading: true);

    try {
      final created = await ref.read(questionsApiProvider).createQuestionFromModel(
            courseId: courseId,
            question: question,
          );

      final hydrated = QuestionModel(
        id: created.id,
        remoteId: created.remoteId,
        text: created.text,
        type: created.type,
        difficulty: created.difficulty,
        source: created.source,
        approvalStatus: created.approvalStatus,
        options: created.options,
        correctOptionId: created.correctOptionId ?? question.correctOptionId,
        correctBool: created.correctBool ?? question.correctBool,
        sampleAnswer: created.sampleAnswer ?? question.sampleAnswer,
        explanation: created.explanation,
        expectedAnswer: created.expectedAnswer,
        tags: created.tags,
        usageCount: created.usageCount,
        successRate: created.successRate,
        maxScore: created.maxScore,
        autoGradable: created.autoGradable,
        courseId: created.courseId ?? courseId,
        moduleId: question.moduleId,
        moduleName: question.moduleName,
        materialId: question.materialId,
        materialName: question.materialName,
        topicId: created.topicId ?? question.topicId,
        topicName: question.topicName,
        createdAt: created.createdAt,
      );

      state = state.copyWith(
        questionsLoading: false,
        questions: [hydrated, ...state.questions],
        lastSyncedCount: (state.lastSyncedCount ?? 0) + 1,
      );
      return hydrated;
    } catch (e) {
      final failure = mapApiFailure(e);
      AppErrorReporter.report(ref, failure);
      state = state.copyWith(
        questionsLoading: false,
        questionsError: failure.message,
      );
      return null;
    }
  }


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
      final resp = await ref.read(questionsApiProvider).batchCreateQuestions(
            courseId: courseId,
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
          courseId: courseId,
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
      AppErrorReporter.report(ref, failure);
      state = state.copyWith(
        questionsLoading: false,
        questionsError: failure.message,
      );
      return false;
    }
  }

  
}
