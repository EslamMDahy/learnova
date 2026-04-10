import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum AppToastType { success, info, warning, error }

@immutable
class AppToast {
  const AppToast._();

  static OverlayEntry? _current;
  static Timer? _autoTimer;

  static void success(BuildContext context, {
    String title = 'Success',
    required String message,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel, VoidCallback? onAction,
  }) => _show(context, type: AppToastType.success, title: title,
        message: message, duration: duration,
        actionLabel: actionLabel, onAction: onAction,);

  static void info(BuildContext context, {
    String title = 'Info',
    required String message,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel, VoidCallback? onAction,
  }) => _show(context, type: AppToastType.info, title: title,
        message: message, duration: duration,
        actionLabel: actionLabel, onAction: onAction,);

  static void warning(BuildContext context, {
    String title = 'Warning',
    required String message,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel, VoidCallback? onAction,
  }) => _show(context, type: AppToastType.warning, title: title,
        message: message, duration: duration,
        actionLabel: actionLabel, onAction: onAction,);

  static void error(BuildContext context, {
    String title = 'Error',
    required String message,
    Duration duration = const Duration(seconds: 5),
    String? actionLabel, VoidCallback? onAction,
  }) => _show(context, type: AppToastType.error, title: title,
        message: message, duration: duration,
        actionLabel: actionLabel, onAction: onAction,);

  static void show(BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel, VoidCallback? onAction,
  }) => _show(context, type: AppToastType.info, title: title,
        message: message, duration: duration,
        actionLabel: actionLabel, onAction: onAction,
        overrideIcon: icon,);

  static void _show(BuildContext context, {
    required AppToastType type,
    required String title,
    required String message,
    required Duration duration,
    String? actionLabel, VoidCallback? onAction, IconData? overrideIcon,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _autoTimer?.cancel();
    _current?.remove();
    _current = null;

    late OverlayEntry entry;

    void dismiss() {
      _autoTimer?.cancel();
      if (entry.mounted) entry.remove();
      if (identical(_current, entry)) _current = null;
    }

    entry = OverlayEntry(builder: (ctx) {
      final mq   = MediaQuery.of(ctx);
      final wide = mq.size.width >= 520;
      final maxW = math.min(420.0, math.max(300.0, mq.size.width - 40.0));

      return SafeArea(
        child: Align(
          alignment: wide ? Alignment.topRight : Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: 20, right: wide ? 24 : 0),
            child: SizedBox(
              width: maxW,
              child: Material(
                color: Colors.transparent,
                child: _ToastRoot(
                  type: type, title: title, message: message,
                  duration: duration, actionLabel: actionLabel,
                  onAction: onAction, overrideIcon: overrideIcon,
                  onDismiss: dismiss,
                ),
              ),
            ),
          ),
        ),
      );
    },);

    _current = entry;
    overlay.insert(entry);
    _autoTimer = Timer(duration + const Duration(milliseconds: 500), dismiss);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Visual tokens per type
// ─────────────────────────────────────────────────────────────────────────────
class _Tokens {
  final Color glow;
  final List<Color> iconGrad;
  final Color bar;
  final Color titleColor;
  final Color messageColor;
  final Color borderColor;
  final IconData icon;

  const _Tokens({
    required this.glow,
    required this.iconGrad,
    required this.bar,
    required this.titleColor,
    required this.messageColor,
    required this.borderColor,
    required this.icon,
  });

  static _Tokens of(AppToastType t, {IconData? override}) {
    switch (t) {
      case AppToastType.success:
        return _Tokens(
          glow: const Color(0xFF22C55E),
          iconGrad: [const Color(0xFF15803D), const Color(0xFF4ADE80)],
          bar: const Color(0xFF16A34A),
          titleColor: const Color(0xFF14532D),
          messageColor: const Color(0xFF166534),
          borderColor: const Color(0xFFBBF7D0),
          icon: override ?? Icons.check_rounded,
        );
      case AppToastType.warning:
        return _Tokens(
          glow: const Color(0xFFF59E0B),
          iconGrad: [const Color(0xFFB45309), const Color(0xFFFCD34D)],
          bar: const Color(0xFFD97706),
          titleColor: const Color(0xFF451A03),
          messageColor: const Color(0xFF78350F),
          borderColor: const Color(0xFFFDE68A),
          icon: override ?? Icons.warning_rounded,
        );
      case AppToastType.error:
        return _Tokens(
          glow: const Color(0xFFEF4444),
          iconGrad: [const Color(0xFFB91C1C), const Color(0xFFFCA5A5)],
          bar: const Color(0xFFDC2626),
          titleColor: const Color(0xFF450A0A),
          messageColor: const Color(0xFF7F1D1D),
          borderColor: const Color(0xFFFECACA),
          icon: override ?? Icons.close_rounded,
        );
      case AppToastType.info:
        return _Tokens(
          glow: const Color(0xFF137FEC),
          iconGrad: [const Color(0xFF1558A8), const Color(0xFF60AFFE)],
          bar: const Color(0xFF137FEC),
          titleColor: const Color(0xFF0C2D5A),
          messageColor: const Color(0xFF1E4A8A),
          borderColor: const Color(0xFFBFDBFE),
          icon: override ?? Icons.info_rounded,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Slide + fade + scale entrance
// ─────────────────────────────────────────────────────────────────────────────
class _ToastRoot extends StatefulWidget {
  final AppToastType type;
  final String title, message;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction, onDismiss;
  final IconData? overrideIcon;

  const _ToastRoot({
    required this.type, required this.title, required this.message,
    required this.duration, required this.onDismiss,
    this.actionLabel, this.onAction, this.overrideIcon,
  });

  @override
  State<_ToastRoot> createState() => _ToastRootState();
}

class _ToastRootState extends State<_ToastRoot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 440),)..forward();

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0.6, 0), end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutExpo));

  late final Animation<double> _fade = Tween<double>(begin: 0.0, end: 1.0)
      .animate(CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.55)));

  late final Animation<double> _scale = Tween<double>(begin: 0.88, end: 1.0)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  Future<void> _dismiss() async { await _c.reverse(); widget.onDismiss?.call(); }

  @override
  Widget build(BuildContext context) => SlideTransition(
    position: _slide,
    child: FadeTransition(opacity: _fade,
      child: ScaleTransition(scale: _scale, alignment: Alignment.topRight,
        child: _ToastCard(
          tokens: _Tokens.of(widget.type, override: widget.overrideIcon),
          title: widget.title, message: widget.message,
          duration: widget.duration, actionLabel: widget.actionLabel,
          onAction: widget.onAction, onDismiss: _dismiss,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  The actual card — light / white glass
// ─────────────────────────────────────────────────────────────────────────────
class _ToastCard extends StatefulWidget {
  final _Tokens tokens;
  final String title, message;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Future<void> Function() onDismiss;

  const _ToastCard({
    required this.tokens, required this.title, required this.message,
    required this.duration, required this.onDismiss,
    this.actionLabel, this.onAction,
  });

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _prog = AnimationController(
      vsync: this, duration: widget.duration,)..forward();

  bool _hovered = false;

  @override
  void dispose() { _prog.dispose(); super.dispose(); }

  void _setHover(bool v) {
    setState(() => _hovered = v);
    v ? _prog.stop() : _prog.forward();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final hasAction = (widget.actionLabel?.trim().isNotEmpty ?? false)
        && widget.onAction != null;

    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit:  (_) => _setHover(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          // ── Light white with faint blue tint ──────────────────────
          color: const Color(0xFFFAFCFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered ? t.borderColor : t.borderColor.withOpacity(0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: t.glow.withOpacity(_hovered ? 0.18 : 0.10),
              blurRadius: _hovered ? 40 : 24,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(kIsWeb ? 0.06 : 0.09),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // ── Body ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 15, 10, 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Icon with gradient background + glow
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: t.iconGrad,
                    ),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: t.glow.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(t.icon, color: Colors.white, size: 19),
                ),

                const SizedBox(width: 13),

                // Title + message + optional action
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: t.titleColor,
                        letterSpacing: -0.15,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.message,
                      maxLines: hasAction ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: t.messageColor.withOpacity(0.85),
                        height: 1.45,
                      ),
                    ),
                    if (hasAction) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () { widget.onAction?.call(); widget.onDismiss(); },
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(widget.actionLabel!,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: t.bar,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(Icons.arrow_forward_rounded,
                              size: 13, color: t.bar,),
                        ],),
                      ),
                    ],
                  ],
                ),),

                const SizedBox(width: 6),

                // Close button
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: _hovered
                          ? t.glow.withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.close_rounded, size: 15,
                        color: t.titleColor.withOpacity(0.4),),
                  ),
                ),
              ],),
            ),

            // ── Progress bar ────────────────────────────────────────
            AnimatedBuilder(
              animation: _prog,
              builder: (_, __) => Stack(children: [
                // track
                Container(height: 2.5,
                    color: t.borderColor.withOpacity(0.4),),
                // fill
                FractionallySizedBox(
                  widthFactor: 1.0 - _prog.value,
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [t.bar.withOpacity(0.5), t.bar],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: t.glow.withOpacity(0.6),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              ],),
            ),

          ],),
        ),
      ),
    );
  }
}
