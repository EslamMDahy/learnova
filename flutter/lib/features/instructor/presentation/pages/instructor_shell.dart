import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/storage/user_storage.dart';
import '../../../../core/ui/toast.dart';
import '../../../../features/auth/data/auth_providers.dart';

import '../../../../shared/widgets/base_dashboard_shell.dart';
import '../../../../shared/widgets/top_header.dart';

import '../instructor_tabs.dart';
import '../widgets/sidebar.dart';

class InstructorShell extends ConsumerStatefulWidget {
  final Widget child;
  const InstructorShell({super.key, required this.child});

  @override
  ConsumerState<InstructorShell> createState() => _InstructorShellState();
}

class _InstructorShellState extends ConsumerState<InstructorShell> {
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
    // fallback: show role-based name matching Figma "Prof. Anderson"
    return 'Instructor';
  }

  /// Returns org name or role subtitle for the top header.
  /// Matches Figma: "Computer Science Dept."
  String _displaySubtitle() {
    final orgs = UserStorage.organizations;
    if (orgs.isNotEmpty) {
      final orgName = (orgs.first['name'] ?? '').toString().trim();
      if (orgName.isNotEmpty) return orgName;
    }
    return 'Instructor Portal';
  }

  int _selectedIndexFromPath(String path) {
    if (path.startsWith(Routes.instructorDashboard)) return InstructorTabs.dashboard;
    if (path.startsWith(Routes.instructorCourses)) return InstructorTabs.course;
    if (path.startsWith(Routes.instructorExamCorrection)) return InstructorTabs.examCorrection;
    if (path.startsWith(Routes.instructorQuizzes)) return InstructorTabs.quizzes;
    if (path.startsWith(Routes.instructorSettings)) return InstructorTabs.settings;
    if (path.startsWith(Routes.instructorHelp)) return InstructorTabs.help;

    return InstructorTabs.dashboard;
  }

  void _goByIndex(int index) {
    switch (index) {
      case InstructorTabs.dashboard:
        context.go(Routes.instructorDashboard);
        return;
      case InstructorTabs.course:
        context.go(Routes.instructorCourses);
        return;
      case InstructorTabs.examCorrection:
        context.go(Routes.instructorExamCorrection);
        return;
      case InstructorTabs.quizzes:
        context.go(Routes.instructorQuizzes);
        return;
      case InstructorTabs.settings:
        context.go(Routes.instructorSettings);
        return;
      case InstructorTabs.help:
        context.go(Routes.instructorHelp);
        return;
    }
  }

  Future<void> _logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
      if (!mounted) return;
      context.go(Routes.login);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(
        context,
        title: 'Logout failed',
        message: e.toString(),
      );
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

          sidebar: InstructorSidebarWidget(
            selectedIndex: _selectedIndexFromPath(path),
            onItemSelected: _goByIndex,
          ),

          header: TopHeaderWidget(
            searchController: _search,
            onSearchChanged: (_) => setState(() {}),
            searchHint: 'Search your courses, lessons, or students...',
            userName: _displayName(),
            userSubtitle: _displaySubtitle(),
            avatarUrl: UserStorage.avatarUrl,
            onNotificationsTap: () => context.go(Routes.instructorNotifications),
            onSettings: () => context.go(Routes.instructorSettings),
            onLogout: () async => _logout(),
          ),

          child: widget.child,
        );
      },
    );
  }
}
