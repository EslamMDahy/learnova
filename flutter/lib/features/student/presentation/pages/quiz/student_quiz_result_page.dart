import 'package:flutter/material.dart';
import 'student_quiz_active_page.dart';
import 'package:learnova/core/theme/app_theme.dart';

class StudentQuizResultPage extends StatefulWidget {
  // متغير لمعرفة هل تم تسليم الاختبار وعرض سيكشن المراجعة أم لا
  final bool isSubmitted;

  const StudentQuizResultPage({super.key, this.isSubmitted = false});

  @override
  State<StudentQuizResultPage> createState() => _StudentQuizResultPageState();
}

class _StudentQuizResultPageState extends State<StudentQuizResultPage> {
  // متغيرات داخلية للتحكم في تبويبات المراجعة والسؤال الحالي داخل السيكشن الجديد
  int _activeTab = 1; // 0: All, 1: Incorrect, 2: Flagged
  int _currentReviewQuestion = 5; // رقم السؤال الحالي المعروض في المراجعة

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 1. LEFT SIDEBAR (Course Content)
          Container(
            width: 320,
            height: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Course Content',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppColors.textTitle,),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5,),
                        decoration: BoxDecoration(
                          color: AppColors.infoBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'CS-101',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ListView(
                      children: [
                        _buildModuleExpansionTile(
                          title: 'Module 1: Intro',
                          isCompleted: true,
                          children: [
                            _buildContentItem('1.1 Course Introduction',
                                isCompleted: true, isCurrent: false,),
                            _buildContentItem('1.2 Setting Up Environment',
                                isCompleted: true, isCurrent: false,),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildModuleExpansionTile(
                          title: 'Module 2: Neural Nets',
                          isInitiallyExpanded: true,
                          isCurrentModule: true,
                          children: [
                            _buildContentItem('2.1 Perceptrons',
                                isCompleted: true, isCurrent: false,),
                            _buildContentItem('2.2 Backpropagation',
                                isCompleted: false, isCurrent: false,),
                            _buildContentItem('2.3 Activation Functions',
                                isCompleted: false, isCurrent: false,),
                            _buildQuizItem('2.4 Module Quiz',
                                isSelectedQuiz: true,),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildModuleExpansionTile(
                          title: 'Module 3: Deep Learning',
                          leadingNumber: '3',
                          children: [
                            _buildContentItem('3.1 CNN Architecture',
                                isCompleted: false, isCurrent: false,),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildModuleExpansionTile(
                          title: 'Module 4: Project',
                          leadingNumber: '4',
                          children: [
                            _buildContentItem('4.1 Final Submission',
                                isCompleted: false, isCurrent: false,),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back to Dashboard',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13,),),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),),
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// 2. MAIN CENTER CONTENT
          Expanded(
            child: SizedBox(
              height: double.infinity,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Mid-Term Assessment: Computer Science 101',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textTitle,),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4,),
                                    decoration: BoxDecoration(
                                      color: AppColors.successBg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Completed',
                                      style: TextStyle(
                                          color: AppColors.successText,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Assessment completed on Oct 24, 2023 • 10:30 AM • ID: #CALC2-2023-MID',
                                style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {},
                              icon:
                                  const Icon(Icons.download_rounded, size: 15),
                              label: const Text('Export PDF',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,),),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textGray,
                                side:
                                    BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12,),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.headerBg,
                                foregroundColor: AppColors.textGray,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12,),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),),
                              ),
                              child: const Text('Back to Dashboard',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,),),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    /// كروت الإحصائيات
                    Row(
                      children: [
                        _buildMetricCard(
                            'OVERALL SCORE',
                            widget.isSubmitted ? '78' : '0',
                            '/100',
                            true,
                            '',
                            Icon(Icons.emoji_events_outlined,
                                color: AppColors.textHint,),),
                        const SizedBox(width: 16),
                        _buildMetricCard(
                            'TIME TAKEN',
                            widget.isSubmitted ? '14m 22s' : '0m 0s',
                            '',
                            false,
                            'Avg. 43s per question',
                            null,),
                        const SizedBox(width: 16),
                        _buildMetricCard(
                            'ACCURACY RATE',
                            widget.isSubmitted ? '80%' : '0%',
                            '',
                            false,
                            widget.isSubmitted
                                ? '16 Correct\n4 Incorrect'
                                : '0 Correct\n0 Incorrect',
                            null,
                            showProgressCircle: true,),
                        const SizedBox(width: 16),
                        _buildMetricCard(
                            'PERCENTILE',
                            widget.isSubmitted ? 'Top 12%' : 'Top 0%',
                            '',
                            false,
                            widget.isSubmitted
                                ? 'Better than 88% of peers'
                                : 'Better than 0% of peers',
                            null,),
                      ],
                    ),
                    const SizedBox(height: 32),

                    /// كرت تحليل الذكاء الاصطناعي
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.infoBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.auto_awesome_rounded,
                                    color: AppColors.primary, size: 18,),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'AI Learning Analysis',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textTitle,),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('IDENTIFIED WEAKNESSES',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textMuted,
                                            letterSpacing: 0.5,),),
                                    const SizedBox(height: 12),
                                    _buildAnalysisItem(
                                      icon: Icons.warning_amber_rounded,
                                      iconColor: AppColors.errorDot,
                                      bgColor: AppColors.dangerBg,
                                      borderColor: AppColors.dangerBorder,
                                      title:
                                          'Integrals of Trigonometric Functions',
                                      subtitle:
                                          'You missed 3 questions related to sin²(x) integration.',
                                    ),
                                    const SizedBox(height: 12),
                                    _buildAnalysisItem(
                                      icon: Icons.info_outline_rounded,
                                      iconColor: AppColors.warningText,
                                      bgColor: AppColors.warningSoftBg,
                                      borderColor: AppColors.warningSoftBg,
                                      title: 'Integration by Parts',
                                      subtitle:
                                          'Slower response time detected. Review formula structure.',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('RECOMMENDED STUDY MATERIALS',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textMuted,
                                            letterSpacing: 0.5,),),
                                    const SizedBox(height: 12),
                                    _buildAnalysisItem(
                                      icon: Icons.menu_book_rounded,
                                      iconColor: AppColors.errorDot,
                                      bgColor: AppColors.dangerBg,
                                      borderColor: AppColors.dangerBorder,
                                      title: 'Chapter 4: Advanced Integration',
                                      subtitle: 'PDF • 15 mins read',
                                      hasArrow: true,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildAnalysisItem(
                                      icon: Icons.play_circle_fill_rounded,
                                      iconColor: AppColors.primary,
                                      bgColor: AppColors.infoBg,
                                      borderColor: AppColors.infoBg,
                                      title: 'Video: Mastering Trig Integrals',
                                      subtitle: 'Video • 8 mins watch',
                                      hasArrow: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    /// 🚀 التحكم التلقائي: إما عرض زر البدء أو عرض الـ Question Review Section بالكامل
                    widget.isSubmitted
                        ? _buildQuestionReviewSection() // عرض سيكشن المراجعة والأزرار بالتفصيل
                        : Center(
                            child: SizedBox(
                              width: 160,
                              height: 46,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const StudentQuizActivePage(),),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),),
                                ),
                                child: const Text('take Quiezz',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,),),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),

          /// 3. RIGHT SIDEBAR (Study Assistant Chat)
          Container(
            width: 340,
            height: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border: Border(left: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                        radius: 5, backgroundColor: Colors.green.shade500,),
                    const SizedBox(width: 8),
                    Text(
                      'Study Assistant',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.textTitle,),
                    ),
                    const SizedBox(width: 6),
                    const Text('• Online & Ready',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.successDot,
                            fontWeight: FontWeight.w600,),),
                    const Spacer(),
                    Icon(Icons.more_horiz,
                        color: AppColors.textMuted, size: 20,),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text('Today',
                              style: TextStyle(
                                  color: AppColors.textHint,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,),),
                        ),
                      ),
                      _buildChatMessage(false,
                          "Hi there! I'm watching this video with you. I can help you summarize key points, generate quiz questions, or explain complex terms like \"Backpropagation\". What do you need?",),
                      Padding(
                        padding: const EdgeInsets.only(left: 40, bottom: 16),
                        child: Row(
                          children: [
                            _buildSuggestionChip('Summarize video'),
                            const SizedBox(width: 8),
                            _buildSuggestionChip('Quiz me'),
                          ],
                        ),
                      ),
                      _buildChatMessage(true,
                          'Can you explain the chain rule part mentioned at 04:20?',),
                      _buildChatMessage(false,
                          "Certainly! At 04:20, the instructor explains that the Chain Rule is used to calculate how a change in the network's weights affects the final error.\n\nThink of it like nested gears: turning a small gear (weight) inside turns a larger gear (hidden layer), which turns the final wheel (output). The chain rule tells us exactly how much the final wheel turns if we nudge the small gear.",),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Ask a question about this lecture...',
                            hintStyle: TextStyle(
                                color: AppColors.textHint, fontSize: 13,),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 14,),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🚀 بناء الـ Question Review Section بالكامل مع التبويبات وأزرار التنقل التفاعلية
  Widget _buildQuestionReviewSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 1. ترويسة السيكشن والتبويبات الفلتر (All, Incorrect, Flagged)
          Row(
            children: [
              Text(
                'Question Review',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTitle,),
              ),
              const SizedBox(width: 24),
              _buildReviewTab(0, 'All (20)'),
              const SizedBox(width: 8),
              _buildReviewTab(1, 'Incorrect (4)'),
              const SizedBox(width: 8),
              _buildReviewTab(2, 'Flagged (1)'),
            ],
          ),
          const SizedBox(height: 24),

          /// 2. تفاصيل السؤال الحالي المختار للمراجعة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question $_currentReviewQuestion',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTitle,),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cancel, color: AppColors.errorDot, size: 14),
                    SizedBox(width: 4),
                    Text('Incorrect',
                        style: TextStyle(
                            color: AppColors.errorDot,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,),),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Which of the following sorting algorithms has a time complexity of O(n log n) in the average case?',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textGray,
                height: 1.4,),
          ),
          const SizedBox(height: 20),

          /// 3. عرض الاختيارات وحالتها (الإجابة الخطأ والإجابة الصح)
          _buildReviewOption('Bubble Sort',
              isWrongSelected: true, isCorrectAnswer: false,),
          _buildReviewOption('Merge Sort',
              isWrongSelected: false, isCorrectAnswer: true,),
          _buildReviewOption('Selection Sort',
              isWrongSelected: false, isCorrectAnswer: false,),
          _buildReviewOption('Insertion Sort',
              isWrongSelected: false, isCorrectAnswer: false,),

          const SizedBox(height: 20),

          /// 4. صندوق توضيح الذكاء الاصطناعي لسبب الخطأ (AI Explanation)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.infoBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        color: AppColors.primary, size: 18,),
                    SizedBox(width: 8),
                    Text('Explanation',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppColors.primary,),),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Merge Sort consistently divides the array in half and takes O(n) time to merge, resulting in O(n log n) complexity. Bubble Sort has an average case complexity of O(n²).',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.infoText,
                      height: 1.4,
                      fontWeight: FontWeight.w500,),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Divider(color: AppColors.border),
          const SizedBox(height: 12),

          /// 5. 🚀 أزرار التنقل المضافة (Previous و Next) للتنقل بين مراجعة الأسئلة كما كانت بصفحة الحل
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: _currentReviewQuestion > 1
                    ? () => setState(() => _currentReviewQuestion--)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                label: const Text('Previous',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13),),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textGray,
                  side: BorderSide(color: AppColors.border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _currentReviewQuestion < 20
                    ? () => setState(() => _currentReviewQuestion++)
                    : null,
                icon: const Text('Next Question',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13),),
                label: const Icon(Icons.chevron_right_rounded, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ويدجت بناء تبويبات الفلترة لسكشن المراجعة
  Widget _buildReviewTab(int tabIndex, String label) {
    final bool isSelected = _activeTab == tabIndex;
    return InkWell(
      onTap: () => setState(() => _activeTab = tabIndex),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.headerBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  /// ويدجت خيارات الأسئلة المصححة داخل سيكشن المراجعة
  Widget _buildReviewOption(String optionText,
      {required bool isWrongSelected, required bool isCorrectAnswer,}) {
    Color cardBg = AppColors.cardBg;
    Color borderBg = AppColors.border;
    IconData icon = Icons.radio_button_off_rounded;
    Color iconColor = AppColors.textHint;

    if (isWrongSelected) {
      cardBg = AppColors.dangerBg;
      borderBg = AppColors.dangerBorder;
      icon = Icons.cancel_rounded;
      iconColor = AppColors.errorDot;
    } else if (isCorrectAnswer) {
      cardBg = AppColors.successBg;
      borderBg = AppColors.greenBorder;
      icon = Icons.check_circle_rounded;
      iconColor = AppColors.successDot;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderBg),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 12),
          Text(
            optionText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: (isWrongSelected || isCorrectAnswer)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: isWrongSelected
                  ? AppColors.dangerTitle
                  : isCorrectAnswer
                      ? AppColors.successText
                      : AppColors.textGray,
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER FUNCTIONS ---

  Widget _buildMetricCard(String title, String value, String total,
      bool showTrendBelow, String footerText, Widget? trailingIcon,
      {bool showProgressCircle = false,}) {
    return Expanded(
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,),),
                if (trailingIcon != null) trailingIcon,
              ],
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value,
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textTitle,),),
                    if (total.isNotEmpty)
                      Text(total,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHint,),),
                    if (showProgressCircle) ...[
                      const Spacer(),
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          value: widget.isSubmitted ? 0.8 : 0.0,
                          strokeWidth: 3,
                          backgroundColor: AppColors.infoBg,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue.shade600,),
                        ),
                      ),
                    ],
                  ],
                ),
                if (showTrendBelow && widget.isSubmitted) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(6),),
                    child: Text('+2% from last attempt',
                        style: TextStyle(
                            color: AppColors.successText,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,),),
                  ),
                ],
              ],
            ),
            const Spacer(),
            if (!showTrendBelow && footerText.isNotEmpty)
              Text(footerText,
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.3,),),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisItem(
      {required IconData icon,
      required Color iconColor,
      required Color bgColor,
      required Color borderColor,
      required String title,
      required String subtitle,
      bool hasArrow = false,}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTitle,),),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,),),
              ],
            ),
          ),
          if (hasArrow)
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint, size: 20,),
        ],
      ),
    );
  }

  Widget _buildModuleExpansionTile(
      {required String title,
      required List<Widget> children,
      bool isInitiallyExpanded = false,
      bool isCompleted = false,
      bool isCurrentModule = false,
      String? leadingNumber,}) {
    Widget leadingIcon;
    if (isCompleted) {
      leadingIcon = const Icon(Icons.check_circle_outline_rounded,
          color: AppColors.successDot, size: 18,);
    } else if (isCurrentModule) {
      leadingIcon = const Icon(Icons.incomplete_circle_rounded,
          color: AppColors.primary, size: 18,);
    } else {
      leadingIcon = CircleAvatar(
        radius: 9,
        backgroundColor: AppColors.headerBg,
        child: Text(leadingNumber ?? '',
            style: TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,),),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isCurrentModule
                ? AppColors.infoBorder
                : AppColors.border,),
      ),
      child: ExpansionTile(
        initiallyExpanded: isInitiallyExpanded,
        leading: leadingIcon,
        title: Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isCurrentModule
                    ? AppColors.textTitle
                    : AppColors.textGray,),),
        trailing: Icon(
            isInitiallyExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: AppColors.textMuted,
            size: 18,),
        childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
        children: children,
      ),
    );
  }

  Widget _buildContentItem(String title,
      {required bool isCompleted, required bool isCurrent,}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: isCurrent ? AppColors.infoBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),),
      child: Row(
        children: [
          Icon(Icons.play_circle_outline_rounded,
              color:
                  isCurrent ? AppColors.primary : AppColors.textHint,
              size: 16,),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCurrent
                        ? AppColors.primary
                        : AppColors.textMuted,),),
          ),
          if (isCompleted)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.successDot, size: 15,),
        ],
      ),
    );
  }

  Widget _buildQuizItem(String title, {bool isSelectedQuiz = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSelectedQuiz ? AppColors.infoBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border:
            isSelectedQuiz ? Border.all(color: AppColors.infoBorder) : null,
      ),
      child: Row(
        children: [
          Icon(Icons.assignment_outlined,
              color: isSelectedQuiz
                  ? AppColors.primary
                  : AppColors.textHint,
              size: 16,),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        isSelectedQuiz ? FontWeight.w700 : FontWeight.w500,
                    color: isSelectedQuiz
                        ? AppColors.primary
                        : AppColors.textMuted,),),
          ),
          if (isSelectedQuiz)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.successDot, size: 15,),
        ],
      ),
    );
  }

  Widget _buildChatMessage(bool isUser, String message) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.headerBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(12),
          ),
        ),
        child: Text(message,
            style: TextStyle(
                color: isUser ? Colors.white : AppColors.textGray,
                fontSize: 13,
                height: 1.45,),),
      ),
    );
  }

  Widget _buildSuggestionChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,),),
    );
  }
}
