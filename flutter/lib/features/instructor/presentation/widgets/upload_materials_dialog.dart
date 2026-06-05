import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// Upload Course Materials dialog.
/// NOTE: Backend currently validates PDF only (max 50MB).
class UploadMaterialsDialog extends StatefulWidget {
  const UploadMaterialsDialog({super.key});

  @override
  State<UploadMaterialsDialog> createState() => _UploadMaterialsDialogState();
}

class _UploadMaterialsDialogState extends State<UploadMaterialsDialog> {
  final bool _isDragging = false;

  static Color get _border => AppColors.border;
  static Color get _text => AppColors.textTitle;
  static Color get _muted => AppColors.textMuted;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Dialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────────
              Text(
                'Upload Course Materials',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _text,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 13.5, color: _muted, height: 1.5),
                  children: [
                    const TextSpan(text: 'Add resources for the AI to analyze and generate study aids.\n'),
                    const TextSpan(text: 'Supported formats: '),
                    TextSpan(
                      text: 'PDF only',
                      style: TextStyle(fontWeight: FontWeight.w700, color: _text),
                    ),
                    const TextSpan(text: '. Max file size: '),
                    TextSpan(
                      text: '50MB',
                      style: TextStyle(fontWeight: FontWeight.w700, color: _text),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Body: drag-drop + queue ────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _DragDropArea(isDragging: _isDragging)),
                  const SizedBox(width: 20),
                  const Expanded(flex: 2, child: _UploadQueue()),
                ],
              ),

              const SizedBox(height: 28),

              // ── Footer ─────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _border),
                      foregroundColor: _muted,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.save_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'Save to Course',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Drag & Drop Area ──────────────────────────────────────────────────────────

class _DragDropArea extends StatelessWidget {
  final bool isDragging;
  const _DragDropArea({required this.isDragging});

  static Color get _blue => AppColors.primary;
  static Color get _blueCircle => AppThemeRuntime.isDark ? const Color(0xFF172554) : const Color(0xFFD0EAFC);
  static Color get _bg => AppColors.pageBg;
  static Color get _borderColor => AppColors.border;
  static Color get _muted => AppColors.textMuted;
  static Color get _text => AppColors.textTitle;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      children: [
        // Drop zone
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 260,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDragging ? AppColors.infoBg : _bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDragging ? _blue : _borderColor,
              width: isDragging ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _blueCircle,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 36,
                  color: _blue,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Drag & Drop files here',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'or click to browse from your computer.',
                style: TextStyle(fontSize: 13, color: _muted),
              ),
              const SizedBox(height: 4),
              Text(
                'AI processing will start automatically upon upload.',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Browse Files',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Guidelines box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GuideRow(
                icon: Icons.info_outline_rounded,
                text: 'Ensure scanned PDFs have OCR enabled for better AI analysis.',
              ),
              SizedBox(height: 8),
              _GuideRow(
                icon: Icons.info_outline_rounded,
                text: 'Video lectures should have clear audio for accurate transcription.',
              ),
              SizedBox(height: 8),
              _GuideRow(
                icon: Icons.info_outline_rounded,
                text: 'Multiple files can be uploaded simultaneously.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _GuideRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4),
          ),
        ),
      ],
    );
  }
}

// ── Upload Queue ──────────────────────────────────────────────────────────────

class _UploadQueue extends StatelessWidget {
  const _UploadQueue();

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Queue header
          Row(
            children: [
              Text(
                'Upload Queue',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textTitle,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '3 Files',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // File items
          const _QueueItem(
            icon: Icons.picture_as_pdf_rounded,
            iconColor: AppColors.errorDot,
            name: 'Lecture_04_Neural_Nets.pdf',
            sub: '2.4 MB',
            progress: 0.45,
            progressLabel: 'Uploading... 45%',
            showClose: true,
          ),
          const SizedBox(height: 14),
          const _QueueItem(
            icon: Icons.description_rounded,
            iconColor: AppColors.primary,
            name: 'Assignment_Brief_v2.docx',
            sub: 'AI Analyzing Content...',
            isAnalyzing: true,
          ),
          const SizedBox(height: 14),
          _QueueItem(
            icon: Icons.video_file_rounded,
            iconColor: AppColors.purpleText,
            name: 'Guest_Speaker_Session.mp4',
            sub: 'Ready for Review',
            isDone: true,
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.border),
                foregroundColor: AppColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Clear Completed',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String name;
  final String sub;
  final double? progress;
  final String? progressLabel;
  final bool isDone;
  final bool isAnalyzing;
  final bool showClose;

  const _QueueItem({
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.sub,
    this.progress,
    this.progressLabel,
    this.isDone = false,
    this.isAnalyzing = false,
    this.showClose = false,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTitle,
                      ),
                    ),
                  ),
                  if (showClose)
                    Icon(Icons.close, size: 16, color: AppColors.textHint),
                ],
              ),
              const SizedBox(height: 3),
              if (progress != null) ...[ 
                Text(
                  progressLabel ?? sub,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ] else if (isAnalyzing) ...[ 
                Row(
                  children: [
                    Icon(Icons.sync_rounded, size: 13, color: AppColors.purpleText),
                    const SizedBox(width: 4),
                    Text(
                      'AI Analyzing Content...',
                      style: TextStyle(fontSize: 11, color: AppColors.purpleText),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation(AppColors.purpleText),
                ),
              ] else if (isDone) ...[ 
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 13, color: AppColors.successText),
                    const SizedBox(width: 4),
                    Text(
                      'Ready for Review',
                      style: TextStyle(fontSize: 11, color: AppColors.successText),
                    ),
                  ],
                ),
              ] else ...[
                Text(sub, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
