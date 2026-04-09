import 'package:flutter/material.dart';

class AppInteractiveRegion extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final bool enabled;

  final Widget Function(
    BuildContext context,
    bool hovered,
    bool focused,
    Widget child,
  )? builder;

  const AppInteractiveRegion({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.enabled = true,
    this.builder,
  });

  @override
  State<AppInteractiveRegion> createState() => _AppInteractiveRegionState();
}

class _AppInteractiveRegionState extends State<AppInteractiveRegion> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bool isActionEnabled = widget.enabled && widget.onTap != null;

    /// 1. بناء المحتوى
    Widget content = widget.builder != null
        ? widget.builder!(context, _hovered, _focused, widget.child)
        : widget.child;

    /// 2. Focus Border
    content = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        border: _focused
            ? Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                width: 2,
              )
            : null,
      ),
      child: content,
    );

    return FocusableActionDetector(
      enabled: isActionEnabled,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      mouseCursor: isActionEnabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: MouseRegion(
        // ✅ FIX 1: مهم جداً
        hitTestBehavior: HitTestBehavior.deferToChild,

        cursor: isActionEnabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,

        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          borderRadius: widget.borderRadius,
          child: InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
            onTap: isActionEnabled ? widget.onTap : null,
            borderRadius: widget.borderRadius,

            // ✅ المصدر الوحيد للـ hover
            onHover: (value) {
              setState(() => _hovered = value);
            },

            splashFactory: NoSplash.splashFactory,

            child: content,
          ),
        ),
      ),
    );
  }
}