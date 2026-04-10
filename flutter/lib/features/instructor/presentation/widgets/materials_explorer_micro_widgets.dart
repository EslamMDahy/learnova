import 'package:flutter/material.dart';
import 'materials_explorer_constants.dart';

// =============================================================================
//  SHARED MICRO-WIDGETS
// =============================================================================

/// Material icon — correct icon + color per type
class _MatIcon extends StatelessWidget {
  final MK? mk;
  final bool isModule;
  final double size;
  const _MatIcon({this.mk, this.isModule = false, required this.size});

  @override
  Widget build(BuildContext context) {
    IconData ic; Color col, bg;
    if (isModule) {
      ic = Icons.folder_rounded; col = K.blue; bg = K.blueSoft;
    } else {
      switch (mk) {
        case MK.video:
          ic = Icons.play_circle_rounded; col = K.blue; bg = K.blueSoft; break;
        case MK.doc:
          ic = Icons.description_rounded;
          col = const Color(0xFF1E40AF); bg = K.badgeDocBg; break;
        case MK.ppt:
          ic = Icons.slideshow_rounded; col = K.orange; bg = K.orangeSoft; break;
        default:
          ic = Icons.picture_as_pdf_rounded; col = K.red; bg = K.redSoft; break;
      }
    }
    final r = size * 0.27;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(r + 2)),
      alignment: Alignment.center,
      child: Icon(ic, size: size * 0.44, color: col),
    );
  }
}

/// Material badge pill
class _MatBadge extends StatelessWidget {
  final MK? mk;
  const _MatBadge(this.mk);

  @override
  Widget build(BuildContext context) {
    String label; Color bg, fg;
    switch (mk) {
      case MK.video:
        label = 'VIDEO'; bg = K.badgeVidBg; fg = K.badgeVidFg; break;
      case MK.doc:
        label = 'DOCUMENT'; bg = K.badgeDocBg; fg = K.badgeDocFg; break;
      case MK.ppt:
        label = 'PRESENTATION'; bg = K.badgePptBg; fg = K.badgePptFg; break;
      default:
        label = 'PDF'; bg = K.badgePdfBg; fg = K.badgePdfFg; break;
    }
    return _Pill(label, bg, fg);
  }
}

class _Pill extends StatelessWidget {
  final String label; final Color bg, fg;
  const _Pill(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(label,
      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800,
        color: fg, letterSpacing: 0.4,),),
  );
}

/// Blue primary button
class _BtnPrimary extends StatefulWidget {
  final String label; final IconData icon; final VoidCallback onTap; final bool full;
  const _BtnPrimary({required this.label, required this.icon,
    required this.onTap, this.full = false,});
  @override State<_BtnPrimary> createState() => _BtnPrimaryState();
}

class _BtnPrimaryState extends State<_BtnPrimary> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit:  (_) => setState(() => _h = false),
    child: GestureDetector(onTap: widget.onTap, child: AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      width: widget.full ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _h ? K.blueHov : K.blue,
        borderRadius: BorderRadius.circular(8),),
      child: Row(
        mainAxisSize: widget.full ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: widget.full ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(widget.icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(widget.label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
              color: Colors.white,),),
        ],),
    ),),
  );
}

/// Outline button
class _BtnOutline extends StatefulWidget {
  final String label; final IconData icon; final VoidCallback onTap; final bool small;
  const _BtnOutline({required this.label, required this.icon,
    required this.onTap, this.small = false,});
  @override State<_BtnOutline> createState() => _BtnOutlineState();
}

class _BtnOutlineState extends State<_BtnOutline> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit:  (_) => setState(() => _h = false),
    child: GestureDetector(onTap: widget.onTap, child: AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      padding: EdgeInsets.symmetric(
        horizontal: widget.small ? 10 : 14,
        vertical:   widget.small ? 6  : 9,),
      decoration: BoxDecoration(
        color: _h ? const Color(0xFFF1F5F9) : K.white,
        border: Border.all(color: K.border),
        borderRadius: BorderRadius.circular(8),),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(widget.icon, size: 13, color: K.text),
        const SizedBox(width: 5),
        Text(widget.label,
          style: TextStyle(fontSize: widget.small ? 12 : 12.5,
            fontWeight: FontWeight.w600, color: K.text,),),
      ],),
    ),),
  );
}

/// Danger outline button
class _BtnDanger extends StatefulWidget {
  final String label; final IconData icon; final VoidCallback onTap;
  const _BtnDanger({required this.label, required this.icon, required this.onTap});
  @override State<_BtnDanger> createState() => _BtnDangerState();
}

class _BtnDangerState extends State<_BtnDanger> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit:  (_) => setState(() => _h = false),
    child: GestureDetector(onTap: widget.onTap, child: AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _h ? K.redSoft : K.white,
        border: Border.all(color: _h ? K.red : K.border),
        borderRadius: BorderRadius.circular(8),),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(widget.icon, size: 13, color: K.red),
        const SizedBox(width: 5),
        Text(widget.label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: K.red),),
      ],),
    ),),
  );
}

/// Generate Question button
class _BtnGenerate extends StatefulWidget {
  final String label; final IconData icon; final VoidCallback? onTap;
  const _BtnGenerate({required this.label, required this.icon, this.onTap});
  @override State<_BtnGenerate> createState() => _BtnGenerateState();
}

class _BtnGenerateState extends State<_BtnGenerate> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit:  (_) => setState(() => _h = false),
    child: GestureDetector(onTap: widget.onTap, child: AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: _h ? K.blueHov : K.blue,
        borderRadius: BorderRadius.circular(8),),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(widget.icon, size: 14, color: Colors.white),
        const SizedBox(width: 7),
        Text(widget.label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),),
      ],),
    ),),
  );
}

/// AI generate button
class _BtnAI extends StatefulWidget {
  final bool generating;
  final VoidCallback onTap;
  final bool labeled;
  const _BtnAI({required this.generating, required this.onTap, this.labeled = false});
  @override State<_BtnAI> createState() => _BtnAIState();
}

class _BtnAIState extends State<_BtnAI> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit:  (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.generating ? null : widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        padding: EdgeInsets.symmetric(
          horizontal: widget.labeled ? 12 : 8,
          vertical:   widget.labeled ? 7  : 5,),
        decoration: BoxDecoration(
          color: _h && !widget.generating
            ? const Color(0xFFD2E9FD)
            : K.blueSoft,
          border: Border.all(
            color: _h && !widget.generating ? K.blue : K.blueBorder,),
          borderRadius: BorderRadius.circular(8),),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          widget.generating
            ? const SizedBox(width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: K.blue),)
            : const Icon(Icons.auto_awesome_rounded, size: 13, color: K.blue),
          if (widget.labeled) ...[
            const SizedBox(width: 6),
            const Text('Generate with AI',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: K.blue),),
          ],
        ],),
      ),
    ),
  );
}

/// Icon button (edit / delete / etc)
class _IcBtn extends StatelessWidget {
  final IconData icon; final String tip; final VoidCallback onTap; final Color col;
  const _IcBtn({required this.icon, required this.tip, required this.onTap,
    this.col = K.muted,});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tip,
    child: InkWell(
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 17, color: col),),
    ),
  );
}

/// Toolbar icon button
class _TbBtn extends StatefulWidget {
  final IconData icon; final String tip; final VoidCallback onTap;
  const _TbBtn({required this.icon, required this.tip, required this.onTap});
  @override State<_TbBtn> createState() => _TbBtnState();
}

class _TbBtnState extends State<_TbBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.tip,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(onTap: widget.onTap, child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: _h ? K.bg : Colors.transparent,
          borderRadius: BorderRadius.circular(6),),
        child: Icon(widget.icon, size: 14, color: K.hint),
      ),),
    ),
  );
}

/// Transcript toolbar button
class _TxBtn extends StatefulWidget {
  final String label; final bool bold; final bool italic;
  const _TxBtn({required this.label, this.bold = false, this.italic = false});
  @override State<_TxBtn> createState() => _TxBtnState();
}

class _TxBtnState extends State<_TxBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _h = true),
    onExit:  (_) => setState(() => _h = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      width: 26, height: 26,
      decoration: BoxDecoration(
        color: _h ? K.bg : Colors.transparent,
        borderRadius: BorderRadius.circular(5),),
      child: Center(child: Text(widget.label, style: TextStyle(
        fontSize: 12,
        fontWeight: widget.bold ? FontWeight.w900 : FontWeight.w500,
        fontStyle: widget.italic ? FontStyle.italic : FontStyle.normal,
        color: K.muted,),),),
    ),
  );
}

/// Count badge
class _CountBadge extends StatelessWidget {
  final String label;
  const _CountBadge(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: K.blueSoft, borderRadius: BorderRadius.circular(999)),
    child: Text(label, style: const TextStyle(fontSize: 11,
      fontWeight: FontWeight.w700, color: K.blue,),),
  );
}

/// Tag chip
class _Tag extends StatelessWidget {
  final String label; final bool dashed;
  const _Tag(this.label, {this.dashed = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: dashed ? Colors.transparent : const Color(0xFFF1F5F9),
      border: Border.all(color: K.border),
      borderRadius: BorderRadius.circular(999),),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
      color: dashed ? K.hint : K.sub,),),
  );
}

// ── Context menu ──────────────────────────────────────────────────────────────
class _MItem {
  final IconData icon; final String label; final Color? color; final VoidCallback onTap;
  const _MItem({required this.icon, required this.label, this.color, required this.onTap});
}

class _MDivider { const _MDivider(); }

class _CtxMenu extends StatelessWidget {
  final List<dynamic> items;
  const _CtxMenu({required this.items});

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
    tooltip: '',
    icon: const Icon(Icons.more_horiz_rounded, size: 14, color: K.hint),
    padding: EdgeInsets.zero, iconSize: 14,
    onSelected: (i) => (items[i] as _MItem).onTap(),
    itemBuilder: (_) {
      final out = <PopupMenuEntry<int>>[];
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        if (item is _MDivider) {
          out.add(const PopupMenuDivider());
        } else if (item is _MItem) {
          out.add(PopupMenuItem<int>(value: i, child: Row(children: [
            Icon(item.icon, size: 14, color: item.color ?? K.text),
            const SizedBox(width: 9),
            Text(item.label,
              style: TextStyle(fontSize: 13, color: item.color ?? K.text),),
          ],),),);
        }
      }
      return out;
    },
  );
}
