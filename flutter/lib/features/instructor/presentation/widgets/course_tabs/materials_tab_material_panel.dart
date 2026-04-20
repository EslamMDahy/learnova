part of 'materials_tab.dart';

class _MaterialPanelWidget extends StatelessWidget {
  final ModuleItem module; final MaterialItem material;
  final List<TopicItem> topics; final bool topicsLoading;
  final List<LearningOutcome> outcomes;
  final String? downloadUrl; final bool urlLoading;
  final void Function(TopicItem) onTopicTap;
  final VoidCallback onAddTopicManual, onGenerateTopicsAI, onRefreshUrl;
  final bool previewInteractive;
  const _MaterialPanelWidget({required this.module, required this.material,
      required this.topics, required this.topicsLoading, required this.outcomes,
      required this.downloadUrl, required this.urlLoading,
      required this.onTopicTap, required this.onAddTopicManual,
      required this.onGenerateTopicsAI, required this.onRefreshUrl, required this.previewInteractive});

  @override
  Widget build(BuildContext context) {
    final mappedOutcomeIds = <String>{};
    for (final topic in topics) {
      mappedOutcomeIds.addAll(topic.linkedOutcomeIds);
      if (topic.linkedOutcomeId != null) mappedOutcomeIds.add(topic.linkedOutcomeId!);
    }

    final readyTopics = topics.where((t) => t.readiness == TopicReadiness.ready).length;
    final statusLabel = material.isReady || material.status == 'uploaded'
        ? 'Ready'
        : material.isProcessing
            ? 'Processing'
            : 'Draft';

    final previewCard = _CardWidget(
      noPadding: true,
      header: _HdrWidget(
        icon: Icons.preview_rounded,
        iconColor: AppColors.primary,
        title: 'Material preview',
        trailing: downloadUrl != null && downloadUrl!.isNotEmpty
            ? _OBtn(url: downloadUrl!)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Pill(l: material.type.toUpperCase(), fg: AppColors.primary, bg: _K.blueSoft),
                _Pill(
                  l: statusLabel,
                  fg: material.isReady ? _K.green : material.isProcessing ? _K.amber : AppColors.textMuted,
                  bg: material.isReady ? _K.greenSoft : material.isProcessing ? _K.amberSoft : const Color(0xFFF1F5F9),
                ),
                if (material.fileName != null && material.fileName!.trim().isNotEmpty)
                  Text(
                    material.fileName!,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: _K.div),
          SizedBox(
            height: 680,
            child: _FilePreviewWidget(
              material: material,
              downloadUrl: downloadUrl,
              loading: urlLoading,
              onRefresh: onRefreshUrl,
              interactive: previewInteractive,
            ),
          ),
        ],
      ),
    );

    final overviewCard = _CardWidget(
      header: _HdrWidget(
        icon: Icons.dashboard_customize_rounded,
        iconColor: AppColors.primary,
        title: 'Overview',
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: Column(
          children: [
            _MaterialMetaRow(
              icon: Icons.task_alt_rounded,
              iconColor: _K.green,
              iconBg: _K.greenSoft,
              label: 'Status',
              value: statusLabel,
              sub: material.isReady
                  ? 'This file is ready for course workflows.'
                  : material.isProcessing
                      ? 'This file is still being processed.'
                      : 'This file is saved inside the module.',
            ),
            const SizedBox(height: 10),
            _MaterialMetaRow(
              icon: Icons.account_tree_outlined,
              iconColor: AppColors.primary,
              iconBg: _K.blueSoft,
              label: 'Topics',
              value: '${topics.length}',
              sub: '$readyTopics ready topic${readyTopics == 1 ? '' : 's'} in this file.',
            ),
            const SizedBox(height: 10),
            _MaterialMetaRow(
              icon: Icons.flag_outlined,
              iconColor: _K.amber,
              iconBg: _K.amberSoft,
              label: 'Learning outcomes',
              value: totalOutcomeCountLabel(mappedOutcomeIds.length, outcomes.length),
              sub: outcomes.isEmpty
                  ? 'No outcomes are attached to this course yet.'
                  : 'Coverage mapped from topics to course outcomes.',
            ),
          ],
        ),
      ),
    );

    final parentTopics = topics
        .where((t) => t.parentTopicId == null)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final childrenByParent = <int, List<TopicItem>>{};
    for (final topic in topics.where((t) => t.parentTopicId != null)) {
      childrenByParent.putIfAbsent(topic.parentTopicId!, () => <TopicItem>[]).add(topic);
    }
    for (final items in childrenByParent.values) {
      items.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    }

    final topicsCard = _CardWidget(
      noPadding: true,
      header: _HdrWidget(
        icon: Icons.auto_awesome_mosaic_rounded,
        iconColor: AppColors.primary,
        title: 'Topics',
        badge: topics.isNotEmpty ? '${topics.length}' : null,
        trailing: _AddTopicUnifiedBtn(onTap: onAddTopicManual),
      ),
      child: topicsLoading
          ? const SizedBox(
              height: 240,
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          : topics.isEmpty
              ? _TopicsEmptyW(onAddManual: onAddTopicManual)
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 460),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    shrinkWrap: true,
                    children: [
                      for (var index = 0; index < parentTopics.length; index++) ...[
                        _TopicItemW(
                          topic: parentTopics[index],
                          index: index,
                          onTap: () => onTopicTap(parentTopics[index]),
                        ),
                        if ((childrenByParent[parentTopics[index].id] ?? const <TopicItem>[]).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...(childrenByParent[parentTopics[index].id] ?? const <TopicItem>[]).map(
                            (subtopic) => Padding(
                              padding: const EdgeInsets.only(left: 14, bottom: 8),
                              child: _SubtopicItemW(
                                subtopic: subtopic,
                                onTap: () => onTopicTap(subtopic),
                              ),
                            ),
                          ),
                        ],
                        if (index != parentTopics.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
    );

    final detailsCard = _CardWidget(
      header: _HdrWidget(
        icon: Icons.info_outline_rounded,
        iconColor: AppColors.primary,
        title: 'Material details',
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
        child: Column(
          children: [
            _MaterialDetailLine(label: 'Module', value: module.title),
            _MaterialDetailLine(label: 'Type', value: material.type.toUpperCase()),
            if (material.fileName != null && material.fileName!.trim().isNotEmpty)
              _MaterialDetailLine(label: 'File name', value: material.fileName!),
            if (material.fileSize != null)
              _MaterialDetailLine(label: 'Size', value: _MetaStripW._fmt(material.fileSize!)),
            if (material.pageCount != null)
              _MaterialDetailLine(label: 'Pages', value: '${material.pageCount}'),
            _MaterialDetailLine(label: 'Uploaded', value: _relativeDate(material.uploadedAt)),
          ],
        ),
      ),
    );

    return Container(
      color: _K.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MaterialHeroWidget(module: module, material: material),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 1180;
                if (stacked) {
                  return Column(
                    children: [
                      overviewCard,
                      const SizedBox(height: 14),
                      previewCard,
                      const SizedBox(height: 14),
                      topicsCard,
                      const SizedBox(height: 14),
                      detailsCard,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: previewCard),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 360,
                      child: Column(
                        children: [
                          overviewCard,
                          const SizedBox(height: 14),
                          topicsCard,
                          const SizedBox(height: 14),
                          detailsCard,
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String totalOutcomeCountLabel(int mapped, int total) {
    if (total == 0) return 'No outcomes';
    return '$mapped/$total';
  }
}



class _SubtopicItemW extends StatelessWidget {
  final TopicItem subtopic;
  final VoidCallback onTap;

  const _SubtopicItemW({required this.subtopic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtopic.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTitle,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Subtopic • ${subtopic.readiness.label}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _MaterialMetaRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final String sub;
  const _MaterialMetaRow({required this.icon, required this.iconColor, required this.iconBg, required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _K.div),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
                const SizedBox(height: 4),
                Text(sub, style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialDetailLine extends StatelessWidget {
  final String label;
  final String value;
  const _MaterialDetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
          ),
        ],
      ),
    );
  }
}

class _MaterialInsightsStrip extends StatelessWidget {
  final int topicCount;
  final int readyCount;
  final int mappedOutcomeCount;
  final int totalOutcomeCount;

  const _MaterialInsightsStrip({
    required this.topicCount,
    required this.readyCount,
    required this.mappedOutcomeCount,
    required this.totalOutcomeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 10, runSpacing: 10, children: [
      _InsightPill(icon: Icons.tag_rounded, label: '$topicCount topic${topicCount == 1 ? '' : 's'}'),
      _InsightPill(icon: Icons.task_alt_rounded, label: '$readyCount ready'),
      _InsightPill(icon: Icons.flag_outlined, label: totalOutcomeCount == 0 ? 'No outcomes yet' : '$mappedOutcomeCount / $totalOutcomeCount LOs mapped'),
    ]);
  }
}

class _InsightPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InsightPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: _K.div),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: AppColors.primary),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textTitle)),
    ]),
  );
}

class _MatHeaderWidget extends StatelessWidget {
  final ModuleItem module; final MaterialItem material;
  const _MatHeaderWidget({required this.module, required this.material});
  static const _tc = {
    'video': (Color(0xFF2563EB), Color(0xFFDBEAFE)),
    'pdf'  : (Color(0xFFDC2626), Color(0xFFFEE2E2)),
    'image': (Color(0xFF7C3AED), Color(0xFFF3E8FF)),
    'audio': (Color(0xFF16A34A), Color(0xFFDCFCE7)),
    'quiz' : (Color(0xFF9333EA), Color(0xFFF3E8FF)),
  };
  @override
  Widget build(BuildContext context) {
    final (tcol, tbg) = _tc[material.type] ?? (AppColors.textMuted, const Color(0xFFF1F5F9));
    final (scol, sbg) = material.isReady ? (_K.green, _K.greenSoft)
        : material.isProcessing ? (_K.amber, _K.amberSoft)
        : (AppColors.dangerText, const Color(0xFFFFF1F2));
    final sl = material.isReady ? '● Ready' : material.isProcessing ? '● Processing' : '● Error';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 16, 12),
      decoration: const BoxDecoration(color: Colors.white,
          border: Border(bottom: BorderSide(color: _K.div))),
      child: Row(children: [
        _TIcon(type: material.type, size: 36), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _Pill(l: material.type.toUpperCase(), fg: tcol, bg: tbg), const SizedBox(width: 6),
            _Pill(l: sl, fg: scol, bg: sbg),
          ]),
          const SizedBox(height: 4),
          Text(material.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
          Text('In "${module.title}"', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Material Hero — mirrors _ModuleHeroWidget layout
// ─────────────────────────────────────────────────────────────────────────────
class _MaterialHeroWidget extends StatelessWidget {
  final ModuleItem module;
  final MaterialItem material;
  const _MaterialHeroWidget({required this.module, required this.material});

  static const _gradients = {
    'pdf'  : [Color(0xFF1565C0), Color(0xFF137FEC), Color(0xFF60A5FA)],
    'video': [Color(0xFF065F46), Color(0xFF059669), Color(0xFF34D399)],
    'image': [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFFA78BFA)],
    'audio': [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF5EEAD4)],
    'quiz' : [Color(0xFF5B21B6), Color(0xFF7C3AED), Color(0xFFC4B5FD)],
  };

  @override
  Widget build(BuildContext context) {
    final t = material.type.toLowerCase();
    final colors = _gradients[t] ??
        [const Color(0xFF374151), const Color(0xFF4B5563), const Color(0xFF9CA3AF)];

    final statusLabel = material.isReady || material.status == 'uploaded'
        ? '● Ready'
        : material.isProcessing
            ? '● Processing'
            : '● Processing';
    final statusColor = material.isReady || material.status == 'uploaded'
        ? const Color(0xFF4ADE80)
        : const Color(0xFFFBBF24);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Color(colors[1].value).withOpacity(0.22),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, children: [
              _HPill(statusLabel, statusColor),
              _HPill(material.type.toUpperCase(), Colors.white70),
              _HPill('In "${module.title}"', Colors.white60),
            ]),
            const SizedBox(height: 10),
            Text(
              material.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.25,
              ),
            ),
            if (material.fileName != null) ...[
              const SizedBox(height: 5),
              Text(
                material.fileName!,
                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ]),
        ),
        const SizedBox(width: 12),
        // File size / pages info box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(children: [
            Text(
              material.pageCount != null ? 'Pages' : 'Size',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              material.pageCount != null
                  ? '${material.pageCount}'
                  : material.fileSize != null
                      ? '${(material.fileSize! / 1024 / 1024).toStringAsFixed(1)}MB'
                      : '—',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
//  FILE PREVIEW
// ─────────────────────────────────────────────────────────────────────────────
enum _PK { pdf, image, video, audio, link, other }

class _FilePreviewWidget extends StatelessWidget {
  final MaterialItem material; final String? downloadUrl;
  final bool loading; final VoidCallback onRefresh;
  final bool interactive;
  const _FilePreviewWidget({required this.material, required this.downloadUrl,
      required this.loading, required this.onRefresh, required this.interactive});

  _PK get _kind {
    final t = material.type.toLowerCase(); final m = (material.mimeType ?? '').toLowerCase();
    if (t == 'video' || m.startsWith('video/')) return _PK.video;
    if (t == 'pdf'   || m == 'application/pdf') return _PK.pdf;
    if (t == 'image' || m.startsWith('image/')) return _PK.image;
    if (t == 'audio' || m.startsWith('audio/')) return _PK.audio;
    if (t == 'link') return _PK.link;
    return _PK.other;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const _LoaderW(label: 'Loading preview…');
    if (material.isProcessing && material.status != 'uploaded') {
      return const _PlaceholderW(icon: Icons.hourglass_top_rounded,
        iconColor: _K.amber, iconBg: _K.amberSoft, title: 'Processing…',
        sub: 'Your file is being processed. Preview will be available shortly.');
    }
    if (material.isError && material.status != 'uploaded') {
      return _PlaceholderW(icon: Icons.error_outline_rounded,
        iconColor: AppColors.dangerText, iconBg: _K.redSoft, title: 'Processing failed',
        sub: 'Something went wrong processing this file.',
        actionLabel: 'Retry', onAction: onRefresh);
    }
    if (downloadUrl == null || downloadUrl!.isEmpty) {
      return _PlaceholderW(icon: Icons.link_off_rounded, iconColor: AppColors.textMuted,
          iconBg: _K.bg, title: 'Preview unavailable',
          sub: 'Could not load a URL for this file.',
          actionLabel: 'Retry', onAction: onRefresh);
    }

    final url = downloadUrl!;
    return switch (_kind) {
      _PK.pdf   => _PdfPreviewWidget(url: url, material: material, interactive: interactive),
      _PK.image => _ImagePreviewWidget(url: url),
      _PK.video => _VideoPreviewWidget(url: url, material: material),
      _PK.audio => _AudioPreviewWidget(url: url, material: material),
      _PK.link  => _LinkPreviewWidget(url: url),
      _PK.other => _FallbackWidget(url: url, material: material),
    };
  }
}

class _PdfPreviewWidget extends StatefulWidget {
  final String url; final MaterialItem material;
  final bool interactive;
  const _PdfPreviewWidget({required this.url, required this.material, required this.interactive});
  @override
  State<_PdfPreviewWidget> createState() => _PdfPreviewWidgetState();
}

class _PdfPreviewWidgetState extends State<_PdfPreviewWidget> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'pdf-iframe-${widget.material.id}';
    _registerView();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePointerEvents());
  }

  void _updatePointerEvents() {
    updatePdfPreviewInteractivity(viewType: _viewId, interactive: widget.interactive);
  }

  @override
  void didUpdateWidget(covariant _PdfPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interactive != widget.interactive || oldWidget.url != widget.url) {
      _updatePointerEvents();
    }
  }

  void _registerView() {
    registerPdfPreviewView(
      viewType: _viewId,
      url: widget.url,
      interactive: widget.interactive,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.interactive) {
      return _PlaceholderW(
        icon: Icons.picture_as_pdf_rounded,
        iconColor: AppColors.primary,
        iconBg: _K.blueSoft,
        title: 'Preview paused',
        sub: 'The PDF preview is temporarily paused while a dialog is open.',
        actionLabel: 'Open file',
        onAction: () async {
          final uri = Uri.tryParse(widget.url);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.platformDefault);
          }
        },
      );
    }
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
      child: HtmlElementView(viewType: _viewId),
    );
  }
}

class _ImagePreviewWidget extends StatelessWidget {
  final String url; const _ImagePreviewWidget({required this.url});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(20),
    child: Container(decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(14), border: Border.all(color: _K.div)),
      child: ClipRRect(borderRadius: BorderRadius.circular(13), child: Stack(children: [
        Container(color: const Color(0xFFF8F9FB)),
        Center(child: Image.network(url, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _FallbackWidget(url: url, material: null),
            loadingBuilder: (_, child, p) => p == null ? child :
                const Center(child: CircularProgressIndicator(strokeWidth: 2)))),
        Positioned(top: 12, right: 12, child: _OBtn(url: url)),
      ]))));
}

class _VideoPreviewWidget extends StatelessWidget {
  final String url; final MaterialItem material;
  const _VideoPreviewWidget({required this.url, required this.material});
  static String _fmt(int s) {
    final h = s ~/ 3600; final m = (s % 3600) ~/ 60; final sec = s % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m ${sec}s';
  }
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _MetaStripW(material: material), const SizedBox(height: 14),
      Expanded(child: Container(
        decoration: BoxDecoration(color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(14), border: Border.all(color: _K.div)),
        child: ClipRRect(borderRadius: BorderRadius.circular(13),
            child: Stack(alignment: Alignment.center, children: [
          Container(decoration: const BoxDecoration(gradient: RadialGradient(
              colors: [Color(0xFF1A2332), Color(0xFF0D1117)]))),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 80, height: 80,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.2))),
                child: const Icon(Icons.play_arrow_rounded, size: 44, color: Colors.white)),
            const SizedBox(height: 16),
            Text(material.displayTitle, style: const TextStyle(fontSize: 16,
                fontWeight: FontWeight.w700, color: Colors.white)),
            if (material.durationSeconds != null) ...[
              const SizedBox(height: 4),
              Text(_fmt(material.durationSeconds!),
                  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.55))),
            ],
            const SizedBox(height: 22),
            ElevatedButton.icon(onPressed: () {},
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('Open Video'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.15),
                    foregroundColor: Colors.white, elevation: 0,
                    side: BorderSide(color: Colors.white.withOpacity(0.25)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)))),
          ]),
        ])))),
    ]));
}

class _AudioPreviewWidget extends StatelessWidget {
  final String url; final MaterialItem material;
  const _AudioPreviewWidget({required this.url, required this.material});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(20),
    child: Container(padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _K.div)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(
            color: _K.greenSoft, borderRadius: BorderRadius.circular(22)),
            child: const Icon(Icons.headphones_rounded, size: 40, color: _K.green)),
        const SizedBox(height: 18),
        Text(material.displayTitle, textAlign: TextAlign.center, style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
        if (material.durationSeconds != null) ...[
          const SizedBox(height: 6),
          Text('Duration: ${material.durationSeconds! ~/ 60}m ${material.durationSeconds! % 60}s',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
        const SizedBox(height: 24),
        _OBtn(url: url, big: true),
      ])));
}

class _LinkPreviewWidget extends StatelessWidget {
  final String url; const _LinkPreviewWidget({required this.url});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(20),
    child: Container(padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _K.div)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 72, height: 72, decoration: BoxDecoration(
            color: _K.blueSoft, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.link_rounded, size: 34, color: AppColors.primary)),
        const SizedBox(height: 16),
        const Text('External Link', style: TextStyle(fontSize: 17,
            fontWeight: FontWeight.w800, color: AppColors.textTitle)),
        const SizedBox(height: 8),
        Text(url, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 20), _OBtn(url: url, big: true),
      ])));
}

class _FallbackWidget extends StatelessWidget {
  final String url; final MaterialItem? material;
  const _FallbackWidget({required this.url, required this.material});
  @override
  Widget build(BuildContext context) => _PlaceholderW(icon: Icons.insert_drive_file_rounded,
      iconColor: AppColors.textMuted, iconBg: _K.bg, title: 'Preview not available',
      sub: material != null ? 'This file type (${material!.type}) cannot be previewed inline.'
          : 'Preview not available.', actionLabel: 'Open / Download', onAction: () {});
}

class _LoaderW extends StatelessWidget {
  final String label; const _LoaderW({required this.label});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const CircularProgressIndicator(strokeWidth: 2), const SizedBox(height: 12),
    Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted))]));
}

class _PlaceholderW extends StatelessWidget {
  final IconData icon; final Color iconColor, iconBg;
  final String title, sub; final String? actionLabel; final VoidCallback? onAction;
  const _PlaceholderW({required this.icon, required this.iconColor, required this.iconBg,
      required this.title, required this.sub, this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 70, height: 70,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(18)),
          child: Icon(icon, size: 32, color: iconColor)),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
      const SizedBox(height: 6),
      Text(sub, style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
          textAlign: TextAlign.center),
      if (actionLabel != null && onAction != null) ...[
        const SizedBox(height: 20),
        ElevatedButton.icon(onPressed: onAction,
            icon: const Icon(Icons.open_in_new_rounded, size: 14), label: Text(actionLabel!)),
      ],
    ])));
}

class _MetaStripW extends StatelessWidget {
  final MaterialItem material; const _MetaStripW({required this.material});
  static String _fmt(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String)>[];
    if (material.fileSize != null) items.add((Icons.storage_rounded, _fmt(material.fileSize!)));
    if (material.pageCount != null) items.add((Icons.menu_book_rounded, '${material.pageCount} pages'));
    if (material.durationSeconds != null) { final s = material.durationSeconds!;
      items.add((Icons.timer_rounded, '${s ~/ 60}m ${s % 60}s')); }
    final d = material.uploadedAt;
    items.add((Icons.calendar_today_rounded, 'Uploaded ${d.day}/${d.month}/${d.year}'));
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 14, runSpacing: 5, children: items.map((it) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(it.$1, size: 12, color: AppColors.textHint), const SizedBox(width: 4),
          Text(it.$2, style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
        ])).toList());
  }
}

class _OBtn extends StatelessWidget {
  final String url; final bool big; const _OBtn({required this.url, this.big = false});

  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (big) {
      return ElevatedButton.icon(onPressed: _open,
        icon: const Icon(Icons.open_in_new_rounded, size: 14), label: const Text('Open'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
            foregroundColor: Colors.white, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
    }
    return Material(color: AppColors.primary, borderRadius: BorderRadius.circular(7),
        child: InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), onTap: _open, borderRadius: BorderRadius.circular(7),
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.open_in_new_rounded, size: 12, color: Colors.white),
                  SizedBox(width: 5),
                  Text('Open', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ]))));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOPICS SIDEBAR
// ─────────────────────────────────────────────────────────────────────────────
