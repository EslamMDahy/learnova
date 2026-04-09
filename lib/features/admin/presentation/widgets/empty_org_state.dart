import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui_components.dart';

class EmptyOrgState extends StatelessWidget {
  final VoidCallback onCreateOrganizationPressed;

  const EmptyOrgState({
    super.key,
    required this.onCreateOrganizationPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: 'No Organization Found',
      message:
          "Welcome to Learnova. You haven't set up or joined an organization\n"
          'yet. Create a new organization to start using the Smart Study\n'
          'Companion management tools.',
      primaryActionLabel: 'Create Your Organization',
      onPrimaryAction: onCreateOrganizationPressed,
    );
  }
}
