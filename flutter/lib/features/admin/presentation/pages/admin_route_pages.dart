import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/toast.dart';
import '../../../../shared/pages/notifications_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../controllers/admin_dashboard_controller.dart';
import '../controllers/admin_dashboard_state.dart';
import '../widgets/create_org_dialog.dart';
import '../widgets/empty_org_state.dart';
import '../widgets/join_requests_content.dart';
import '../widgets/upgrade_plans_content.dart';
import '../widgets/user_management_content.dart';

String _resolveOrgId(AdminDashboardState state) {
  final s = (state.organizationId ?? '').trim();
  if (s.isNotEmpty) return s;

  
  return '';
}

class AdminUsersRoutePage extends ConsumerWidget {
  const AdminUsersRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminDashboardControllerProvider);
    final ctrl = ref.read(adminDashboardControllerProvider.notifier);

    final orgId = _resolveOrgId(state);
    final hasOrg = orgId.isNotEmpty;

    if (!hasOrg) {
      return EmptyOrgState(
        onCreateOrganizationPressed: () async {
          final data = await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (_) => const CreateOrgDialog(),
          );
          if (data == null) return;

          final name = (data['name'] ?? '').toString().trim();
          final desc = (data['description'] ?? '').toString().trim();
          final logo = (data['logo_url'] ?? '').toString().trim();

          if (name.isEmpty || desc.isEmpty) {
            AppToast.error(
              context,
              title: 'Missing info',
              message: 'Organization name and description are required.',
            );
            return;
          }

          await ctrl.createOrganization(
            name: name,
            description: desc,
            logoUrl: logo.isEmpty ? null : logo,
          );
        },
      );
    }

    return UserManagementContent(organizationId: orgId);
  }
}

class AdminJoinRequestsRoutePage extends ConsumerWidget {
  const AdminJoinRequestsRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminDashboardControllerProvider);
    final orgId = _resolveOrgId(state);
    final hasOrg = orgId.isNotEmpty;

    if (!hasOrg) {
      return const Center(child: Text('Create an organization first.'));
    }

    return JoinRequestsContent(organizationId: orgId);
  }
}

class AdminUpgradePlansRoutePage extends StatelessWidget {
  const AdminUpgradePlansRoutePage({super.key});
  @override
  Widget build(BuildContext context) => const UpgradePlansContent();
}

class AdminSettingsRoutePage extends StatelessWidget {
  const AdminSettingsRoutePage({super.key});
  @override
  Widget build(BuildContext context) => const SettingsPage();
}

class AdminNotificationsRoutePage extends StatelessWidget {
  const AdminNotificationsRoutePage({super.key});
  @override
  Widget build(BuildContext context) => const NotificationsPage();
}

class AdminHelpRoutePage extends StatelessWidget {
  const AdminHelpRoutePage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Help & Support (Coming soon)'));
  }
}
