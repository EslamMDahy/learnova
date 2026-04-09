import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../design_tokens.dart';

/// Dropdowns / selects (canonical + legacy wrappers + profile menu).

class AppDropdown extends StatelessWidget {
  final double? width;
  final double height;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const AppDropdown({
    super.key,
    this.width,
    this.height = 40,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: enabled ? AppColors.cSurface : AppColors.headerBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.cBorder),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: height >= 48 ? 12 : 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 22, color: AppColors.cGray500),
              onChanged: enabled ? (v) => onChanged(v!) : null,
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
            ),
          ),
        ),
      ),
    );

    return child;
  }
}

class AppDropdown48 extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const AppDropdown48({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppDropdown(
      height: 48,
      value: value,
      items: items,
      onChanged: onChanged,
      enabled: enabled,
    );
  }
}

class AppDropdown56 extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const AppDropdown56({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppDropdown(
      height: 56,
      value: value,
      items: items,
      onChanged: onChanged,
      enabled: enabled,
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                               Legacy wrappers                              */
/* -------------------------------------------------------------------------- */

class AppDropdownSmall extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const AppDropdownSmall({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppDropdown(
      value: value,
      items: items,
      onChanged: onChanged,
      enabled: enabled,
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                           Profile menu (example)                            */
/* -------------------------------------------------------------------------- */

class AppProfileMenu extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onLogout;

  const AppProfileMenu({
    super.key,
    required this.name,
    required this.email,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      elevation: 12,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onSelected: (v) {
        if (v == 'logout') onLogout();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text(email,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: Color(0xFF6B7280))),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: Text('Logout'),
        ),
      ],
      child: Row(
        children: [
          const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
          const SizedBox(width: 8),
          Text(name,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more_rounded, size: 18),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                         Figma UM dropdown (40px)                            */
/* -------------------------------------------------------------------------- */

class FigmaUmDropdown40 extends StatefulWidget {
  final double width;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const FigmaUmDropdown40({
    super.key,
    required this.width,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  State<FigmaUmDropdown40> createState() => _FigmaUmDropdown40State();
}

class _FigmaUmDropdown40State extends State<FigmaUmDropdown40> {
  bool _hover = false;
  OverlayEntry? _overlay;
  final _key = GlobalKey();

  static const _text = Color(0xFF374151);
  static const _muted = Color(0xFF6B7280);
  static const _border = Color(0xFFE2E8F0);
  static const _bgIdle = Color(0xFFF9FAFB);
  static const _bgHover = Color(0xFFEFF6FF);
  static const _bgOpen = Color(0xFFEFF6FF);
  static const _blue = Color(0xFF137FEC);

  bool get _isOpen => _overlay != null;

  void _open() {
    if (_isOpen) return;

    final box = _key.currentContext!.findRenderObject() as RenderBox;

    // ✅ FIX: anchor relative to the overlay, not global screen.
    // This prevents wrong position when inside dialogs / nested overlays.
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero, ancestor: overlayBox);

    final size = box.size;

    _overlay = OverlayEntry(
      builder: (_) => _FigmaDropdownMenu(
        anchorOffset: offset,
        anchorSize: size,
        value: widget.value,
        items: widget.items,
        onSelect: (v) {
          _close();
          widget.onChanged(v);
        },
        onDismiss: _close,
      ),
    );

    Overlay.of(context).insert(_overlay!);
    setState(() {});
  }

  void _close() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _overlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = _isOpen ? _bgOpen : _hover ? _bgHover : _bgIdle;
    final borderColor = _isOpen ? _blue : _border;
    final borderWidth = _isOpen ? 1.5 : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _isOpen ? _close : _open,
        child: AnimatedContainer(
          key: _key,
          duration: kIsWeb ? Duration.zero : const Duration(milliseconds: 120),
          width: widget.width,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _text,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: _isOpen ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: _isOpen ? _blue : _muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Overlay menu that appears below the trigger ----

class _FigmaDropdownMenu extends StatefulWidget {
  final Offset anchorOffset;
  final Size anchorSize;
  final String value;
  final List<String> items;
  final ValueChanged<String> onSelect;
  final VoidCallback onDismiss;

  const _FigmaDropdownMenu({
    required this.anchorOffset,
    required this.anchorSize,
    required this.value,
    required this.items,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<_FigmaDropdownMenu> createState() => _FigmaDropdownMenuState();
}

class _FigmaDropdownMenuState extends State<_FigmaDropdownMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160))
      ..forward();
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const itemH = 40.0;
    const vPad = 6.0;
    final menuW = widget.anchorSize.width.clamp(150.0, 280.0);
    final menuH = widget.items.length * itemH + vPad * 2;
    final top = widget.anchorOffset.dy + widget.anchorSize.height + 6;
    final left = widget.anchorOffset.dx;

    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.onDismiss,
        ),
      ),
      Positioned(
        top: top,
        left: left,
        width: menuW,
        height: menuH,
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    const BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: (kIsWeb ? 12 : 18),
                      offset: (kIsWeb ? Offset(0, 4) : Offset(0, 6)),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: vPad),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: widget.items.length,
                    itemBuilder: (_, i) {
                      final item = widget.items[i];
                      final selected = item == widget.value;
                      return _FigmaDropdownItem(
                        text: item,
                        selected: selected,
                        onTap: () => widget.onSelect(item),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _FigmaDropdownItem extends StatefulWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _FigmaDropdownItem({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FigmaDropdownItem> createState() => _FigmaDropdownItemState();
}

class _FigmaDropdownItemState extends State<_FigmaDropdownItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hover
        ? const Color(0xFFEFF6FF)
        : widget.selected
            ? const Color(0xFFF3F4F6)
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w600,
                color: widget.selected
                    ? const Color(0xFF111827)
                    : const Color(0xFF374151),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                           AppProfileDropdown (used)                         */
/* -------------------------------------------------------------------------- */

enum AppProfileMenuAction { profile, settings, logout }

class AppProfileDropdown extends StatelessWidget {
  final String name;
  final String subtitle;

  final VoidCallback? onLogout;
  final VoidCallback? onProfile;
  final VoidCallback? onSettings;

  const AppProfileDropdown({
    super.key,
    required this.name,
    required this.subtitle,
    this.onLogout,
    this.onProfile,
    this.onSettings,
  });

  static const Color _mute = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppProfileMenuAction>(
      tooltip: '',
      elevation: 12,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _border),
      ),
      onSelected: (action) {
        switch (action) {
          case AppProfileMenuAction.profile:
            onProfile?.call();
            break;
          case AppProfileMenuAction.settings:
            onSettings?.call();
            break;
          case AppProfileMenuAction.logout:
            onLogout?.call();
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12, color: _mute)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: AppProfileMenuAction.profile,
          child: Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 18),
              SizedBox(width: 10),
              Text('Profile'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: AppProfileMenuAction.settings,
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 18),
              SizedBox(width: 10),
              Text('Settings'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: AppProfileMenuAction.logout,
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18),
              SizedBox(width: 10),
              Text('Logout'),
            ],
          ),
        ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 14,
              child: Icon(Icons.person, size: 16),
            ),
            const SizedBox(width: 8),
            Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more_rounded, size: 18, color: _mute),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                           AppModernDropdown (used)                          */
/* -------------------------------------------------------------------------- */

class AppModernDropdown<T> extends StatefulWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData icon;

  const AppModernDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon = Icons.language_outlined,
  });

  @override
  State<AppModernDropdown<T>> createState() => _AppModernDropdownState<T>();
}

class _AppModernDropdownState<T> extends State<AppModernDropdown<T>> {
  bool _hover = false;
  OverlayEntry? _overlay;
  final _key = GlobalKey();

  static const _text      = Color(0xFF374151);
  static const _muted     = Color(0xFF6B7280);
  static const _border    = Color(0xFFE2E8F0);
  static const _bgIdle    = Color(0xFFF9FAFB);
  static const _bgHover   = Color(0xFFEFF6FF);
  static const _bgOpen    = Color(0xFFEFF6FF);
  static const _blue      = Color(0xFF137FEC);
  static const _labelColor = Color(0xFF374151);

  bool get _isOpen => _overlay != null;

  String get _displayLabel {
    for (final item in widget.items) {
      if (item.value == widget.value) {
        final child = item.child;
        if (child is Text) return child.data ?? '';
        if (child is DefaultTextStyle) {
          final inner = child.child;
          if (inner is Text) return inner.data ?? '';
        }
      }
    }
    return widget.value.toString();
  }

  void _open() {
    if (_isOpen) return;

    final box = _key.currentContext!.findRenderObject() as RenderBox;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final size = box.size;

    _overlay = OverlayEntry(
      builder: (_) => _ModernDropdownMenu<T>(
        anchorOffset: offset,
        anchorSize: size,
        value: widget.value,
        items: widget.items,
        onSelect: (v) {
          _close();
          widget.onChanged(v);
        },
        onDismiss: _close,
      ),
    );

    Overlay.of(context).insert(_overlay!);
    setState(() {});
  }

  void _close() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _overlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = _isOpen ? _bgOpen : _hover ? _bgHover : _bgIdle;
    final borderColor = _isOpen ? _blue : _border;
    final borderWidth = _isOpen ? 1.5 : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: _labelColor,
          ),
        ),
        const SizedBox(height: 8),
        MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: _isOpen ? _close : _open,
            child: AnimatedContainer(
              key: _key,
              duration: kIsWeb
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: borderWidth),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _displayLabel,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: _text,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: _isOpen ? _blue : _muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Overlay menu for AppModernDropdown ──────────────────────────────────────

class _ModernDropdownMenu<T> extends StatefulWidget {
  final Offset anchorOffset;
  final Size anchorSize;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onSelect;
  final VoidCallback onDismiss;

  const _ModernDropdownMenu({
    required this.anchorOffset,
    required this.anchorSize,
    required this.value,
    required this.items,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<_ModernDropdownMenu<T>> createState() => _ModernDropdownMenuState<T>();
}

class _ModernDropdownMenuState<T> extends State<_ModernDropdownMenu<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160))
      ..forward();
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  String _labelFor(DropdownMenuItem<T> item) {
    final child = item.child;
    if (child is Text) return child.data ?? '';
    return item.value.toString();
  }

  @override
  Widget build(BuildContext context) {
    const itemH = 40.0;
    const vPad = 6.0;
    final menuW =
        widget.anchorSize.width.clamp(160.0, 320.0);
    final menuH = widget.items.length * itemH + vPad * 2;

    final media = MediaQuery.of(context);
    var top = widget.anchorOffset.dy + widget.anchorSize.height + 6;
    var left = widget.anchorOffset.dx;

    if (left + menuW > media.size.width - 8) {
      left = (media.size.width - 8) - menuW;
    }
    if (left < 8) left = 8;
    if (top + menuH > media.size.height - 8) {
      final above = widget.anchorOffset.dy - 6 - menuH;
      if (above >= 8) top = above;
    }

    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.onDismiss,
        ),
      ),
      Positioned(
        top: top,
        left: left,
        width: menuW,
        height: menuH,
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    const BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: kIsWeb ? 12 : 18,
                      offset:
                          kIsWeb ? Offset(0, 4) : Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: vPad),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: widget.items.length,
                    itemBuilder: (_, i) {
                      final item = widget.items[i];
                      final selected = item.value == widget.value;
                      return _ModernDropdownItem(
                        text: _labelFor(item),
                        selected: selected,
                        onTap: () => widget.onSelect(item.value),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _ModernDropdownItem extends StatefulWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _ModernDropdownItem({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ModernDropdownItem> createState() => _ModernDropdownItemState();
}

class _ModernDropdownItemState extends State<_ModernDropdownItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hover
        ? const Color(0xFFEFF6FF)
        : widget.selected
            ? const Color(0xFFF3F4F6)
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: widget.selected
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: widget.selected
                        ? const Color(0xFF111827)
                        : const Color(0xFF374151),
                  ),
                ),
              ),
              if (widget.selected)
                const Icon(Icons.check_rounded,
                    size: 16, color: Color(0xFF137FEC)),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                         Figma UM Action / Popup Menu                        */
/* -------------------------------------------------------------------------- */

class FigmaUmMenuEntry<T> {
  final T? value;
  final String? label;
  final IconData? icon;
  final bool enabled;
  final bool isDivider;

  const FigmaUmMenuEntry._({
    this.value,
    this.label,
    this.icon,
    this.enabled = true,
    this.isDivider = false,
  });

  const FigmaUmMenuEntry.item({
    required T value,
    required String label,
    IconData? icon,
    bool enabled = true,
  }) : this._(value: value, label: label, icon: icon, enabled: enabled);

  const FigmaUmMenuEntry.divider() : this._(isDivider: true);
}

Future<T?> showFigmaUmMenu<T>({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<FigmaUmMenuEntry<T>> entries,
  double yOffset = 6,
  double minWidth = 180,
  double maxWidth = 280,
}) async {
  final overlayState = Overlay.of(context);
  final overlayBox = overlayState.context.findRenderObject() as RenderBox?;
  final anchorBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;

  if (overlayBox == null || anchorBox == null) return null;

  final topLeft = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  final size = anchorBox.size;

  final completer = Completer<T?>();

  late OverlayEntry entry;
  void close([T? value]) {
    if (completer.isCompleted) return;
    completer.complete(value);
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => _FigmaUmActionMenuOverlay<T>(
      anchorOffset: topLeft,
      anchorSize: size,
      entries: entries,
      yOffset: yOffset,
      minWidth: minWidth,
      maxWidth: maxWidth,
      onSelect: (v) => close(v),
      onDismiss: () => close(),
    ),
  );

  overlayState.insert(entry);
  return completer.future;
}

class _FigmaUmActionMenuOverlay<T> extends StatefulWidget {
  final Offset anchorOffset;
  final Size anchorSize;
  final List<FigmaUmMenuEntry<T>> entries;
  final double yOffset;
  final double minWidth;
  final double maxWidth;
  final ValueChanged<T> onSelect;
  final VoidCallback onDismiss;

  const _FigmaUmActionMenuOverlay({
    required this.anchorOffset,
    required this.anchorSize,
    required this.entries,
    required this.yOffset,
    required this.minWidth,
    required this.maxWidth,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<_FigmaUmActionMenuOverlay<T>> createState() =>
      _FigmaUmActionMenuOverlayState<T>();
}

class _FigmaUmActionMenuOverlayState<T>
    extends State<_FigmaUmActionMenuOverlay<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  static const _border = Color(0xFFE2E8F0);
  static const _divider = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    )..forward();
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const itemH = 40.0;
    const vPad = 6.0;

    final width =
        widget.anchorSize.width.clamp(widget.minWidth, widget.maxWidth);

    final itemCount = widget.entries.where((e) => !e.isDivider).length;
    final dividerCount = widget.entries.where((e) => e.isDivider).length;
    final height = itemCount * itemH + dividerCount * 1 + vPad * 2;

    var top = widget.anchorOffset.dy + widget.anchorSize.height + widget.yOffset;
    var left = widget.anchorOffset.dx;

    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final screenH = media.size.height;

    if (left + width > screenW - 8) left = (screenW - 8) - width;
    if (left < 8) left = 8;

    if (top + height > screenH - 8) {
      final aboveTop = widget.anchorOffset.dy - widget.yOffset - height;
      if (aboveTop >= 8) top = aboveTop;
    }

    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.onDismiss,
        ),
      ),
      Positioned(
        top: top,
        left: left,
        width: width.toDouble(),
        height: height.toDouble(),
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                  boxShadow: [
                    const BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: (kIsWeb ? 12 : 18),
                      offset: (kIsWeb ? Offset(0, 4) : Offset(0, 6)),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: vPad),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.entries.map((e) {
                      if (e.isDivider) {
                        return Container(height: 1, color: _divider);
                      }
                      return _FigmaUmActionMenuItem(
                        height: itemH,
                        icon: e.icon,
                        label: e.label ?? '',
                        enabled: e.enabled,
                        onTap: () {
                          if (!e.enabled) return;
                          widget.onSelect(e.value as T);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _FigmaUmActionMenuItem extends StatefulWidget {
  final double height;
  final IconData? icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _FigmaUmActionMenuItem({
    required this.height,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_FigmaUmActionMenuItem> createState() => _FigmaUmActionMenuItemState();
}

class _FigmaUmActionMenuItemState extends State<_FigmaUmActionMenuItem> {
  bool _hover = false;

  static const _text = Color(0xFF374151);
  static const _muted = Color(0xFF9CA3AF);
  static const _hoverBg = Color(0xFFEFF6FF);

  @override
  Widget build(BuildContext context) {
    final fg = widget.enabled ? _text : _muted;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        child: Container(
          height: widget.height,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _hover && widget.enabled ? _hoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: fg),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
