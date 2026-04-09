import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui_components.dart';

class CreateOrgDialog extends StatefulWidget {
  const CreateOrgDialog({super.key});

  @override
  State<CreateOrgDialog> createState() => _CreateOrgDialogState();
}

class _CreateOrgDialogState extends State<CreateOrgDialog> {
  // required by backend
  final _orgName = TextEditingController();
  final _orgDesc = TextEditingController();
  final _logoUrl = TextEditingController();

  // figma-like extra fields (optional UI for now)
  final _primaryDomain = TextEditingController();
  final _location = TextEditingController();
  final _adminName = TextEditingController();
  final _adminEmail = TextEditingController();

  final _nameFocus = FocusNode();
  final _descFocus = FocusNode();

  String _orgType = 'Select type...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _orgName.dispose();
    _orgDesc.dispose();
    _logoUrl.dispose();
    _primaryDomain.dispose();
    _location.dispose();
    _adminName.dispose();
    _adminEmail.dispose();
    _nameFocus.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _orgName.text.trim().isNotEmpty && _orgDesc.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;

    final logo = _logoUrl.text.trim();

    final payload = <String, dynamic>{
      'name': _orgName.text.trim(),
      'description': _orgDesc.text.trim(),
      if (logo.isNotEmpty) 'logo_url': logo,
    };

    Navigator.pop<Map<String, dynamic>>(context, payload);
  }

  Widget _twoFields({
    required bool isNarrow,
    required Widget left,
    required Widget right,
  }) {
    if (isNarrow) {
      return Column(
        children: [
          left,
          const SizedBox(height: 16),
          right,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 20),
        Expanded(child: right),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final isNarrow = w < 860;

        final hPad = isNarrow ? 16.0 : 48.0;
        final topPad = isNarrow ? 22.0 : 44.0;
        final bottomPad = isNarrow ? 20.0 : 36.0;

        return AppDialogShell(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, bottomPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppDialogTitleBlock(
                      title: 'Create New Organization',
                      subtitle:
                          'Set up a new institutional account for your university, school, or research center.',
                    ),
                    const SizedBox(height: 22),

                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppCardHeaderRow(
                            icon: Icons.account_balance_outlined,
                            title: 'Organization Details',
                          ),
                          const SizedBox(height: 18),

                          _twoFields(
                            isNarrow: isNarrow,
                            left: AppLabeledField(
                              label: 'Organization Name',
                              child: AppTextField48(
                                controller: _orgName,
                                focusNode: _nameFocus,
                                hint: 'e.g. Stanford University',
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => _descFocus.requestFocus(),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            right: AppLabeledField(
                              label: 'Organization Type',
                              child: AppDropdown48(
                                value: _orgType,
                                items: const [
                                  'Select type...',
                                  'University',
                                  'School',
                                  'Research Center',
                                  'Institute',
                                  'Training Center',
                                ],
                                onChanged: (v) => setState(() => _orgType = v),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          _twoFields(
                            isNarrow: isNarrow,
                            left: AppLabeledField(
                              label: 'Primary Domain',
                              child: AppTextField48(
                                controller: _primaryDomain,
                                hint: 'e.g. stanford.edu',
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                            right: AppLabeledField(
                              label: 'Location',
                              child: AppTextField48(
                                controller: _location,
                                hint: 'e.g. Palo Alto, CA',
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          AppLabeledField(
                            label: 'Description (max 50 chars)',
                            child: AppTextField48(
                              controller: _orgDesc,
                              focusNode: _descFocus,
                              hint: 'Short description',
                              maxLen: 50,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),

                          const SizedBox(height: 18),

                          AppLabeledField(
                            label: 'Organization Logo',
                            child: AppLogoUrlUploader(
                              controller: _logoUrl,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),

                          const SizedBox(height: 22),
                          const Divider(height: 1, color: Color(0xFFEEF2F4)),
                          const SizedBox(height: 18),

                          const AppSubHeaderText(title: 'Primary Administrator'),
                          const SizedBox(height: 14),

                          _twoFields(
                            isNarrow: isNarrow,
                            left: AppLabeledField(
                              label: 'Full Name',
                              child: AppTextField48(
                                controller: _adminName,
                                hint: 'e.g. Alex Morgan',
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                            right: AppLabeledField(
                              label: 'Administrator Email',
                              child: AppTextField48(
                                controller: _adminEmail,
                                hint: 'admin@university.edu',
                                textInputAction: TextInputAction.done,
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          const AppInfoInlineBox(
                            message:
                                'Need help? Chat with our support team or learn more about how organizations work.',
                          ),

                          const SizedBox(height: 22),

                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              spacing: 14,
                              runSpacing: 12,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.title,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: _canSubmit ? _submit : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    disabledBackgroundColor:
                                        const Color(0xFF93C5FD),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    minimumSize: const Size(0, 48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Create Organization',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    const Center(
                      child: Text(
                        '© 2024 Learnova Academic Platform. All rights reserved.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 20 / 14,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
