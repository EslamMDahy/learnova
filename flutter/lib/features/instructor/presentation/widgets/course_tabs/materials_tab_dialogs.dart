part of 'materials_tab.dart';

class _ModuleDialogWidget extends StatelessWidget {
  final TextEditingController titleCtrl, descCtrl;
  const _ModuleDialogWidget({required this.titleCtrl, required this.descCtrl});
  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: const Row(children: [Icon(Icons.add_box_outlined, size: 18, color: AppColors.primary),
        SizedBox(width: 8), Text('New Module', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),]),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: titleCtrl, autofocus: true, decoration: InputDecoration(
          hintText: 'e.g. Lecture 1: Introduction', labelText: 'Title *',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
      SizedBox(height: 12),
      TextField(controller: descCtrl, maxLines: 2, decoration: InputDecoration(
          hintText: 'Optional description', labelText: 'Description',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
      ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
          onPressed: () { if (titleCtrl.text.trim().isEmpty) return; Navigator.pop(context, true); },
          child: Text('Create')),
    ]);
}

class _AddTopicDialogWidget extends StatefulWidget {
  final String moduleTitle;
  final TextEditingController titleCtrl, descCtrl;
  final ValueChanged<TopicDifficulty> onDifficultyChanged;
  const _AddTopicDialogWidget({required this.moduleTitle, required this.titleCtrl,
      required this.descCtrl, required this.onDifficultyChanged});
  @override
  State<_AddTopicDialogWidget> createState() => _AddTopicDialogWidgetState();
}

class _AddTopicDialogWidgetState extends State<_AddTopicDialogWidget> {
  TopicDifficulty _diff = TopicDifficulty.beginner;

  static Map<TopicDifficulty, (Color, Color)> get _diffColors => {
    TopicDifficulty.beginner:     (AppColors.successText, AppColors.successBg),
    TopicDifficulty.intermediate: (AppColors.warningText, AppColors.warningSoftBg),
    TopicDifficulty.advanced:     (AppColors.dangerText, AppColors.dangerBorder),
  };

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.tag_rounded, size: 17, color: AppColors.primary), SizedBox(width: 8),
          Text('Add Topic', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))]),
      SizedBox(height: 4),
      Text('in "${widget.moduleTitle}"', style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w400)),
    ]),
    content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: widget.titleCtrl, autofocus: true, decoration: InputDecoration(
          hintText: 'e.g. Introduction to Cryptography', labelText: 'Topic Title *',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
      SizedBox(height: 12),
      TextField(controller: widget.descCtrl, maxLines: 2, decoration: InputDecoration(
          hintText: 'Optional description…', labelText: 'Description',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
      SizedBox(height: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Difficulty', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
        SizedBox(height: 8),
        Row(children: TopicDifficulty.values.map((d) {
          final (fg, bg) = _diffColors[d]!;
          final sel = _diff == d;
          final isLast = d == TopicDifficulty.advanced;
          return Expanded(child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 8),
            child: GestureDetector(
              onTap: () { setState(() => _diff = d); widget.onDifficultyChanged(d); },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? bg : AppColors.surfaceBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? fg : AppColors.border, width: sel ? 1.5 : 1),
                ),
                child: Center(child: Text(d.label,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: sel ? fg : AppColors.textMuted))),
              ),
            ),
          ));
        }).toList()),
      ]),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
      ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
          onPressed: () {
            if (widget.titleCtrl.text.trim().isEmpty) return;
            Navigator.pop(context, {'difficulty': _diff});
          },
          child: Text('Add Topic')),
    ]);
}

class _SimpleDialog extends StatelessWidget {
  final String title, confirm; final TextEditingController ctrl; final Color confirmColor;
  const _SimpleDialog({required this.title, required this.ctrl, required this.confirm, required this.confirmColor});
  @override
  Widget build(BuildContext context) => _PreferencesDialogShell(
    title: title,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DialogTextField(
          controller: ctrl,
          hintText: 'Enter value',
          autofocus: true,
        ),
        SizedBox(height: 16),
        _DialogActions(
          onCancel: () => Navigator.pop(context, false),
          onConfirm: () => Navigator.pop(context, true),
          confirmLabel: confirm,
          confirmVariant: _isDangerActionColor(confirmColor) ? AppButtonVariant.danger : AppButtonVariant.primary,
        ),
      ],
    ),
  );
}

class _ConfirmDialogWidget extends StatelessWidget {
  final String title, body, confirm; final Color confirmColor;
  const _ConfirmDialogWidget({required this.title, required this.body, required this.confirm, required this.confirmColor});
  @override
  Widget build(BuildContext context) => _PreferencesDialogShell(
    title: title,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(body, style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textMuted)),
        SizedBox(height: 16),
        _DialogActions(
          onCancel: () => Navigator.pop(context, false),
          onConfirm: () => Navigator.pop(context, true),
          confirmLabel: confirm,
          confirmVariant: _isDangerActionColor(confirmColor) ? AppButtonVariant.danger : AppButtonVariant.primary,
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED MICRO WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
//  Module Actions Grid — replaces the vertical list with a 2-col card grid
// ─────────────────────────────────────────────────────────────────────────────
class _ModuleActionsGrid extends StatelessWidget {
  final ModuleItem module;
  final bool uploading;
  final VoidCallback? onRename, onTogglePublish, onUpload, onShare, onDelete;

  const _ModuleActionsGrid({
    required this.module,
    required this.uploading,
    this.onRename,
    this.onTogglePublish,
    this.onUpload,
    this.onShare,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final isPublished = module.isPublished;

    final actions = [
      _ActionCardData(
        icon: Icons.drive_file_rename_outline_rounded,
        iconColor: AppColors.primary,
        iconBg: _K.blueSoft,
        label: 'Rename',
        onTap: onRename,
      ),
      _ActionCardData(
        icon: isPublished ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        iconColor: isPublished ? _K.amber : _K.green,
        iconBg: isPublished ? _K.amberSoft : _K.greenSoft,
        label: isPublished ? 'Unpublish' : 'Publish',
        onTap: onTogglePublish,
      ),
      _ActionCardData(
        icon: Icons.upload_file_rounded,
        iconColor: AppColors.primary,
        iconBg: AppColors.primarySoft,
        label: 'Upload',
        onTap: uploading ? null : onUpload,
      ),
      _ActionCardData(
        icon: Icons.swap_vert_rounded,
        iconColor: _K.green,
        iconBg: _K.greenSoft,
        label: 'Reorder',
      ),
      _ActionCardData(
        icon: Icons.share_rounded,
        iconColor: AppColors.primary,
        iconBg: AppColors.infoBg,
        label: 'Share',
        onTap: onShare,
      ),
      _ActionCardData(
        icon: Icons.delete_outline_rounded,
        iconColor: AppColors.errorDot,
        iconBg: AppColors.dangerBorder,
        label: 'Delete',
        onTap: onDelete,
        danger: true,
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      // 3 columns on wide, 2 on narrow
      final cols = c.maxWidth > 600 ? 3 : 2;
      const gap = 10.0;
      final cardW = (c.maxWidth - gap * (cols - 1)) / cols;

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: actions
            .map((a) => SizedBox(width: cardW, child: _ActionCard(data: a)))
            .toList(),
      );
    });
  }
}

class _ActionCardData {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  const _ActionCardData({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    this.onTap,
    this.danger = false,
  });
}

class _ActionCard extends StatefulWidget {
  final _ActionCardData data;
  const _ActionCard({required this.data});

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final d = widget.data;
    final disabled = d.onTap == null;
    final hoverBorderColor = d.danger
        ? Color(0xFFFCA5A5)
        : d.iconColor.withOpacity(0.3);
    final hoverBg = d.danger
        ? AppColors.dangerBg
        : d.iconColor.withOpacity(0.04);

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) { if (!disabled) setState(() => _hovered = true); },
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: d.onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            color: _hovered ? hoverBg : AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? hoverBorderColor : _K.div,
              width: _hovered ? 1.5 : 1.0,
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: d.iconColor.withOpacity(0.08), blurRadius: 12, offset: Offset(0, 3))]
                : [BoxShadow(color: Color(0x07000000), blurRadius: 4, offset: Offset(0, 1))],
          ),
          child: Opacity(
            opacity: disabled ? 0.4 : 1.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 140),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _hovered
                        ? d.iconColor.withOpacity(0.15)
                        : d.iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(d.icon, size: 17, color: d.iconColor),
                ),
                SizedBox(height: 10),
                Text(
                  d.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: d.danger
                        ? AppColors.dangerText
                        : (_hovered ? d.iconColor : AppColors.textTitle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardWidget extends StatelessWidget {
  final Widget child; final _HdrWidget? header; final bool noPadding;
  const _CardWidget({required this.child, this.header, this.noPadding = false});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _K.div), boxShadow: [BoxShadow(color: Color(0x07000000), blurRadius: 12, offset: Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (header != null) ...[header!, Divider(height: 1, color: _K.div)],
      child,
    ]));
}

class _HdrWidget extends StatelessWidget {
  final IconData icon; final Color iconColor; final String title;
  final String? badge; final Widget? trailing;
  const _HdrWidget({required this.icon, required this.iconColor, required this.title,
      this.badge, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
    child: Row(children: [
      Icon(icon, size: 15, color: iconColor), SizedBox(width: 10),
      Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textTitle)),
      if (badge != null) ...[SizedBox(width: 7),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _K.blueSoft, borderRadius: BorderRadius.circular(10)),
            child: Text(badge!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)))],
      Spacer(), if (trailing != null) trailing!,
    ]));
}

class _SmBtn extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final bool disabled;
  const _SmBtn({required this.icon, required this.label, required this.onTap, this.disabled = false});
  @override
  Widget build(BuildContext context) => InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: WidgetStatePropertyAll(Colors.transparent), onTap: disabled ? null : onTap,
    borderRadius: BorderRadius.circular(10), child: Opacity(opacity: disabled ? 0.4 : 1.0,
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(color: _K.blueSoft, borderRadius: BorderRadius.circular(7)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: AppColors.primary), SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ]))));
}

class _Pill extends StatelessWidget {
  final String l; final Color fg, bg; _Pill({required this.l, required this.fg, required this.bg});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(l, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg, letterSpacing: 0.1)));
}

class _PRow extends StatefulWidget {
  final IconData icon; final Color iconBg, iconFg;
  final String label, sub; final VoidCallback? onTap; final bool danger;
  const _PRow({required this.icon, required this.iconBg, required this.iconFg,
      required this.label, required this.sub, this.onTap, this.danger = false});
  @override
  State<_PRow> createState() => _PRowState();
}

class _PRowState extends State<_PRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final disabled = widget.onTap == null;
    final textColor = widget.danger ? AppColors.dangerText : AppColors.textTitle;
    final iconColor = disabled ? AppColors.textHint : widget.iconFg;

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) { if (!disabled) setState(() => _hovered = true); },
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 120),
          color: Colors.transparent,
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
          child: Opacity(
            opacity: disabled ? 0.4 : 1.0,
            child: Row(children: [
              // Small icon — not a big chunky box
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _hovered && !disabled
                      ? widget.iconFg.withOpacity(0.12)
                      : widget.iconBg.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(widget.icon, size: 16, color: iconColor),
              ),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.label, style: TextStyle(
                  fontSize: 13.8,
                  fontWeight: FontWeight.w700,
                  color: _hovered && !disabled && !widget.danger
                      ? AppColors.primary
                      : textColor,
                )),
                SizedBox(height: 4),
                Text(widget.sub, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.8, color: AppColors.textMuted, height: 1.45)),
              ])),
              // Arrow only visible on hover
              AnimatedOpacity(
                duration: Duration(milliseconds: 120),
                opacity: disabled ? 0.0 : (_hovered ? 1.0 : 0.18),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: widget.danger
                      ? AppColors.dangerText
                      : AppColors.primary,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DivW extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: _K.div, indent: 16, endIndent: 16);
}

class _MRowW extends StatelessWidget {
  final IconData icon; final String label, value; final bool isLast;
  const _MRowW({required this.icon, required this.label, required this.value, this.isLast = false});
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: Row(children: [
      Icon(icon, size: 14, color: AppColors.textHint), SizedBox(width: 8),
      SizedBox(width: 110, child: Text(label, style: TextStyle(
          fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500))),
      Expanded(child: Text(value, style: TextStyle(
          fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textTitle))),
    ])),
    if (!isLast) Divider(height: 1, color: _K.div, indent: 16, endIndent: 16),
  ]);
}

class _TIcon extends StatelessWidget {
  final String type; final double size; _TIcon({required this.type, this.size = 40});
  static Map<String, (IconData, Color, Color)> get _m => {
    'video': (Icons.play_circle_filled_rounded, AppColors.badgeBlueBg, AppColors.primary),
    'pdf'  : (Icons.picture_as_pdf_rounded,     AppColors.dangerBorder, AppColors.dangerText),
    'quiz' : (Icons.quiz_rounded,                AppColors.purpleBg, AppColors.purpleText),
  };
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final (ico, bg, fg) = _m[type] ??
        (Icons.insert_drive_file_rounded, AppColors.headerBg, AppColors.textMuted);
    return Container(width: size, height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
        child: Icon(ico, size: size * 0.48, color: fg));
  }
}

class _Dot extends StatelessWidget {
  final String status; _Dot({required this.status});
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final c = switch (status) {
      'ready'       => _K.green,
      'processing'  => _K.amber,
      'uploaded'    => _K.amber,
      'draft_upload'=> AppColors.infoText,
      'error'       => AppColors.dangerText,
      _             => AppColors.textHint,
    };
    return Container(width: 6, height: 6, margin: const EdgeInsets.only(left: 5),
        decoration: BoxDecoration(color: c, shape: BoxShape.circle));
  }
}

class _IBtn extends StatelessWidget {
  final IconData icon; final String tooltip; final VoidCallback onTap;
  const _IBtn({required this.icon, required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(message: tooltip, child: InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: WidgetStatePropertyAll(Colors.transparent), onTap: onTap,
      borderRadius: BorderRadius.circular(6), child: Padding(padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 14, color: AppColors.textHint))));
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final bool disabled;
  final VoidCallback? onTap;

  const _Btn({
    required this.icon,
    required this.label,
    this.primary = false,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final fg = disabled
        ? AppColors.textHint
        : (primary ? Colors.white : AppColors.textTitle);
    final bg = disabled
        ? AppColors.borderGray
        : (primary ? AppColors.primary : Colors.transparent);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: WidgetStatePropertyAll(Colors.transparent), 
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: primary || disabled
              ? null
              : BoxDecoration(
                  border: Border.all(color: _K.div),
                  borderRadius: BorderRadius.circular(8),
                ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
