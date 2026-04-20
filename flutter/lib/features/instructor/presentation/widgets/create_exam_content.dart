import 'package:flutter/material.dart';
import 'exam_question_selection_step.dart';
import 'exam_settings_step.dart';

class CreateExamContent extends StatefulWidget {
  final int currentStep;
  final VoidCallback onNext;
  final VoidCallback onBack;

  final String? courseTitle;
  final String? scopeLabel;
  final List<dynamic>? topicTargets;
  final VoidCallback? onAddQuestion;

  const CreateExamContent({
    super.key,
    required this.currentStep,
    required this.onNext,
    required this.onBack,
    this.courseTitle,
    this.scopeLabel,
    this.topicTargets,
    this.onAddQuestion,
  });

  @override
  State<CreateExamContent> createState() => _CreateExamContentState();
}

class _CreateExamContentState extends State<CreateExamContent> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create New Exam',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Step ${widget.currentStep}: ${widget.currentStep == 1 ? 'Basic Details' : widget.currentStep == 2 ? 'Add Questions' : 'Settings'}",
                    style: const TextStyle(
                      color: Color(0xFF617589),
                      fontSize: 14,
                    ),
                  ),
                  if ((widget.scopeLabel ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.scopeLabel!,
                      style: const TextStyle(
                        color: Color(0xFF137FEC),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  _headerActionBtn('Save Draft', isPrimary: false),
                  const SizedBox(width: 12),
                  _headerActionBtn('Publish Quiz', isPrimary: true),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              _buildStepItem(
                stepNumber: 1,
                label: '1. Basic Details',
                isActive: widget.currentStep == 1,
                isCompleted: widget.currentStep > 1,
              ),
              _buildDivider(),
              _buildStepItem(
                stepNumber: 2,
                label: '2. Add Questions',
                isActive: widget.currentStep == 2,
                isCompleted: widget.currentStep > 2,
              ),
              _buildDivider(),
              _buildStepItem(
                stepNumber: 3,
                label: '3. Settings',
                isActive: widget.currentStep == 3,
                isCompleted: widget.currentStep > 3,
              ),
            ],
          ),
          const SizedBox(height: 40),
          _buildStepFormContent(),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: Text(
                    widget.currentStep == 1 ? 'Back to Dashboard' : 'Back to Previous',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF137FEC),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(widget.currentStep == 3 ? 'Finish' : 'Next Step'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepFormContent() {
    switch (widget.currentStep) {
      case 1:
        return _buildStep1Fields();
      case 2:
        return ExamQuestionSelectionStep(
          scopeLabel: widget.scopeLabel ?? 'Selected content',
          topicTargets: widget.topicTargets ?? const [],
          onAddQuestion: widget.onAddQuestion,
        );
      case 3:
        return const ExamSettingsStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1Fields() {
    final selectedContent = (widget.scopeLabel ?? '').trim().isNotEmpty
        ? widget.scopeLabel!
        : ((widget.topicTargets?.isNotEmpty ?? false)
            ? '${widget.topicTargets!.length} selected target(s)'
            : 'Not specified');

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Quiz Title *'),
          TextField(
            decoration: _inputDecoration(
              widget.courseTitle == null || widget.courseTitle!.trim().isEmpty
                  ? 'e.g., Midterm Exam - Data Structures'
                  : 'e.g., Midterm Exam - ${widget.courseTitle}',
            ),
          ),
          const SizedBox(height: 24),
          _buildLabel('Description / Instructions'),
          const Text(
            'Provide instructions for students before they begin.',
            style: TextStyle(color: Color(0xFF617589), fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            maxLines: 5,
            decoration: _inputDecoration('Enter detailed instructions here...'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Exam Category'),
                    DropdownButtonFormField<String>(
                      decoration: _inputDecoration('Quiz'),
                      initialValue: 'Quiz',
                      items: const [
                        DropdownMenuItem(value: 'Quiz', child: Text('Quiz')),
                      ],
                      onChanged: (v) {},
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Selected Content'),
                    TextField(
                      enabled: false,
                      controller: TextEditingController(text: selectedContent),
                      decoration: _inputDecoration('Selected content'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerActionBtn(String label, {required bool isPrimary}) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? const Color(0xFF137FEC) : Colors.white,
        foregroundColor: isPrimary ? Colors.white : const Color(0xFF0F172A),
        side: isPrimary ? BorderSide.none : const BorderSide(color: Color(0xFFE2E8F0)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }

  Widget _buildStepItem({
    required int stepNumber,
    required String label,
    required bool isActive,
    required bool isCompleted,
  }) {
    final Color mainColor = isActive
        ? const Color(0xFF137FEC)
        : (isCompleted ? const Color(0xFF10B981) : const Color(0xFFCBD5E1));
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isActive || isCompleted ? mainColor : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: mainColor, width: 2),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '$stepNumber',
                    style: TextStyle(
                      color: isActive ? Colors.white : mainColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: isActive || isCompleted ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() => Container(
        width: 40,
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: const Color(0xFFE2E8F0),
      );

  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );
}
