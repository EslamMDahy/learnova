import 'package:flutter/material.dart';

class CreateExamContent2 extends StatefulWidget {
  const CreateExamContent2({super.key});

  @override
  State<CreateExamContent2> createState() => _CreateExamContent2State();
}

class _CreateExamContent2State extends State<CreateExamContent2> {
  
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
            child: const Icon(
              Icons.auto_awesome,
              color: Color(0xFF3B82F6),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Question Generator',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'Let our AI analyze the course material and suggest relevant questions for this quiz.',
                  style: TextStyle(
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Generate Questions',
              style: TextStyle(
                color: Color(0xFF3B82F6),
                fontWeight: FontWeight.bold,
              ),
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
              hintText: 'Search questions by keyword or',
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: Colors.grey,
              ),
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
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
          ),
          const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
        ],
      ),
    );
  }

  
  Widget _buildQuestionsList() {
    return Column(
      children: [
        _buildQuestionCard(
          'What is the time complexity of a binary search algorithm in the worst case?',
          'Algorithms',
          'Multiple Choice',
          'Used 3 times',
          'Easy',
          Colors.green,
        ),
        const SizedBox(height: 16),
        _buildQuestionCard(
          'Explain the difference between SQL and NoSQL databases, providing examples for each.',
          'Databases',
          'Essay',
          'Used 1 time',
          'Medium',
          Colors.orange,
        ),
        const SizedBox(height: 16),
        _buildQuestionCard(
          'In Python, which of the following is NOT a mutable data type?',
          'Programming',
          'Multiple Choice',
          'New',
          'Easy',
          Colors.green,
        ),
        const SizedBox(height: 16),
        _buildQuestionCard(
          'Describe the CAP theorem and its implications for distributed system design.',
          'System Design',
          'Essay',
          'Used 5 times',
          'Hard',
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildQuestionCard(
    String title,
    String tag,
    String type,
    String usage,
    String diff,
    Color diffColor,
  ) {
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
              activeColor: const Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _metaItem(Icons.folder_outlined, tag),
                    const SizedBox(width: 16),
                    _metaItem(Icons.list_alt, type),
                    const SizedBox(width: 16),
                    _metaItem(Icons.history, usage),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: diffColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              diff,
              style: TextStyle(
                color: diffColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildQuizSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quiz Summary',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 24),
          _summaryRow('Total Questions', '15'),
          const Divider(height: 32, color: Color(0xFFF1F5F9)),
          _summaryRow('Total Points', '100'),
          const Divider(height: 32, color: Color(0xFFF1F5F9)),
          _summaryRow('Difficulty', 'Medium', color: Colors.orange),
          const SizedBox(height: 24),
          _buildInfoBox(),
          const SizedBox(height: 24),
          _summaryButton(
            Icons.visibility_outlined,
            'Preview as Student',
            Colors.black,
            Colors.white,
          ),
          const SizedBox(height: 16),
          _summaryButton(
            Icons.add,
            'Add New Question',
            const Color(0xFF3B82F6),
            Colors.white,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: Color(0xFF0EA5E9)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'This quiz is currently saved as a draft. Publishing will make it visible to enrolled students immediately or on the scheduled date.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF617589),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helpers ---
  Widget _metaItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color ?? const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _summaryButton(
    IconData icon,
    String label,
    Color bg,
    Color text, {
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: text,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.chevron_left, color: Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        _pageNode('1', true),
        _pageNode('2', false),
        _pageNode('3', false),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
      ],
    );
  }

  Widget _pageNode(String n, bool active) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF3B82F6) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          n,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF64748B),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
