import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/browser_file_picker.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Result
// ─────────────────────────────────────────────────────────────────────────────
class UploadSheetResult {
  final Uint8List bytes;
  final String filename;
  final String contentType;
  final String title;
  const UploadSheetResult({
    required this.bytes,
    required this.filename,
    required this.contentType,
    required this.title,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────────────────────────────────────
enum _FileStatus { ready, error }

class _QueuedFile {
  final String name;
  final int sizeBytes;
  final Uint8List bytes;
  final _FileStatus status;
  final String? errorMsg;
  const _QueuedFile({
    required this.name,
    required this.sizeBytes,
    required this.bytes,
    required this.status,
    this.errorMsg,
  });

  String get displaySize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1048576) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / 1048576).toStringAsFixed(1)} MB';
  }

  String get ext {
    final i = name.lastIndexOf('.');
    return i >= 0 ? name.substring(i + 1).toUpperCase() : 'FILE';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Dialog
// ─────────────────────────────────────────────────────────────────────────────
class UploadMaterialSheet extends StatefulWidget {
  final String moduleTitle;
  const UploadMaterialSheet({super.key, required this.moduleTitle});

  @override
  State<UploadMaterialSheet> createState() => _UploadMaterialSheetState();
}

class _UploadMaterialSheetState extends State<UploadMaterialSheet>
    with TickerProviderStateMixin {
  final List<_QueuedFile> _queue = [];
  bool _hovering = false;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;
  static const int _maxBytes = 50 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _browse() async {
    final files = await pickBrowserFiles(
      acceptedExtensions: const ['pdf'],
      multiple: true,
    );
    for (final file in files) {
      _queuePickedFile(file);
    }
  }

  void _queuePickedFile(PickedBrowserFile file) {
    final valid = file.sizeBytes <= _maxBytes && _isSupportedPdf(file);
    setState(() {
      _queue.add(_QueuedFile(
        name: file.name,
        sizeBytes: file.sizeBytes,
        bytes: file.bytes,
        status: valid ? _FileStatus.ready : _FileStatus.error,
        errorMsg: valid ? null : 'Only PDF files are supported right now, up to 50 MB',
      ));
    });
  }

  static final RegExp _pdfExtension = RegExp(r'\.pdf$', caseSensitive: false);

  bool _isSupportedPdf(PickedBrowserFile file) {
    final hasPdfExtension = _pdfExtension.hasMatch(file.name);
    final mime = file.mimeType.trim().toLowerCase();
    final mimeLooksPdf = mime.isEmpty || mime == 'application/pdf';
    return hasPdfExtension && mimeLooksPdf;
  }

  String _contentTypeForUpload(String filename) {
    if (_pdfExtension.hasMatch(filename)) return 'application/pdf';
    throw StateError('Unsupported upload type for $filename');
  }

  void _remove(int i) => setState(() => _queue.removeAt(i));
  void _clearDone() =>
      setState(() => _queue.removeWhere((f) => f.status == _FileStatus.ready));

  void _save() {
    final ready = _queue.where((f) => f.status == _FileStatus.ready).toList();
    if (ready.isEmpty) return;
    final results = ready.map((f) {
      final dot = f.name.lastIndexOf('.');
      return UploadSheetResult(
        bytes: f.bytes,
        filename: f.name,
        contentType: _contentTypeForUpload(f.name),
        title: dot > 0 ? f.name.substring(0, dot) : f.name,
      );
    }).toList();
    Navigator.of(context).pop(results);
  }

  @override
  Widget build(BuildContext context) {
    final readyCount = _queue.where((f) => f.status == _FileStatus.ready).length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 120, vertical: 60),
      child: LayoutBuilder(builder: (ctx, constraints) {
        return Container(
          width: constraints.maxWidth.clamp(0.0, 900.0),
          height: constraints.maxHeight.clamp(0.0, 580.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF137FEC).withOpacity(0.12),
                blurRadius: 80,
                offset: const Offset(0, 24),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 40,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Row(children: [
              // ══ LEFT — dark hero panel ══════════════════════════════
              Expanded(
                flex: 56,
                child: _LeftPanel(
                  moduleTitle: widget.moduleTitle,
                  hovering: _hovering,
                  pulse: _pulse,
                  queueCount: _queue.length,
                  onBrowse: _browse,
                  onEnter: () => setState(() => _hovering = true),
                  onExit: () => setState(() => _hovering = false),
                ),
              ),

              // ══ RIGHT — white queue panel ═══════════════════════════
              Expanded(
                flex: 44,
                child: _RightPanel(
                  queue: _queue,
                  readyCount: readyCount,
                  onRemove: _remove,
                  onClear: _clearDone,
                  onCancel: () => Navigator.of(context).pop(),
                  onSave: readyCount > 0 ? _save : null,
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LEFT dark panel
// ─────────────────────────────────────────────────────────────────────────────
class _LeftPanel extends StatelessWidget {
  final String moduleTitle;
  final bool hovering;
  final Animation<double> pulse;
  final int queueCount;
  final VoidCallback onBrowse;
  final VoidCallback onEnter;
  final VoidCallback onExit;

  const _LeftPanel({
    required this.moduleTitle,
    required this.hovering,
    required this.pulse,
    required this.queueCount,
    required this.onBrowse,
    required this.onEnter,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B2E), Color(0xFF0F2540), Color(0xFF0A1929)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(children: [
        // Decorative grid lines (subtle)
        Positioned.fill(child: CustomPaint(painter: _GridPainter())),

        // Glowing orb behind drop zone
        AnimatedBuilder(
          animation: pulse,
          builder: (_, __) => Positioned(
            left: -60,
            top: -60 + pulse.value * 20,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF137FEC).withOpacity(0.18 + pulse.value * 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Content
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 40, 40, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF137FEC).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF137FEC).withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.upload_file_rounded,
                      size: 20, color: Color(0xFF60AFFE)),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Upload Materials',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF60AFFE),
                          letterSpacing: 0.5)),
                  Text('→ $moduleTitle',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.4))),
                ]),
              ]),

              const SizedBox(height: 36),

              // Big headline
              const Text(
                'Drop your\nPDFs here.',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'PDF only  ·  Max 50 MB',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.45)),
              ),

              const SizedBox(height: 40),

              // Drop zone box
              Expanded(
                child: MouseRegion(
                  onEnter: (_) => onEnter(),
                  onExit: (_) => onExit(),
                  child: GestureDetector(
                    onTap: onBrowse,
                    child: AnimatedBuilder(
                      animation: pulse,
                      builder: (_, __) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: hovering
                              ? const Color(0xFF137FEC).withOpacity(0.12)
                              : Colors.white.withOpacity(0.04 + pulse.value * 0.02),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: hovering
                                ? const Color(0xFF137FEC)
                                : Colors.white.withOpacity(0.12 + pulse.value * 0.06),
                            width: hovering ? 2.0 : 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Animated icon
                            AnimatedBuilder(
                              animation: pulse,
                              builder: (_, __) => Transform.translate(
                                offset: Offset(0, -4 + pulse.value * 8),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: hovering
                                        ? const Color(0xFF137FEC).withOpacity(0.25)
                                        : Colors.white.withOpacity(0.07),
                                    border: Border.all(
                                      color: hovering
                                          ? const Color(0xFF60AFFE).withOpacity(0.6)
                                          : Colors.white.withOpacity(0.15),
                                    ),
                                  ),
                                  child: Icon(
                                    hovering
                                        ? Icons.cloud_done_outlined
                                        : Icons.cloud_upload_outlined,
                                    size: 36,
                                    color: hovering
                                        ? const Color(0xFF60AFFE)
                                        : Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              hovering
                                  ? 'Release to add PDFs'
                                  : 'Drag & drop PDFs',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: hovering
                                    ? const Color(0xFF60AFFE)
                                    : Colors.white.withOpacity(0.85),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'or click anywhere here to browse',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                            const SizedBox(height: 28),
                            // Browse button
                            GestureDetector(
                              onTap: onBrowse,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 13),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF137FEC),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF137FEC)
                                          .withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'Browse Files',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Tips — compact inline
              Row(children: [
                const Icon(Icons.auto_awesome_rounded, size: 13, color: Color(0xFF60AFFE)),
                const SizedBox(width: 6),
                Text('AI auto-analysis', style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.45))),
                const SizedBox(width: 16),
                const Icon(Icons.layers_outlined, size: 13, color: Color(0xFF60AFFE)),
                const SizedBox(width: 6),
                Text('Multi-PDF upload', style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.45))),
                const SizedBox(width: 16),
                const Icon(Icons.text_snippet_outlined, size: 13, color: Color(0xFF60AFFE)),
                const SizedBox(width: 6),
                Text('OCR supported', style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.45))),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Subtle grid painter
// ─────────────────────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 1;
    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  RIGHT panel
// ─────────────────────────────────────────────────────────────────────────────
class _RightPanel extends StatelessWidget {
  final List<_QueuedFile> queue;
  final int readyCount;
  final ValueChanged<int> onRemove;
  final VoidCallback onClear;
  final VoidCallback onCancel;
  final VoidCallback? onSave;

  const _RightPanel({
    required this.queue,
    required this.readyCount,
    required this.onRemove,
    required this.onClear,
    required this.onCancel,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Queue header
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
          child: Row(children: [
            const Text('Upload Queue',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4)),
            const Spacer(),
            if (queue.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${queue.length} Files',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
          ]),
        ),

        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            queue.isEmpty
                ? 'Files you add will appear here'
                : '$readyCount of ${queue.length} ready to save',
            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        ),

        const SizedBox(height: 20),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),

        // File list
        Expanded(
          child: queue.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.inbox_outlined,
                          size: 32, color: Color(0xFFCBD5E1)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Nothing here yet',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8))),
                    const SizedBox(height: 6),
                    const Text('Drop files on the left\nto add them to the queue',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFFCBD5E1),
                            height: 1.5)),
                  ]),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                  itemCount: queue.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFF8FAFC)),
                  itemBuilder: (_, i) => _QueueTile(
                    file: queue[i],
                    onRemove: () => onRemove(i),
                  ),
                ),
        ),

        // Queue actions
        if (queue.isNotEmpty) ...[
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 8),
            child: SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton(
                onPressed: readyCount > 0 ? onClear : null,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                  foregroundColor: const Color(0xFF64748B),
                ),
                child: const Text('Clear Completed',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],

        // Footer buttons
        Container(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Column(children: [
            // Save
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_alt_rounded, size: 18),
                label: Text(
                  readyCount > 1
                      ? 'Save to Course ($readyCount)'
                      : 'Save to Course',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF137FEC),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  disabledForegroundColor: const Color(0xFF94A3B8),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Cancel
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF94A3B8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Queue tile
// ─────────────────────────────────────────────────────────────────────────────
class _QueueTile extends StatelessWidget {
  final _QueuedFile file;
  final VoidCallback onRemove;
  const _QueueTile({required this.file, required this.onRemove});

  (IconData, Color, Color) get _style {
    switch (file.ext) {
      case 'PDF':
        return (Icons.picture_as_pdf_rounded,
            const Color(0xFFFEE2E2), const Color(0xFFEF4444));
      case 'MP4': case 'MOV':
        return (Icons.play_circle_filled_rounded,
            const Color(0xFFDBEAFE), const Color(0xFF3B82F6));
      case 'DOCX': case 'DOC':
        return (Icons.article_rounded,
            const Color(0xFFDCFCE7), const Color(0xFF22C55E));
      case 'PPTX': case 'PPT':
        return (Icons.slideshow_rounded,
            const Color(0xFFFFEDD5), const Color(0xFFF97316));
      default:
        return (Icons.insert_drive_file_rounded,
            const Color(0xFFF3E8FF), const Color(0xFFA855F7));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, iconBg, iconFg) = _style;
    final isReady = file.status == _FileStatus.ready;
    final isError = file.status == _FileStatus.error;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 20, 12),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 22, color: iconFg),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 5),
            if (isReady)
              Row(children: [
                const Icon(Icons.check_circle_rounded,
                    size: 14, color: Color(0xFF22C55E)),
                const SizedBox(width: 5),
                Text(file.displaySize,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF22C55E))),
                const SizedBox(width: 8),
                const Text('Ready for Review',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8))),
              ])
            else if (isError)
              Row(children: [
                const Icon(Icons.error_outline_rounded,
                    size: 14, color: Color(0xFFEF4444)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(file.errorMsg ?? 'Error',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFEF4444))),
                ),
              ]),
          ]),
        ),
        InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
          onTap: onRemove,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.close_rounded,
                size: 14, color: Color(0xFFCBD5E1)),
          ),
        ),
      ]),
    );
  }
}
