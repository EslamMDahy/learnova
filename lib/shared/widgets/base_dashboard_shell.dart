import 'dart:math' as math;
import 'package:flutter/material.dart';

class BaseDashboardShell extends StatelessWidget {
  final Widget sidebar;
  final Widget header;
  final Widget child;

  final double asideWidth;
  final double contentMaxWidth;

  
  final EdgeInsets contentPadding;

  final Color backgroundColor;
  final Color dividerColor;

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
    this.backgroundColor = const Color(0xFFF6F7F8),
    this.dividerColor = const Color(0xFFEDF2F7),
    this.enableResponsive = true,
    this.drawerBreakpoint = 1100,
    this.compactPaddingBreakpoint = 900,
    this.compactPadding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    this.wrapChild = true,
  });

  @override
  Widget build(BuildContext context) {
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

    final content = Container(
      color: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: dividerColor)),
            ),
            child: header,
          ),
          Expanded(child: effectiveBody),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: backgroundColor,
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
