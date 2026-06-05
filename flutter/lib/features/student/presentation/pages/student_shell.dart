import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learnova/core/routing/routes.dart';

import '../../../../core/storage/user_storage.dart';

import '../../../../shared/widgets/base_dashboard_shell.dart';
import '../../../../shared/widgets/top_header.dart';

import '../widgets/student_sidebar.dart';

class StudentShell extends ConsumerStatefulWidget {
  final Widget child;

  const StudentShell({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends ConsumerState<StudentShell> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _displayName() {
    final name = (UserStorage.userMap?['full_name'] ?? '').toString().trim();

    if (name.isNotEmpty) return name;

    return 'Student';
  }

  String _displaySubtitle() {
    final orgs = UserStorage.organizations;

    if (orgs.isNotEmpty) {
      final orgName = (orgs.first['name'] ?? '').toString().trim();

      if (orgName.isNotEmpty) return orgName;
    }

    return 'Student Portal';
  }

  int _selectedIndexFromPath(String path) {
    if (path.startsWith(Routes.studentDashboard)) {
      return 0;
    }

    if (path.startsWith(Routes.studentCourses)) {
      return 1;
    }

    if (path.startsWith(Routes.studentQuestionBank)) {
      return 2;
    }

    if (path.startsWith(Routes.studentQuizHistory)) {
      return 3;
    }

    if (path.startsWith(Routes.studentRecommendations)) {
      return 4;
    }

    if (path.startsWith(Routes.studentSettings)) {
      return 5;
    }

    if (path.startsWith(Routes.studentHelp)) {
      return 6;
    }

    return 0;
  }

  void _goByIndex(int index) {
    switch (index) {
      case 0:
        context.go(Routes.studentDashboard);
        return;

      case 1:
        context.go(Routes.studentCourses);
        return;

      case 2:
        context.go(Routes.studentQuestionBank);
        return;

      case 3:
        context.go(Routes.studentQuizHistory);
        return;

      case 4:
        context.go(Routes.studentRecommendations);
        return;

      case 5:
        context.go(Routes.studentSettings);
        return;

      case 6:
        context.go(Routes.studentHelp);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;

    return ValueListenableBuilder<int>(
      valueListenable: UserStorage.listenable as ValueNotifier<int>,
      builder: (context, _, __) {
        return BaseDashboardShell(
          wrapChild: false,

          /// SIDEBAR
          sidebar: StudentSidebarWidget(
            selectedIndex: _selectedIndexFromPath(path),
            onItemSelected: _goByIndex,
          ),

          /// HEADER
          header: TopHeaderWidget(
            searchController: _search,
            onSearchChanged: (_) => setState(() {}),
            searchHint: 'Search topics, questions, or courses...',
            userName: _displayName(),
            userSubtitle: _displaySubtitle(),
            avatarUrl: UserStorage.avatarUrl,
            onNotificationsTap: () {
              context.go(Routes.studentNotifications);
            },
            onSettings: () {
              context.go(Routes.studentSettings);
            },
          ),

          /// CONTENT
          child: widget.child,
        );
      },
    );
  }
}
