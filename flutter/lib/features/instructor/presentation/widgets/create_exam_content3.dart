import 'package:flutter/material.dart';
import 'package:learnova/core/theme/app_theme.dart';

class CreateExamContent3 extends StatefulWidget {
  const CreateExamContent3({super.key});

  @override
  State<CreateExamContent3> createState() => _CreateExamContent3State();
}

class _CreateExamContent3State extends State<CreateExamContent3> {
  
  bool _shuffleQuestions = true;
  bool _showResults = false;
  bool _oneAtATime = false;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildTimingAttemptsCard(),
              const SizedBox(height: 24),
              _buildDisplaySecurityCard(),
            ],
          ),
        ),
        const SizedBox(width: 32),
        
        Expanded(child: _buildQuizSummaryCard()),
      ],
    );
  }

  
  Widget _buildTimingAttemptsCard() {
    return _buildSectionCard(
      icon: Icons.timer_outlined,
      iconColor: AppColors.primary,
      title: 'Timing & Attempts',
      subtitle: 'Control how students access and take the quiz.',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'Time Limit',
                  hint: '60',
                  suffix: 'Minutes',
                  helperText: 'Leave blank for no time limit.',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildDropdownField(
                  label: 'Allowed Attempts',
                  value: 'Unlimited',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Grading Criteria',
                  value: 'Highest Score',
                  helperText:
                      'Determines which score is recorded in the gradebook.',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildInputField(
                  label: 'Due Date',
                  hint: 'mm/dd/yyyy, --:-- --',
                  suffixIcon: Icons.calendar_today_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  
  Widget _buildDisplaySecurityCard() {
    return _buildSectionCard(
      icon: Icons.settings_outlined,
      iconColor: Colors.purple,
      title: 'Display & Security',
      subtitle: 'Manage question behavior and result visibility.',
      child: Column(
        children: [
          _buildSwitchTile(
            title: 'Shuffle Questions',
            subtitle:
                'Randomize the order of questions for each student attempt.',
            value: _shuffleQuestions,
            onChanged: (v) => setState(() => _shuffleQuestions = v),
          ),
          const Divider(height: 32),
          _buildSwitchTile(
            title: 'Show Results Immediately',
            subtitle:
                'Students see their score and correct answers upon submission.',
            value: _showResults,
            onChanged: (v) => setState(() => _showResults = v),
          ),
          const Divider(height: 32),
          _buildSwitchTile(
            title: 'One Question at a Time',
            subtitle:
                'Prevent students from seeing upcoming questions or going back.',
            value: _oneAtATime,
            onChanged: (v) => setState(() => _oneAtATime = v),
          ),
        ],
      ),
    );
  }

  
  Widget _buildQuizSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quiz Summary',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.textGray,
            ),
          ),
          const SizedBox(height: 24),
          _summaryRow('Total Questions', '15'),
          Divider(height: 32, color: AppColors.headerBg),
          _summaryRow('Total Points', '100'),
          Divider(height: 32, color: AppColors.headerBg),
          _summaryRow('Difficulty', 'Medium', color: Colors.orange),
          const SizedBox(height: 24),
          _buildInfoBox(),
          const SizedBox(height: 24),
          _summaryButton(
            Icons.visibility_outlined,
            'Preview as Student',
            AppColors.textTitle,
          ),
        ],
      ),
    );
  }

  

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    String? suffix,
    IconData? suffixIcon,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            suffixIcon: suffixIcon != null ? Icon(suffixIcon, size: 20) : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.border),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value, style: const TextStyle(fontSize: 14)),
              const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
            ],
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primary),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color ?? AppColors.textGray,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This quiz is currently saved as a draft. Publishing will make it visible to enrolled students immediately or on the scheduled date.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryButton(IconData icon, String label, Color bg) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
