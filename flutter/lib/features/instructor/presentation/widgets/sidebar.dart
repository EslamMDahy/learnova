import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_sidebar.dart';
import '../instructor_tabs.dart';

class InstructorSidebarWidget extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const InstructorSidebarWidget({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AppSidebar(
      selectedIndex: selectedIndex,
      onItemSelected: onItemSelected,
      portalSubtitle: 'INSTRUCTOR Portal',
      mainItems: const [
        AppSidebarItem(icon: Icons.grid_view_rounded, title: 'Dashboard', index: InstructorTabs.dashboard),
        AppSidebarItem(icon: Icons.menu_book_rounded, title: 'My Courses', index: InstructorTabs.course),
        AppSidebarItem(icon: Icons.document_scanner_outlined, title: 'Exam Correction', index: InstructorTabs.examCorrection),
        AppSidebarItem(icon: Icons.quiz_outlined, title: 'Quizzes', index: InstructorTabs.quizzes),
      ],
      bottomItems: const [
        AppSidebarItem(icon: Icons.settings_outlined, title: 'Settings', index: InstructorTabs.settings),
        AppSidebarItem(icon: Icons.help_outline_rounded, title: 'Help & Support', index: InstructorTabs.help),
      ],
    );
  }
}
