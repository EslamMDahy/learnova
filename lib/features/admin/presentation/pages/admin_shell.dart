import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/storage/user_storage.dart';
import '../../../../core/ui/toast.dart';
import '../../../../features/auth/data/auth_providers.dart';
import '../../../../shared/widgets/base_dashboard_shell.dart';
import '../../../../shared/widgets/top_header.dart';

import '../admin_tabs.dart';
import '../controllers/admin_dashboard_controller.dart';
import '../controllers/admin_dashboard_state.dart';
import '../widgets/sidebar.dart';

class AdminShell extends ConsumerStatefulWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
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

  
  String _resolveOrgId(AdminDashboardState state) {
    final s = (state.organizationId ?? '').trim();
    if (s.isNotEmpty) return s;

    final me = UserStorage.meJson ?? const <String, dynamic>{};

    final selected = me['selected_organization_id']?.toString().trim();
    if (selected != null && selected.isNotEmpty) return selected;

    final orgs = UserStorage.organizations;
    if (orgs.isNotEmpty) {
      final id = orgs.first['id']?.toString().trim();
      if (id != null && id.isNotEmpty) return id;
    }

    return '';
  }

  String _displayName() {
    final me = UserStorage.meJson;
    final user = me?['user'];
    if (user is Map) {
      final name = user['full_name']?.toString();
      if (name != null && name.trim().isNotEmpty) return name.trim();
    }
    return 'Admin';
  }

  int _selectedIndexFromPath(String path) {
    if (path.startsWith(Routes.adminUsers)) return AdminTabs.users;
    if (path.startsWith(Routes.adminJoinRequests)) return AdminTabs.joinRequests;
    if (path.startsWith(Routes.adminUpgradePlans)) return AdminTabs.upgradePlans;
    if (path.startsWith(Routes.adminSettings)) return AdminTabs.settings;
    if (path.startsWith(Routes.adminHelp)) return AdminTabs.help;
    return AdminTabs.users;
  }

  void _goByIndex(int index) {
    switch (index) {
      case AdminTabs.users:
        context.go(Routes.adminUsers);
        return;
      case AdminTabs.joinRequests:
        context.go(Routes.adminJoinRequests);
        return;
      case AdminTabs.upgradePlans:
        context.go(Routes.adminUpgradePlans);
        return;
      case AdminTabs.settings:
        context.go(Routes.adminSettings);
        return;
      case AdminTabs.help:
        context.go(Routes.adminHelp);
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
    final state = ref.watch(adminDashboardControllerProvider);
    final path = GoRouterState.of(context).uri.path;

    final orgId = _resolveOrgId(state);
    final hasOrg = orgId.isNotEmpty;

    return ValueListenableBuilder<int>(
      valueListenable: UserStorage.listenable as ValueNotifier<int>,
      builder: (context, _, __) {
        return BaseDashboardShell(
          sidebar: AdminSidebarWidget(
            selectedIndex: _selectedIndexFromPath(path),
            onItemSelected: _goByIndex,
          ),

          header: TopHeaderWidget(
            searchController: _search,
            onSearchChanged: (_) => setState(() {}),
            searchHint: 'Search users, join requests, or plans...',
            userName: _displayName(),
            userSubtitle:
                hasOrg ? 'Organization Admin Portal' : 'Setup your organization',
            avatarUrl: UserStorage.avatarUrl,
            onNotificationsTap: () => context.go(Routes.adminNotifications),
            onSettings: () => context.go(Routes.adminSettings),
            onLogout: () async => _logout(),
          ),

          child: widget.child,
        );
      },
    );
  }
}
