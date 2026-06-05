import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'design_tokens.dart';

class BaseDashboardShell extends StatelessWidget {
  final Widget sidebar;
  final Widget header;
  final Widget child;

  final double asideWidth;
  final double contentMaxWidth;

  
  final EdgeInsets contentPadding;

  final Color? backgroundColor;
  final Color? dividerColor;

  final bool enableResponsive;
  final double drawerBreakpoint;
  final double compactPaddingBreakpoint;
  final EdgeInsets compactPadding;

  
  final bool wrapChild;

  const BaseDashboardShell({
    super.key,
    required this.sidebar,
    required this.header,
    required this.child,
    this.asideWidth = 288,
    this.contentMaxWidth = 1400,
    this.contentPadding =
        const EdgeInsets.symmetric(horizontal: 116, vertical: 32),
    this.backgroundColor,
    this.dividerColor,
    this.enableResponsive = true,
    this.drawerBreakpoint = 1100,
    this.compactPaddingBreakpoint = 900,
    this.compactPadding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    this.wrapChild = true,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final useDrawer = enableResponsive && w < drawerBreakpoint;

    
    final dynamicHorizontal = math.max(16.0, math.min(116.0, w * 0.08));
    final dynamicVertical = w < compactPaddingBreakpoint ? 16.0 : 32.0;

    final effectivePadding = (!enableResponsive)
        ? contentPadding
        : (w < compactPaddingBreakpoint
            ? compactPadding
            : EdgeInsets.symmetric(
                horizontal: dynamicHorizontal,
                vertical: dynamicVertical,
              ));

    final Widget effectiveBody = wrapChild
        ? Padding(
            padding: effectivePadding,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: child,
              ),
            ),
          )
        : child;

    final effectiveBackground = backgroundColor ?? AppColors.pageBg;
    final effectiveDivider = dividerColor ?? AppColors.border;

    final content = Container(
      color: effectiveBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border: Border(bottom: BorderSide(color: effectiveDivider)),
            ),
            child: header,
          ),
          Expanded(child: effectiveBody),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: effectiveBackground,
      drawer: useDrawer ? Drawer(child: SafeArea(child: sidebar)) : null,
      body: useDrawer
          ? content
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: asideWidth, child: sidebar),
                Expanded(child: content),
              ],
            ),
    );
  }
}
