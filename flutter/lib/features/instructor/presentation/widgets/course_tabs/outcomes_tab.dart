import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../data/courses_models.dart';
import '../course_outcomes_panel.dart';

class CourseOutcomesTab extends StatelessWidget {
  final MyCourseItem course;

  const CourseOutcomesTab({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.pageBg,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: CourseOutcomesManager(courseId: course.id, embedded: true),
      ),
    );
  }
}
