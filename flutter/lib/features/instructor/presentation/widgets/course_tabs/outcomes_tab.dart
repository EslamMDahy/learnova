import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../data/courses_models.dart';
import '../course_outcomes_panel.dart';

class CourseOutcomesTab extends StatelessWidget {
  final MyCourseItem course;

  const CourseOutcomesTab({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.pageBg,
      child: CourseOutcomesManager(courseId: course.id, embedded: true),
    );
  }
}
