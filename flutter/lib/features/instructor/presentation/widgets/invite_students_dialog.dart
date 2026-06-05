import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learnova/core/theme/app_theme.dart';
import 'package:learnova/core/ui/toast.dart';
import 'package:learnova/features/instructor/data/courses_providers.dart';

class InviteStudentsDialog extends ConsumerStatefulWidget {
  final int courseId;
  const InviteStudentsDialog({super.key, required this.courseId});

  @override
  ConsumerState<InviteStudentsDialog> createState() =>
      _InviteStudentsDialogState();
}

class _InviteStudentsDialogState extends ConsumerState<InviteStudentsDialog> {
  bool _loading = false;
  PlatformFile? _pickedFile;

  // ألوان التصميم الجديد
  Color get _accentColor => AppColors.primary;
  Color get _bgLight => AppColors.surfaceBg;
  Color get _border => AppColors.border;


  Future<void> _downloadTemplate() async {
    AppToast.info(
      context,
      title: 'Template format',
      message: 'Use an .xlsx spreadsheet with one column named email.',
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );

    if (!mounted || result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final name = file.name.toLowerCase();
    final valid = name.endsWith('.xlsx');

    if (!valid) {
      AppToast.error(
        context,
        title: 'Invalid file',
        message: 'Please choose a valid .xlsx file.',
      );
      return;
    }

    setState(() => _pickedFile = file);
  }

  Future<void> _submit() async {
    final file = _pickedFile;
    final bytes = file?.bytes;

    if (file == null || bytes == null || bytes.isEmpty) {
      AppToast.error(
        context,
        title: 'No file selected',
        message: 'Choose a valid .xlsx file before uploading.',
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final repo = ref.read(coursesRepositoryProvider);
      await repo.uploadInvitationsFile(
        courseId: widget.courseId.toString(),
        bytes: bytes,
        filename: file.name,
      );

      if (!mounted) return;
      AppToast.success(
        context,
        title: 'Invitations ready',
        message: 'Students were uploaded and invitations were sent.',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(
        context,
        title: 'Upload failed',
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        width: 550,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTemplateSection(),
                    const SizedBox(height: 24),
                    _buildUploadZone(),
                    const SizedBox(height: 24),
                    _buildSettingsToggle(),
                    const SizedBox(height: 32),
                    _buildActions(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _bgLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.group_add_rounded, color: _accentColor, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite Students',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textTitle,
                ),
              ),
              Text(
                'Import your student list via .xlsx',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Please use our official template for a smooth import.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textTitle,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _downloadTemplate,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download'),
            style: TextButton.styleFrom(foregroundColor: Colors.amber[900]),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadZone() {
    return InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
      onTap: _pickFile,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: _pickedFile != null
              ? _accentColor.withOpacity(0.02)
              : _bgLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _pickedFile != null ? _accentColor : _border,
            style: _pickedFile != null ? BorderStyle.solid : BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _pickedFile != null
                  ? Icons.insert_drive_file_rounded
                  : Icons.cloud_upload_outlined,
              size: 48,
              color: _pickedFile != null ? _accentColor : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _pickedFile != null
                  ? _pickedFile!.name
                  : 'Click to select or drag file',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _pickedFile != null
                    ? _accentColor
                    : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _pickedFile != null
                  ? '${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB'
                  : 'Supports .xlsx files with an email column',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_read_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Automatic email sending',
                  style: TextStyle(
                    color: AppColors.textTitle,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The backend sends invitations automatically after a successful upload.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.cardBg,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Upload & Continue',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
          ),
        ),
      ],
    );
  }
}
