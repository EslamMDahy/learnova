import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_sidebar.dart';

class StudentSidebarWidget extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const StudentSidebarWidget({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AppSidebar(
      selectedIndex: selectedIndex,
      onItemSelected: onItemSelected,
      portalSubtitle: 'STUDENT Portal',
      mainItems: const [
        AppSidebarItem(
          icon: Icons.grid_view_rounded,
          title: 'Dashboard',
          index: 0,
        ),
        AppSidebarItem(
          icon: Icons.menu_book_rounded,
          title: 'My Courses',
          index: 1,
        ),
        AppSidebarItem(
          icon: Icons.quiz_outlined,
          title: 'Question Bank',
          index: 2,
        ),
        AppSidebarItem(
          icon: Icons.history_rounded,
          title: 'Quiz History',
          index: 3,
        ),
        AppSidebarItem(
          icon: Icons.auto_awesome_rounded,
          title: 'Recommendations',
          index: 4,
        ),
      ],
      bottomItems: const [
        AppSidebarItem(
          icon: Icons.settings_outlined,
          title: 'Settings',
          index: 5,
        ),
        AppSidebarItem(
          icon: Icons.help_outline_rounded,
          title: 'Help & Support',
          index: 6,
        ),
      ],
    );
  }
}
