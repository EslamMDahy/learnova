import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/exam_correction_models.dart';
import '../controllers/exam_correction_controller.dart';

class ExamCorrectionPage extends ConsumerStatefulWidget {
  const ExamCorrectionPage({super.key});

  @override
  ConsumerState<ExamCorrectionPage> createState() => _ExamCorrectionPageState();
}

class _ExamCorrectionPageState extends ConsumerState<ExamCorrectionPage> {
  late final TextEditingController _examIdController;
  late final TextEditingController _courseIdController;

  @override
  void initState() {
    super.initState();
    _examIdController = TextEditingController();
    _courseIdController = TextEditingController();
  }

  @override
  void dispose() {
    _examIdController.dispose();
    _courseIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(examCorrectionControllerProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1120;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth < 620 ? 16 : 32,
            vertical: 28,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _PageHeader(),
                  const SizedBox(height: 22),
                  if (compact) ...[
                    _ScanSetupPanel(
                      examIdController: _examIdController,
                      courseIdController: _courseIdController,
                      onExamIdChanged: controller.setExamIdText,
                      onCourseIdChanged: controller.setCourseIdText,
                    ),
                    const SizedBox(height: 18),
                    const _PaperPreviewPanel(),
                    const SizedBox(height: 18),
                    const _ReviewPanel(),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 360,
                          child: _ScanSetupPanel(
                            examIdController: _examIdController,
                            courseIdController: _courseIdController,
                            onExamIdChanged: controller.setExamIdText,
                            onCourseIdChanged: controller.setCourseIdText,
                          ),
                        ),
                        const SizedBox(width: 18),
                        const Expanded(flex: 5, child: _PaperPreviewPanel()),
                        const SizedBox(width: 18),
                        const Expanded(flex: 4, child: _ReviewPanel()),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      padding: const EdgeInsets.all(28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.document_scanner_outlined, color: AppColors.primary, size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Smart Exam Correction', style: AppText.h1.copyWith(fontSize: 30, height: 36 / 30)),
                const SizedBox(height: 8),
                Text(
                  'Scan printed Learnova exams, detect QR metadata, read Student ID bubbles, extract objective answers with OMR, and prepare written answers for AI grading.',
                  style: AppText.subtitle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          const _PipelineStrip(),
        ],
      ),
    );
  }
}

class _PipelineStrip extends StatelessWidget {
  const _PipelineStrip();

  @override
  Widget build(BuildContext context) {
    const steps = ['QR', 'ID OMR', 'Answers', 'AI'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: steps.map((step) => _StatusChip(label: step, color: AppColors.primary)).toList(growable: false),
    );
  }
}

class _ScanSetupPanel extends ConsumerWidget {
  final TextEditingController examIdController;
  final TextEditingController courseIdController;
  final ValueChanged<String> onExamIdChanged;
  final ValueChanged<String> onCourseIdChanged;

  const _ScanSetupPanel({
    required this.examIdController,
    required this.courseIdController,
    required this.onExamIdChanged,
    required this.onCourseIdChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(examCorrectionControllerProvider);
    final controller = ref.read(examCorrectionControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(icon: Icons.upload_file_rounded, title: 'Scan Queue'),
              const SizedBox(height: 8),
              Text('Upload solved paper scans. New exports include QR, page alignment markers, Student ID bubbles, and answer bubbles.', style: AppText.mutedSmall),
              const SizedBox(height: 16),
              _UploadDropZone(onTap: state.loading ? null : controller.pickFiles),
              if (state.files.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SelectedFilesList(files: state.files, onRemove: controller.removeFile),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: state.loading ? null : controller.clearFiles,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Clear'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(icon: Icons.tune_rounded, title: 'Scanner Setup'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: state.language,
                decoration: _inputDecoration('OCR language'),
                items: const [
                  DropdownMenuItem(value: 'eng', child: Text('English')),
                  DropdownMenuItem(value: 'ara', child: Text('Arabic')),
                  DropdownMenuItem(value: 'ara+eng', child: Text('Arabic + English')),
                ],
                onChanged: state.loading ? null : (value) => controller.setLanguage(value ?? 'eng'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: examIdController,
                onChanged: onExamIdChanged,
                enabled: !state.loading,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Fallback Exam ID').copyWith(helperText: 'Optional. QR is the primary source.'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: courseIdController,
                onChanged: onCourseIdChanged,
                enabled: !state.loading,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Fallback Course ID').copyWith(helperText: 'Optional when QR is valid.'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('Student ID digits', style: AppText.label)),
                  _StepperValue(
                    value: state.studentIdDigits,
                    onChanged: state.loading ? null : controller.setStudentIdDigits,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: state.canAnalyze ? controller.analyzeScan : null,
                  icon: state.loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_motion_outlined),
                  label: Text(state.loading ? 'Analyzing scan...' : 'Analyze solved paper'),
                ),
              ),
              if (state.error != null && state.error!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                _InlineNotice(message: state.error!, tone: _NoticeTone.error),
              ],
              if (state.submitMessage != null && state.submitMessage!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                _InlineNotice(message: state.submitMessage!, tone: _NoticeTone.success),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PaperPreviewPanel extends ConsumerWidget {
  const _PaperPreviewPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(examCorrectionControllerProvider);
    final response = state.response;

    if (state.loading && response == null) {
      return const _PanelCard(
        child: SizedBox(height: 540, child: Center(child: CircularProgressIndicator())),
      );
    }

    if (response == null) {
      return _PanelCard(
        child: SizedBox(
          height: 540,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.article_outlined, color: AppColors.textMuted, size: 56),
                const SizedBox(height: 14),
                Text('No scan analyzed yet', style: AppText.sectionTitle),
                const SizedBox(height: 6),
                Text('The paper preview will show QR, alignment, bubble detection, and written-answer crops.', textAlign: TextAlign.center, style: AppText.sectionSubtitle),
              ],
            ),
          ),
        ),
      );
    }

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(icon: Icons.image_search_rounded, title: 'Paper Intelligence'),
          const SizedBox(height: 14),
          _ScanStats(response: response),
          const SizedBox(height: 16),
          _SyntheticPaper(response: response),
          if (response.warnings.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...response.warnings.map((warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _InlineNotice(message: warning, tone: _NoticeTone.warning),
                )),
          ],
        ],
      ),
    );
  }
}

class _ScanStats extends StatelessWidget {
  final ExamScanAnalyzeResponse response;

  const _ScanStats({required this.response});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MetricCard(label: 'Pages', value: '${response.pages.length}', icon: Icons.description_outlined),
        _MetricCard(label: 'Bubbles', value: '${response.pages.fold<int>(0, (sum, page) => sum + page.bubbleCount)}', icon: Icons.radio_button_checked_rounded),
        _MetricCard(label: 'Detected', value: '${response.gradePreview.detectedQuestions}', icon: Icons.task_alt_rounded),
        _MetricCard(label: 'Review', value: '${response.gradePreview.needsReview}', icon: Icons.warning_amber_rounded),
      ],
    );
  }
}

class _SyntheticPaper extends StatelessWidget {
  final ExamScanAnalyzeResponse response;

  const _SyntheticPaper({required this.response});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 420),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusChip(label: response.exam.title ?? 'Exam ${response.exam.examId ?? 'unknown'}', color: AppColors.primary),
              const SizedBox(width: 8),
              _StatusChip(label: response.status, color: _statusColor(response.status)),
            ],
          ),
          const SizedBox(height: 18),
          for (final page in response.pages) ...[
            _PageScanRow(page: page),
            const SizedBox(height: 12),
          ],
          const Divider(height: 28),
          Text('Detected answer map', style: AppText.label),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: response.answers
                .map((answer) => _AnswerBubblePill(answer: answer))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _PageScanRow extends StatelessWidget {
  final ExamScanPage page;

  const _PageScanRow({required this.page});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.headerBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Text('${page.pageNumber}', style: AppText.label),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(page.filename, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.label),
                const SizedBox(height: 4),
                Text('Alignment: ${page.alignmentStatus} • ${page.alignmentConfidence.toStringAsFixed(1)}% • ${page.bubbleCount} bubbles', style: AppText.mutedSmall),
              ],
            ),
          ),
          _StatusChip(label: page.qrDetected ? 'QR found' : 'No QR', color: page.qrDetected ? AppColors.successText : AppColors.warningText),
        ],
      ),
    );
  }
}

class _ReviewPanel extends ConsumerWidget {
  const _ReviewPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(examCorrectionControllerProvider);
    final controller = ref.read(examCorrectionControllerProvider.notifier);
    final response = state.response;

    if (response == null) {
      return const _PanelCard(
        child: SizedBox(height: 540, child: _EmptyReview()),
      );
    }

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(icon: Icons.fact_check_outlined, title: 'Review & Grade'),
          const SizedBox(height: 14),
          _StudentExamCard(response: response),
          const SizedBox(height: 14),
          _GradePreviewCard(preview: response.gradePreview),
          const SizedBox(height: 16),
          Text('Answers', style: AppText.sectionTitle),
          const SizedBox(height: 10),
          _AnswersList(answers: response.answers),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: state.canSubmit ? controller.submitCorrection : null,
              icon: state.submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.verified_rounded),
              label: Text(state.submitting ? 'Saving correction...' : 'Submit graded attempt'),
            ),
          ),
          if (!state.canSubmit) ...[
            const SizedBox(height: 10),
            _InlineNotice(
              message: 'Submit requires a detected exam, matched student user, and at least one bound answer.',
              tone: _NoticeTone.info,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyReview extends StatelessWidget {
  const _EmptyReview();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.rule_folder_outlined, color: AppColors.textMuted, size: 54),
          const SizedBox(height: 14),
          Text('Waiting for scan result', style: AppText.sectionTitle),
          const SizedBox(height: 6),
          Text('Student identity, answers, AI-ready written responses, and grade preview will appear here.', textAlign: TextAlign.center, style: AppText.sectionSubtitle),
        ],
      ),
    );
  }
}

class _StudentExamCard extends StatelessWidget {
  final ExamScanAnalyzeResponse response;

  const _StudentExamCard({required this.response});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoLine(label: 'Student', value: response.student.name ?? response.student.studentId ?? 'Unmatched'),
          _InfoLine(label: 'User ID', value: response.student.userId?.toString() ?? '—'),
          _InfoLine(label: 'ID confidence', value: '${response.student.confidence.toStringAsFixed(1)}%'),
          const Divider(height: 20),
          _InfoLine(label: 'Exam', value: response.exam.title ?? 'Exam ${response.exam.examId ?? '—'}'),
          _InfoLine(label: 'Course ID', value: response.exam.courseId?.toString() ?? '—'),
          _InfoLine(label: 'Template', value: response.exam.templateVersion),
        ],
      ),
    );
  }
}

class _GradePreviewCard extends StatelessWidget {
  final ExamScanGradePreview preview;

  const _GradePreviewCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    final pct = preview.totalScore > 0 ? (preview.scoreSoFar / preview.totalScore) * 100 : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Score preview', style: AppText.label.copyWith(color: AppColors.primary)),
          const SizedBox(height: 8),
          Text(
            '${preview.scoreSoFar.toStringAsFixed(2)} / ${preview.totalScore.toStringAsFixed(2)}${pct == null ? '' : ' • ${pct.toStringAsFixed(1)}%'}',
            style: AppText.h3,
          ),
          const SizedBox(height: 8),
          Text('${preview.autoGradableQuestions} objective • ${preview.writtenQuestions} written • ${preview.aiReady} AI-ready • ${preview.needsReview} review', style: AppText.mutedSmall),
        ],
      ),
    );
  }
}

class _AnswersList extends StatelessWidget {
  final List<ExamScanAnswer> answers;

  const _AnswersList({required this.answers});

  @override
  Widget build(BuildContext context) {
    if (answers.isEmpty) {
      return _InlineNotice(message: 'No answers were extracted. Check QR, scan clarity, and printed bubble template.', tone: _NoticeTone.warning);
    }
    return Column(
      children: answers
          .map((answer) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AnswerTile(answer: answer),
              ))
          .toList(growable: false),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  final ExamScanAnswer answer;

  const _AnswerTile({required this.answer});

  @override
  Widget build(BuildContext context) {
    final color = answer.needsReview ? AppColors.warningText : AppColors.successText;
    final icon = answer.isWritten ? Icons.edit_note_rounded : Icons.radio_button_checked_rounded;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Q${answer.questionNumber} • ${answer.type.replaceAll('_', ' ')}', style: AppText.label)),
                    _StatusChip(label: '${answer.confidence.toStringAsFixed(0)}%', color: color),
                  ],
                ),
                const SizedBox(height: 5),
                Text(answer.displayAnswer, maxLines: answer.isWritten ? 4 : 1, overflow: TextOverflow.ellipsis, style: AppText.input),
                const SizedBox(height: 5),
                Text(_answerFooter(answer), style: AppText.mutedSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _answerFooter(ExamScanAnswer answer) {
    final parts = <String>[answer.status];
    if (answer.isCorrect != null) parts.add(answer.isCorrect! ? 'correct' : 'incorrect');
    if (answer.pointsEarned != null || answer.maxScore != null) {
      parts.add('${(answer.pointsEarned ?? 0).toStringAsFixed(2)} / ${(answer.maxScore ?? 0).toStringAsFixed(2)}');
    }
    if (answer.aiGradingPayload != null) parts.add('AI payload ready');
    return parts.join(' • ');
  }
}

class _SelectedFilesList extends StatelessWidget {
  final List<ExamCorrectionUploadFile> files;
  final ValueChanged<int> onRemove;

  const _SelectedFilesList({required this.files, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < files.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == files.length - 1 ? 0 : 8),
            child: _SelectedFileTile(file: files[i], onRemove: () => onRemove(i)),
          ),
      ],
    );
  }
}

class _SelectedFileTile extends StatelessWidget {
  final ExamCorrectionUploadFile file;
  final VoidCallback onRemove;

  const _SelectedFileTile({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
            child: Text(file.extension, style: AppText.mutedSmall.copyWith(color: AppColors.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.label),
                const SizedBox(height: 2),
                Text(file.displaySize, style: AppText.mutedSmall),
              ],
            ),
          ),
          IconButton(onPressed: onRemove, icon: const Icon(Icons.close_rounded, size: 18), tooltip: 'Remove'),
        ],
      ),
    );
  }
}

class _UploadDropZone extends StatelessWidget {
  final VoidCallback? onTap;

  const _UploadDropZone({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
        decoration: BoxDecoration(
          color: AppColors.surfaceBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.35)),
        ),
        child: Column(
          children: [
            Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 36),
            const SizedBox(height: 10),
            Text('Choose solved exam scans', style: AppText.label),
            const SizedBox(height: 4),
            Text('PDF, PNG, JPG, WEBP, TIFF, BMP • 12 files max', textAlign: TextAlign.center, style: AppText.mutedSmall),
          ],
        ),
      ),
    );
  }
}

class _StepperValue extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;

  const _StepperValue({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(onPressed: onChanged == null ? null : () => onChanged!(value - 1), icon: const Icon(Icons.remove_circle_outline_rounded)),
        Text('$value', style: AppText.label),
        IconButton(onPressed: onChanged == null ? null : () => onChanged!(value + 1), icon: const Icon(Icons.add_circle_outline_rounded)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 122,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderSoft)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 8),
          Text(value, style: AppText.sectionTitle),
          Text(label, style: AppText.mutedSmall),
        ],
      ),
    );
  }
}

class _AnswerBubblePill extends StatelessWidget {
  final ExamScanAnswer answer;

  const _AnswerBubblePill({required this.answer});

  @override
  Widget build(BuildContext context) {
    final color = answer.needsReview ? AppColors.warningText : AppColors.successText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.35))),
      child: Text('Q${answer.questionNumber}: ${answer.isWritten ? 'written' : answer.displayAnswer}', style: AppText.mutedSmall.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [Icon(icon, color: AppColors.primary), const SizedBox(width: 10), Text(title, style: AppText.sectionTitle)]);
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 94, child: Text(label, style: AppText.mutedSmall)),
          Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.label)),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _PanelCard({required this.child, this.padding = const EdgeInsets.all(22)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [BoxShadow(color: AppColors.shadowSoft, blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.24))),
      child: Text(label, style: AppText.mutedSmall.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

enum _NoticeTone { error, warning, success, info }

class _InlineNotice extends StatelessWidget {
  final String message;
  final _NoticeTone tone;

  const _InlineNotice({required this.message, required this.tone});

  @override
  Widget build(BuildContext context) {
    final bg = switch (tone) {
      _NoticeTone.error => AppColors.dangerBg,
      _NoticeTone.warning => AppColors.warningSoftBg,
      _NoticeTone.success => AppColors.successBg,
      _NoticeTone.info => AppColors.infoBg,
    };
    final border = switch (tone) {
      _NoticeTone.error => AppColors.dangerBorder,
      _NoticeTone.warning => AppColors.warningBorder,
      _NoticeTone.success => AppColors.greenBorder,
      _NoticeTone.info => AppColors.infoBorder,
    };
    final fg = switch (tone) {
      _NoticeTone.error => AppColors.dangerText,
      _NoticeTone.warning => AppColors.warningText,
      _NoticeTone.success => AppColors.successText,
      _NoticeTone.info => AppColors.infoText,
    };
    final icon = switch (tone) {
      _NoticeTone.error => Icons.error_outline_rounded,
      _NoticeTone.warning => Icons.warning_amber_rounded,
      _NoticeTone.success => Icons.check_circle_outline_rounded,
      _NoticeTone.info => Icons.info_outline_rounded,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppText.mutedSmall.copyWith(color: fg))),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  if (status == 'ready' || status == 'detected' || status == 'ai_ready') return AppColors.successText;
  if (status == 'needs_review') return AppColors.warningText;
  return AppColors.primary;
}

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.fieldBg,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderSoft)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderSoft)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary, width: 1.3)),
  );
}
