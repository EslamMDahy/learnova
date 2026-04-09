import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:learnova/core/theme/app_theme.dart';

class AppDialogTokens {
  AppDialogTokens._();

  static const double radius = 10;
  static const Color barrier = Color(0x7A0E1B2C);
  static const EdgeInsets insetPadding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 24,
  );
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
}) {
  return showDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? AppDialogTokens.barrier,
    barrierLabel: barrierLabel,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
  );
}

class AppDialogSurface extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final double? maxHeight;
  final EdgeInsets? insetPadding;
  final Color backgroundColor;
  final bool blurBackdrop;

  const AppDialogSurface({
    super.key,
    required this.child,
    this.maxWidth,
    this.maxHeight,
    this.insetPadding,
    this.backgroundColor = Colors.white,
    this.blurBackdrop = false,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content = Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: insetPadding ?? AppDialogTokens.insetPadding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDialogTokens.radius),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? 720,
          maxHeight: maxHeight ?? double.infinity,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppDialogTokens.radius),
          border: Border.all(color: AppColors.borderSoft),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A0F172A),
              blurRadius: 32,
              offset: Offset(0, 16),
            ),
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDialogTokens.radius),
          child: child,
        ),
      ),
    );

    if (!blurBackdrop) return content;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 2.4, sigmaY: 2.4),
      child: content,
    );
  }
}
