import 'package:flutter/material.dart';

class ExamQuestionSelectionStep extends StatefulWidget {
  final String scopeLabel;
  final List<dynamic> topicTargets;
  final VoidCallback? onAddQuestion;

  const ExamQuestionSelectionStep({
    super.key,
    this.scopeLabel = 'Selected content',
    this.topicTargets = const [],
    this.onAddQuestion,
  });

  @override
  State<ExamQuestionSelectionStep> createState() => _ExamQuestionSelectionStepState();
}

class _ExamQuestionSelectionStepState extends State<ExamQuestionSelectionStep> {
  final List<String> _selectedQuestions = [
    'Explain the difference between SQL and NoSQL databases, providing examples for each.',
    'Describe the CAP theorem and its implications for distributed system design.',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAIQuestionGenerator(),
              const SizedBox(height: 24),
              _buildFiltersBar(),
              const SizedBox(height: 24),
              const Text(
                'AVAILABLE QUESTIONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              _buildQuestionsList(),
              const SizedBox(height: 24),
              _buildPagination(),
            ],
          ),
        ),
        const SizedBox(width: 32),
        Expanded(child: _buildQuizSummaryCard()),
      ],
    );
  }

  Widget _buildAIQuestionGenerator() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Color(0xFF3B82F6), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Question Generator',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'Current scope: ${widget.scopeLabel}',
                  style: const TextStyle(
                    color: Color(0xFF617589),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Generate Questions',
              style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search questions by keyword',
              prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildDropdownFilter('All Topics'),
        const SizedBox(width: 12),
        _buildDropdownFilter('Any Difficulty'),
        const SizedBox(width: 12),
        _buildDropdownFilter('All Types'),
      ],
    );
  }

  Widget _buildDropdownFilter(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
          const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildQuestionsList() {
    return Column(
      children: [
        _buildQuestionCard('What is the time complexity of a binary search algorithm in the worst case?', 'Algorithms', 'Multiple Choice', 'Used 3 times', 'Easy', Colors.green),
        const SizedBox(height: 16),
        _buildQuestionCard('Explain the difference between SQL and NoSQL databases, providing examples for each.', 'Databases', 'Essay', 'Used 1 time', 'Medium', Colors.orange),
        const SizedBox(height: 16),
        _buildQuestionCard('In Python, which of the following is NOT a mutable data type?', 'Programming', 'Multiple Choice', 'New', 'Easy', Colors.green),
        const SizedBox(height: 16),
        _buildQuestionCard('Describe the CAP theorem and its implications for distributed system design.', 'System Design', 'Essay', 'Used 5 times', 'Hard', Colors.red),
      ],
    );
  }

  Widget _buildQuestionCard(String title, String tag, String type, String usage, String diff, Color diffColor) {
    final bool selected = _selectedQuestions.contains(title);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: selected,
              onChanged: (bool? v) {
                setState(() {
                  if (v ?? false) {
                    _selectedQuestions.add(title);
                  } else {
                    _selectedQuestions.remove(title);
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _metaPill(tag),
                    _metaPill(type),
                    _metaPill(usage),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: diffColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(diff, style: TextStyle(color: diffColor, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _metaPill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF617589))),
      );

  Widget _buildPagination() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          5,
          (index) => Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: index == 0 ? const Color(0xFF137FEC) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: index == 0 ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildQuizSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quiz Summary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 18),
          _summaryRow('Total Questions', '${_selectedQuestions.length}'),
          _summaryRow('Selected Targets', '${widget.topicTargets.length}'),
          _summaryRow('Difficulty', 'Medium'),
          const SizedBox(height: 16),
          if (widget.onAddQuestion != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onAddQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF137FEC),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add New Question'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF617589))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          ],
        ),
      );
}
