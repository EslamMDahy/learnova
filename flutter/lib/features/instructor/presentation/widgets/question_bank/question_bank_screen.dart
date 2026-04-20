import 'package:flutter/material.dart';
import 'package:learnova/core/ui/widgets/app_card.dart';

class QuestionBankScreen extends StatelessWidget {
  const QuestionBankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;

      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: w < 600 ? 16 : 24,
          vertical: 24,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 28),
                const QuestionBankStatsSection(),
                const SizedBox(height: 32),
                _buildSearchAndFilterRow(),
                const SizedBox(height: 16),
                const QuestionBankTable(),
                const SizedBox(height: 24),
                _buildPagination(),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Question Bank",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Manage assessments, grades, and analytics for CS101: Intro to AI.",
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text("Create Question Bank"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilterRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: "Search quizzes, topics...",
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildIconButton(Icons.filter_list_rounded, "Filter"),
        const Spacer(),
        Text("SORT BY: ", style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const Text("Due Date", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF475569)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Rows per page:', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        const SizedBox(width: 8),
        _buildPageSelect(),
        const SizedBox(width: 24),
        Text("1-4 of 12", style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(width: 16),
        Icon(Icons.chevron_left_rounded, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
      ],
    );
  }

  Widget _buildPageSelect() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: const [Text("10", style: TextStyle(fontWeight: FontWeight.w600)), Icon(Icons.arrow_drop_down)]),
    );
  }
}

class QuestionBankStatsSection extends StatelessWidget {
  const QuestionBankStatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _statCard("Active Quizzes", "3", "↗ +1 this week", const Color(0xFF3B82F6), Icons.assignment_rounded)),
        const SizedBox(width: 20),
        Expanded(child: _statCard("Pending Grading", "45", "12 manual reviews", const Color(0xFFF59E0B), Icons.fact_check_rounded)),
        const SizedBox(width: 20),
        Expanded(child: _statCard("Avg. Score", "82%", "↗ +2.4% vs last", const Color(0xFF10B981), Icons.trending_up_rounded)),
      ],
    );
  }

  Widget _statCard(String title, String value, String sub, Color color, IconData icon) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                Text(sub, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
        ],
      ),
    );
  }
}

class QuestionBankTable extends StatelessWidget {
  const QuestionBankTable({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildTableHeader(),
          _buildRow("Midterm Exam - AI Ethics", "Ethics, Bias, Safety", "Exam", "Published", const Color(0xFF10B981), "Oct 12, 2023", 0.9, "45/50", "85%"),
          _divider(),
          _buildRow("Week 3 Pop Quiz", "Neural Networks", "Quiz", "Draft", Colors.grey, "Not scheduled", 0, "-", "-", isAi: true),
          _divider(),
          _buildRow("Intro to Python", "Syntax, Variables", "Quiz", "Closed", Colors.redAccent, "Sep 20, 2023", 1.0, "50/50", "92%"),
          _divider(),
          _buildRow("Machine Learning Basics", "ML, Algorithms", "Exam", "Published", const Color(0xFF10B981), "Oct 15, 2023", 0.16, "8/50", "-", isAi: true),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: _headerText("QUIZ TITLE & TOPIC")),
          Expanded(flex: 2, child: _headerText("STATUS")),
          Expanded(flex: 2, child: _headerText("DUE DATE")),
          Expanded(flex: 4, child: _headerText("COMPLETION")), // flex 4 لزيادة التباعد
          Expanded(flex: 1, child: _headerText("AVG. SCORE")),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _headerText(String label) => Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5));

  Widget _divider() => const Divider(height: 1, color: Color(0xFFF1F5F9));

  Widget _buildRow(String title, String topic, String type, String status, Color color, String date, double progress, String label, String score, {bool isAi = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Expanded(flex: 4, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B))),
                if (isAi) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.auto_awesome, size: 14, color: Color(0xFF6366F1))),
              ]),
              const SizedBox(height: 4),
              Text("Topic: $topic", style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            ],
          )),
          // Status Badge width fix
          Expanded(flex: 2, child: Row(
            mainAxisSize: MainAxisSize.min, 
            children: [_badge(status, color)],
          )),
          Expanded(flex: 2, child: Text(date, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500))),
          // Completion & Avg Score spacing fix
          Expanded(flex: 4, child: Row(children: [
            if (progress > 0) Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Color(0xFFF1F5F9), color: color))),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(width: 24), // مسافة تفصل النتائج عن بعضها
          ])),
          Expanded(flex: 1, child: Text(score, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E293B)))),
          const SizedBox(width: 40, child: Icon(Icons.more_horiz_rounded, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}