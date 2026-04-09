import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../data/learning_outcomes_models.dart';
import '../../../data/topics_models.dart';

class TopicOverviewSnapshotCard extends StatelessWidget {
  final TopicItem topic;
  final List<LearningOutcome> mappedOutcomes;

  const TopicOverviewSnapshotCard({
    super.key,
    required this.topic,
    required this.mappedOutcomes,
  });

  @override
  Widget build(BuildContext context) {
    return _TopicSectionCard(
      title: 'Topic Snapshot',
      icon: Icons.grid_view_rounded,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.bolt_rounded,
                  iconColor: AppColors.primary,
                  iconBg: const Color(0xFFEFF6FF),
                  label: 'Readiness',
                  value: topic.readiness == TopicReadiness.ready
                      ? 'Ready'
                      : topic.readiness == TopicReadiness.review
                          ? 'Needs review'
                          : 'Draft',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  icon: Icons.trending_up_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  iconBg: const Color(0xFFF5F3FF),
                  label: 'Difficulty',
                  value: topic.difficulty.label,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.flag_outlined,
                  iconColor: const Color(0xFF16A34A),
                  iconBg: const Color(0xFFF0FDF4),
                  label: 'Outcomes',
                  value: mappedOutcomes.isEmpty ? 'Not mapped' : '${mappedOutcomes.length} linked',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  icon: Icons.schedule_rounded,
                  iconColor: const Color(0xFFD97706),
                  iconBg: const Color(0xFFFFFBEB),
                  label: 'Study time',
                  value: topic.estimatedDurationMinutes == null
                      ? 'Flexible'
                      : '~${topic.estimatedDurationMinutes} min',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TopicAlignmentCard extends StatelessWidget {
  final List<LearningOutcome> mappedOutcomes;

  const TopicAlignmentCard({super.key, required this.mappedOutcomes});

  @override
  Widget build(BuildContext context) {
    return _TopicSectionCard(
      title: 'Learning Outcome Alignment',
      icon: Icons.outlined_flag_rounded,
      child: mappedOutcomes.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'No learning outcomes are linked yet. Use Manage to connect this topic to one or more course outcomes.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.6),
              ),
            )
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: mappedOutcomes
                  .map(
                    (lo) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Text(
                        '${lo.code} • ${(lo.description ?? lo.title).trim()}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class TopicInsightsCard extends StatelessWidget {
  final TopicItem topic;
  final int mappedOutcomesCount;

  const TopicInsightsCard({
    super.key,
    required this.topic,
    required this.mappedOutcomesCount,
  });

  @override
  Widget build(BuildContext context) {
    final List<_InsightItem> items = [
      _InsightItem(
        icon: Icons.lightbulb_outline_rounded,
        title: 'Delivery focus',
        body: topic.readiness == TopicReadiness.ready
            ? 'This topic is ready for delivery. Focus on examples and assessment calibration.'
            : 'Use Manage to refine the topic before pushing it into live delivery.',
      ),
      _InsightItem(
        icon: Icons.map_outlined,
        title: 'Assessment hint',
        body: mappedOutcomesCount == 0
            ? 'Map at least one learning outcome before building question coverage for this topic.'
            : 'This topic is already connected to outcomes, so question generation can stay aligned.',
      ),
      _InsightItem(
        icon: Icons.auto_awesome_outlined,
        title: 'Instructor tip',
        body: topic.instructorNotes?.trim().isNotEmpty ?? false
            ? 'You already have instructor notes. Keep them updated with examples, pitfalls, and pacing advice.'
            : 'Add quick instructor notes to capture misconceptions, good examples, or delivery reminders.',
      ),
    ];

    return _TopicSectionCard(
      title: 'Instructor Insights',
      icon: Icons.insights_rounded,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Icon(items[i].icon, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTitle,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].body,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (i != items.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class TopicNotesCard extends StatelessWidget {
  final TopicItem topic;

  const TopicNotesCard({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final hasNotes = topic.instructorNotes?.trim().isNotEmpty ?? false;
    return _TopicSectionCard(
      title: 'Instructor Notes',
      icon: Icons.sticky_note_2_outlined,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          hasNotes
              ? topic.instructorNotes!.trim()
              : 'No notes yet. Use Manage to add delivery notes, examples, misconceptions, or assessment guidance.',
          style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.7),
        ),
      ),
    );
  }
}

class _TopicSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _TopicSectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEDEDED))),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTitle,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textTitle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightItem {
  final IconData icon;
  final String title;
  final String body;

  const _InsightItem({required this.icon, required this.title, required this.body});
}
