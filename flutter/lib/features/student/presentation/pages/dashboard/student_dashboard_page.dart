import 'package:flutter/material.dart';
import 'package:learnova/core/theme/app_theme.dart';

class StudentDashboardPage extends StatelessWidget {
  const StudentDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // الحفاظ على التصميم المتجاوب (Responsive) بناءً على عرض الشاشة
        final isSmall = constraints.maxWidth < 1150;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: isSmall
              ? const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LeftContent(),
                    SizedBox(height: 24),
                    _RightContent(),
                  ],
                )
              : const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // الجزء الأيسر (العريض) يأخذ نسبة 7 نفس الصورة
                    Expanded(
                      flex: 7,
                      child: _LeftContent(),
                    ),
                    SizedBox(width: 24),
                    // الجزء الأيمن (الجانبي) يأخذ نسبة 3 نفس الصورة
                    Expanded(
                      flex: 3,
                      child: _RightContent(),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// ==========================================
/// الجزء الأيسر (الرئيسي)
/// ==========================================
class _LeftContent extends StatelessWidget {
  const _LeftContent();

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// الترحيب والاسم باللون الداكن المظبوط
        Text(
          'Welcome back, Alex',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppColors.textTitle,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'You have 2 upcoming quizzes and 3 new recommendations.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 24),

        /// صف كروت الإحصائيات الأربعة
        const Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Current GPA',
                value: '3.8',
                percent: '+0.2%',
                icon: Icons.school_outlined,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                title: 'Quizzes Done',
                value: '24',
                percent: '+4%',
                icon: Icons.assignment_turned_in_outlined,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                title: 'Study Hours',
                value: '15h',
                percent: '+12%',
                icon: Icons.access_time_rounded,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                title: 'Accuracy Rate',
                value: '82%',
                percent: '+1.5%',
                icon: Icons.trending_up_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        /// عنوان الكورسات
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Enrolled Courses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textTitle,
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'View All',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        /// كروت الكورسات (اثنين بجانب بعضهما)
        const Row(
          children: [
            Expanded(
              child: _CourseCard(
                title: 'Data Structures & Algo',
                instructor: 'Dr. Sarah Jenkins',
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _CourseCard(
                title: 'Data Structures & Algo',
                instructor: 'Dr. Sarah Jenkins',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        /// قسم تحليلات الذكاء الاصطناعي (AI Insights) بنفس اللون الفاتح الجميل
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: AppColors.primary, size: 18,),
                  const SizedBox(width: 8),
                  Text(
                    'AI Learning Insights',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textTitle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Based on your recent quiz performance in ',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const Text(
                    'Calculus II.',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _InsightRowItem(
                icon: Icons.error_outline_rounded,
                iconColor: AppColors.errorDot,
                iconBg: AppColors.dangerBorder,
                title: 'Weak Topic: Integration by Parts',
                subtitle: 'Your score: 45% (Avg: 78%)',
                buttonText: 'Practice Now',
                isPrimaryButton: true,
              ),
              const SizedBox(height: 12),
              _InsightRowItem(
                icon: Icons.trending_down_rounded,
                iconColor: AppColors.warningText,
                iconBg: AppColors.warningSoftBg,
                title: 'Weak Topic: Chain Rule Application',
                subtitle: 'Your score: 58% (Avg: 82%)',
                buttonText: 'Review Notes',
                isPrimaryButton: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ==========================================
/// الجزء الأيمن الجانبي
/// ==========================================
class _RightContent extends StatelessWidget {
  const _RightContent();

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      children: [
        /// كارت المواعيد النهائية (Upcoming Deadlines)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upcoming Deadlines',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTitle,
                ),
              ),
              const SizedBox(height: 20),
              _buildDeadlineRow(
                  'OCT', '24', 'Midterm Exam', 'Data Structures • 10:00 AM',),
              _buildDeadlineRow('OCT', '28', 'Lab Report Submission',
                  'Physics 101 • 11:59 PM',),
              _buildDeadlineRow('NOV', '02', 'Quiz: Photosynthesis',
                  'Advanced Biology • Online',),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),),
                  ),
                  child: Text(
                    'View Calendar',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        /// كارت النتائج الأخيرة (Recent Results) مع خط الـ Timeline الواصل بينهم
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Results',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTitle,
                ),
              ),
              const SizedBox(height: 20),

              // تم بناء هيكل يدوي هنا لرسم الخط العمودي الرمادي الواصل بين الدوائر كما بالصورة
              Stack(
                children: [
                  Positioned(
                    left: 16,
                    top: 20,
                    bottom: 20,
                    child: Container(
                      width: 2,
                      color: AppColors.headerBg,
                    ),
                  ),
                  Column(
                    children: [
                      _buildResultRow(
                          'A',
                          'Linear Algebra Quiz',
                          '2 hours ago',
                          '95/100',
                          AppColors.successBg,
                          AppColors.successText,),
                      const SizedBox(height: 16),
                      _buildResultRow(
                          'B+',
                          'Organic Chemistry',
                          'Yesterday',
                          '88/100',
                          AppColors.infoBg,
                          AppColors.infoText,),
                      const SizedBox(height: 16),
                      _buildResultRow(
                          'C',
                          'History Essay',
                          '3 days ago',
                          '72/100',
                          AppColors.warningSoftBg,
                          AppColors.warningText,),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeadlineRow(
      String month, String day, String title, String subtitle,) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  month,
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,),
                ),
                Text(
                  day,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textTitle,),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textTitle,),),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textMuted,),),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String grade, String title, String time, String score,
      Color bg, Color text,) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: bg,
          child: Text(grade,
              style: TextStyle(
                  color: text, fontSize: 12, fontWeight: FontWeight.w700,),),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textTitle,),),
              const SizedBox(height: 2),
              Text(time,
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textHint),),
            ],
          ),
        ),
        Text(score,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textTitle,),),
      ],
    );
  }
}

/// ==========================================
/// المكونات الفرعية (Widgets الأزرار والكروت المخصصة)
/// ==========================================

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String percent;
  final IconData icon;

  const _StatCard(
      {required this.title,
      required this.value,
      required this.percent,
      required this.icon,});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,),),
              Icon(icon, color: AppColors.primary, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTitle,),),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(percent,
                    style: const TextStyle(
                        color: AppColors.successDot,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,),),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final String title;
  final String instructor;

  const _CourseCard({required this.title, required this.instructor});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 130,
            width: double.infinity,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              gradient: LinearGradient(
                colors: [Color(0xff092C28), Color(0xff0A192F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),),
                    child: const Text('CS-101',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,),),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTitle,),),
                const SizedBox(height: 2),
                Text(instructor,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMuted,),),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.headerBg,
                      foregroundColor: AppColors.textGray,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),),
                    ),
                    child: const Text('Continue',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,),),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRowItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String buttonText;
  final bool isPrimaryButton;

  const _InsightRowItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.isPrimaryButton,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: iconBg,
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textGray,),),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 11,),),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isPrimaryButton ? AppColors.primary : AppColors.cardBg,
                foregroundColor:
                    isPrimaryButton ? Colors.white : AppColors.textGray,
                elevation: 0,
                side: isPrimaryButton
                    ? BorderSide.none
                    : BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(buttonText,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,),),
            ),
          ),
        ],
      ),
    );
  }
}
