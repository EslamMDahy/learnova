import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:learnova/core/ui/toast.dart';
import '../design_tokens.dart';
import 'buttons.dart';
import 'inputs.dart';
import 'dropdowns.dart';

/// Misc widgets (layout, table bits, sidebar, uploaders, empty states, etc.).

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AppSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.sectionTitle),
                AppSpacing.gap4,
                Text(subtitle, style: AppText.sectionSubtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

@Deprecated('Use AppButton(variant: AppButtonVariant.soft)')

class AppToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const AppToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppText.input.copyWith(fontWeight: FontWeight.w500, height: 20 / 14),
              ),
              AppSpacing.gap4,
              Text(subtitle, style: AppText.mutedSmall),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: AppColors.primary,
          inactiveThumbColor: AppColors.cardBg,
          inactiveTrackColor: AppColors.borderSoft,
        ),
      ],
    );
  }
}

class AppNotifIconButton extends StatelessWidget {
  final bool hasBadge;
  final VoidCallback? onTap;

  const AppNotifIconButton({
    super.key,
    required this.hasBadge,
    this.onTap,
  });

  static Color get _muted => AppColors.textMuted;
  static Color get _danger => AppColors.errorDot;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return SizedBox(
      width: 24.01,
      height: 27.99,
      child: InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
        onTap: onTap ??
            () {
              AppToast.info(
                context,
                title: 'Coming soon',
                message: 'Notifications coming soon',
              );
            },
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              child: Icon(
                Icons.notifications_none_outlined,
                color: _muted,
                size: 24,
              ),
            ),
            if (hasBadge)
              Positioned(
                right: 0.01,
                top: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _danger,
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: AppColors.cardBg, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AppSidebarItem {
  final IconData icon;
  final String title;
  final int index;

  const AppSidebarItem({
    required this.icon,
    required this.title,
    required this.index,
  });
}

/* -------------------- App Sidebar -------------------- */

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  final String brandTitle;
  final String portalSubtitle;
  final String? logoAssetPath;
  final VoidCallback? onBrandTap;

  final List<AppSidebarItem> mainItems;
  final List<AppSidebarItem> bottomItems;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.portalSubtitle,
    required this.mainItems,
    required this.bottomItems,
    this.brandTitle = 'Learnova',
    this.logoAssetPath = 'assets/logo.webp',
    this.onBrandTap,
  });

  static const double _w              = 260;
  static Color get _rightBorder => AppColors.sidebarBorder; // subtle right separator
  static Color get _sectionLabel => AppColors.sidebarLabel;
  static Color get _divider => AppColors.divider;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return SizedBox(
      width: _w,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border(
            right: BorderSide(color: _rightBorder),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Brand ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: _AppSidebarBrandHeader(
                  title: brandTitle,
                  subtitle: portalSubtitle,
                  logoAssetPath: logoAssetPath,
                  onTap: onBrandTap ??
                      () => onItemSelected(
                            mainItems.isNotEmpty ? mainItems.first.index : 0,
                          ),
                ),
              ),

              // ── Section label + main nav ──────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 20, 6, 4),
                        child: Text(
                          'NAVIGATION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: _sectionLabel,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Scrollbar(
                          thumbVisibility: !kIsWeb,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            physics: const ClampingScrollPhysics(),
                            itemCount: mainItems.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: _AppSidebarNavLink(
                                icon: mainItems[i].icon,
                                title: mainItems[i].title,
                                index: mainItems[i].index,
                                selectedIndex: selectedIndex,
                                onTap: onItemSelected,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Bottom items ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: _divider)),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < bottomItems.length; i++) ...[
                      _AppSidebarNavLink(
                        icon: bottomItems[i].icon,
                        title: bottomItems[i].title,
                        index: bottomItems[i].index,
                        selectedIndex: selectedIndex,
                        onTap: onItemSelected,
                      ),
                      if (i != bottomItems.length - 1)
                        const SizedBox(height: 2),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------- Brand Header -------------------- */

class _AppSidebarBrandHeader extends StatelessWidget {
  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final String? logoAssetPath;

  const _AppSidebarBrandHeader({
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.logoAssetPath,
  });

  static Color get _text => AppColors.textTitle;
  static Color get _muted => AppColors.textGray500;
  static Color get _logoBg => AppColors.cardBg;
  static Color get _logoBorder => AppColors.border;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _logoBg,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _logoBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: logoAssetPath == null
                    ? const Icon(Icons.auto_awesome, size: 18,
                        color: AppColors.primary,)
                    : Image.asset(
                        logoAssetPath!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.auto_awesome, size: 18,
                          color: AppColors.primary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _text,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------- Nav Link -------------------- */

class _AppSidebarNavLink extends StatefulWidget {
  final IconData icon;
  final String title;
  final int index;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _AppSidebarNavLink({
    required this.icon,
    required this.title,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  State<_AppSidebarNavLink> createState() => _AppSidebarNavLinkState();
}

class _AppSidebarNavLinkState extends State<_AppSidebarNavLink> {
  bool _hovered = false;
  bool _focused = false;

  static Color get _primary => AppColors.primary;
  static Color get _selectedBg => AppColors.sidebarSelectedBg;
  static Color get _hoverBg => AppColors.sidebarHoverBg;
  static Color get _idleFg => AppColors.textMuted;
  static Color get _selectedFg => AppColors.primary;
  static Color get _hoverFg => AppColors.textGray;
  static Color get _barColor => AppColors.primary;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final sel = widget.selectedIndex == widget.index;

    final bg = sel ? _selectedBg : _hovered ? _hoverBg : Colors.transparent;
    final fg = sel ? _selectedFg : _hovered ? _hoverFg : _idleFg;

    return Semantics(
      button: true,
      selected: sel,
      label: widget.title,
      child: Focus(
        onFocusChange: (v) => setState(() => _focused = v),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit:  (_) => setState(() => _hovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => widget.onTap(widget.index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: 42,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border: _focused
                    ? Border.all(
                        color: _primary.withValues(alpha: 0.45),
                        width: 1.5,
                      )
                    : null,
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Active indicator bar (left edge)
                  if (sel)
                    Positioned(
                      left: 0, top: 10, bottom: 10,
                      child: Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: _barColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  // Row content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(widget.icon, size: 19, color: fg),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight:
                                  sel ? FontWeight.w700 : FontWeight.w500,
                              color: fg,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class AppFormHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AppFormHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return AppDialogTitleBlock(title: title, subtitle: subtitle);
  }
}


// ===================== Auth / Forms Reusables =====================

class AppErrorBox extends StatelessWidget {
  final String message;
  const AppErrorBox({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.dangerBorder),
      ),
      child: Text(
        message,
        style: AppText.mutedSmall.copyWith(
          color: AppColors.dangerTitle,
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class AppSegmentOption<T> {
  final String label;
  final T value;
  const AppSegmentOption({required this.label, required this.value});
}



class AppSegmentedControl<T> extends StatelessWidget {
  final List<AppSegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool disabled;

  const AppSegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.disabled = false,
  });

  static Color get _bg => AppColors.borderGray;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _bg,
      ),
      child: Row(
        children: [
          for (int i = 0; i < options.length; i++) ...[
            Expanded(
              child: _SegmentChip(
                text: options[i].label,
                selected: options[i].value == value,
                onTap: disabled ? null : () => onChanged(options[i].value),
              ),
            ),
            if (i != options.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback? onTap;

  const _SegmentChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: kIsWeb ? Duration.zero : const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.cardBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.shadowThin,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.title : AppColors.textGray500,
              height: 20 / 14,
            ),
          ),
        ),
      ),
    );
  }
}

class AppLabeledIconField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const AppLabeledIconField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final radius = BorderRadius.circular(10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        AppSpacing.gap6,
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          validator: validator,
          style: TextStyle(
            color: AppColors.title,
            fontSize: 15,
            height: 1.4,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.hint,
            prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: AppColors.pageBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: AppColors.borderGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: AppColors.dangerText),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: AppColors.dangerText, width: 1.5),
            ),
            errorStyle: const TextStyle(fontSize: 12, height: 1.2),
          ),
        ),
      ],
    );
  }
}

class AppPasswordStrengthHints extends StatelessWidget {
  final String password;
  const AppPasswordStrengthHints({super.key, required this.password});

  bool _has(String pattern) => RegExp(pattern).hasMatch(password);
  bool get _len => password.trim().length >= 8;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    Widget chip(String text, bool ok) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: ok ? AppColors.successBg : AppColors.divider,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: ok ? AppColors.greenBorder : AppColors.borderGray,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: ok ? AppColors.successText : AppColors.textGray500,
            fontWeight: ok ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('8+ chars', _len),
        chip('A-Z', _has(r'[A-Z]')),
        chip('a-z', _has(r'[a-z]')),
        chip('0-9', _has(r'\d')),
        chip('Symbol', _has(r'[!@#$%^&*(),.?":{}|<>_\-\\/\[\]=+~`]')),
      ],
    );
  }
}

enum AppInfoType { success, error }

class AppInfoCard extends StatelessWidget {
  final AppInfoType type;
  final String title;
  final String message;

  const AppInfoCard({
    super.key,
    required this.type,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final isSuccess = type == AppInfoType.success;

    final bg = isSuccess ? AppColors.successBg : AppColors.dangerBg;
    final border = isSuccess ? AppColors.greenBorder : AppColors.dangerBorder;
    final icon =
        isSuccess ? Icons.check_circle_rounded : Icons.error_rounded;
    final iconColor = isSuccess ? AppColors.successText : AppColors.dangerTitle;
    final textColor = iconColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppAuthHeaderIcon extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const AppAuthHeaderIcon({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(icon, color: AppColors.primary, size: 26),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: AppText.h1.copyWith(fontSize: 28, color: AppColors.title),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: AppText.subtitle.copyWith(
            color: AppColors.muted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
class AppPrimaryLoadingButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final double height;

  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  const AppPrimaryLoadingButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
    this.height = 50,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  TextStyle _autoTextStyle(Color fg) {
    if (height <= 36) {
      return TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600);
    }
    if (height <= 40) {
      return TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600);
    }
    if (height <= 48) {
      return TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w700);
    }
    return TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w700);
  }

  EdgeInsets _autoPadding() {
    
    if (height <= 36) return const EdgeInsets.symmetric(horizontal: 10);
    if (height <= 40) return const EdgeInsets.symmetric(horizontal: 12);
    return const EdgeInsets.symmetric(horizontal: 16);
  }

  double _loaderSize() {
    if (height <= 36) return 14;
    if (height <= 40) return 16;
    return 20;
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final bg = backgroundColor ?? AppColors.primary;
    final fg = foregroundColor ?? Colors.white;

    final borderSide = borderColor == null
        ? BorderSide.none
        : BorderSide(color: borderColor!);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.6),
          disabledForegroundColor: fg.withValues(alpha: 0.85),
          elevation: 0,
          padding: _autoPadding(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: borderSide,
          ),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? SizedBox(
                width: _loaderSize(),
                height: _loaderSize(),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fg,
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown, 
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _autoTextStyle(fg),
                ),
              ),
      ),
    );
  }
}

class AppBackLink extends StatelessWidget {
  final String? label;
  final VoidCallback? onTap;
  final bool showLabel;

  const AppBackLink({
    super.key,
    this.label,
    required this.onTap,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.textMuted),
          if (showLabel && (label ?? '').isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              label!,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}



@Deprecated('Use AppBackLink(showLabel: true)')

class AppBackLinkLabeled extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const AppBackLinkLabeled({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return AppBackLink(label: label, onTap: onTap, showLabel: true);
  }
}


// ===================== Auth Layout / Helpers =====================

class AppAuthShell extends StatelessWidget {
  final bool isMobile;
  final Widget child;
  final double maxWidth;

  const AppAuthShell({
    super.key,
    required this.child,
    this.isMobile = false,
    this.maxWidth = 420,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      color: AppColors.pageBg,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 56),
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

class AppAuthOrDivider extends StatelessWidget {
  const AppAuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR CONTINUE WITH',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class AppSocialButton extends StatelessWidget {
  final String label;
  final String imagePath;
  final VoidCallback onTap;
  final bool disabled;

  const AppSocialButton({
    super.key,
    required this.label,
    required this.imagePath,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.borderSoft),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: disabled ? null : onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, width: 40, height: 35, fit: BoxFit.contain),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(color: AppColors.textTitle, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class AppSuccessBanner extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onClose;

  const AppSuccessBanner({
    super.key,
    required this.title,
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: kIsWeb ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.successBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.greenBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.check_circle,
                  color: AppColors.successText, size: 20,),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.successText,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      color: AppColors.successText,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
              borderRadius: BorderRadius.circular(8),
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child:
                    Icon(Icons.close, size: 16, color: AppColors.successText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppRememberForgotRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onForgot;
  final bool disabled;

  const AppRememberForgotRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onForgot,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Row(
      children: [
        Checkbox(
          value: value,
          activeColor: AppColors.primary,
          checkColor: Colors.white,
          onChanged: disabled ? null : onChanged,
        ),
        Text(
          'Remember me',
          style: TextStyle(color: AppColors.textTitle, fontSize: 14),
        ),
        const Spacer(),
        TextButton(
          onPressed: disabled ? null : onForgot,
          child: const Text(
            'Forgot Password?',
            style: TextStyle(color: AppColors.primary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class AppOutlinedLoadingButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final double height;

  const AppOutlinedLoadingButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}

class AppTextLoadingButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const AppTextLoadingButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return TextButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

// ===================== Dialog / Admin Form Reusables =====================

class AppDialogShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double maxHeight;

  const AppDialogShell({
    super.key,
    required this.child,
    this.maxWidth = 1184,
    this.maxHeight = 820,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Dialog(
      backgroundColor: AppColors.headerBg, // close to figma bg
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: child,
        ),
      ),
    );
  }
}

class AppDialogTitleBlock extends StatelessWidget {
  final String title;
  final String subtitle;

  const AppDialogTitleBlock({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.h1),
        AppSpacing.gap8,
        Text(subtitle, style: AppText.subtitle),
      ],
    );
  }
}

class AppCardHeaderRow extends StatelessWidget {
  final IconData icon;
  final String title;

  const AppCardHeaderRow({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 25 / 20,
            color: AppColors.title,
          ),
        ),
      ],
    );
  }
}

class AppSubHeaderText extends StatelessWidget {
  final String title;

  const AppSubHeaderText({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.title,
      ),
    );
  }
}

class AppLabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final double gap;

  const AppLabeledField({
    super.key,
    required this.label,
    required this.child,
    this.gap = 8,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        SizedBox(height: gap),
        child,
      ],
    );
  }
}

class AppTextField48 extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final int? maxLen;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  const AppTextField48({
    super.key,
    required this.controller,
    required this.hint,
    this.focusNode,
    this.maxLen,
    this.onChanged,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLength: maxLen,
        enabled: enabled,
        onChanged: onChanged,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.title,
        ),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.muted,
          ),
          filled: true,
          fillColor: AppColors.cardBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.borderSoft),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Inline info banner with primary brand tint.
class AppInfoInlineBox extends StatelessWidget {
  final String message;
  final VoidCallback? onTap;

  const AppInfoInlineBox({
    super.key,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.infoBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Need help? Chat with our support team or learn more about how organizations work.',
                style: TextStyle(
                  fontSize: 13,
                  height: 20 / 13,
                  color: AppColors.infoText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppLogoUrlUploader extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onUploadPressed;

  const AppLogoUrlUploader({
    super.key,
    required this.controller,
    this.onChanged,
    this.onUploadPressed,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.headerBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Icon(Icons.image_outlined, color: AppColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(fontSize: 14, color: AppColors.title),
              decoration: InputDecoration(
                hintText: 'Paste logo URL (optional)',
                hintStyle: TextStyle(fontSize: 14, color: AppColors.muted),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onUploadPressed ??
                () {
                  AppToast.info(
                  context,
                  title: 'Coming soon',
                  message: 'Upload coming soon — use URL for now.',
                );
                },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Upload Logo',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;

  final double maxWidth;
  final EdgeInsets padding;

  const AppEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.maxWidth = 720,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
  });

  void _handleTap(BuildContext context) {
    FocusScope.of(context).unfocus();
    onPrimaryAction();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppText.h1.copyWith(
                  fontSize: 48,
                  height: 60 / 48,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.subtitle,
              ),
              const SizedBox(height: 22),
              Semantics(
                button: true,
                label: primaryActionLabel,
                child: AppButton(
                  label: primaryActionLabel,
                  onTap: () => _handleTap(context),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}




@Deprecated('Use AppCardShell')

class FigmaUmPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const FigmaUmPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 36 / 30,
            letterSpacing: -0.75,
            color: AppColors.cText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 24 / 16,
            color: AppColors.cMuted,
          ),
        ),
      ],
    );
  }
}

class FigmaUmSquareIconBtn40 extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const FigmaUmSquareIconBtn40({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(hoverColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: const WidgetStatePropertyAll(Colors.transparent), 
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.cSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: AppColors.cGray500),
        ),
      ),
    );
  }
}

class FigmaUmFiltersBar extends StatelessWidget {
  final TextEditingController controller;
  final String selectedRole;
  final String selectedStatus;
  final bool isNarrow;

  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onStatusChanged;

  final VoidCallback onMoreFilters;
  final VoidCallback onRefresh;

const FigmaUmFiltersBar({
    super.key,
    required this.controller,
    required this.selectedRole,
    required this.selectedStatus,
    required this.isNarrow,
    required this.onSearchChanged,
    required this.onRoleChanged,
    required this.onStatusChanged,
    required this.onMoreFilters,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final roleDrop = FigmaUmDropdown40(
      width: isNarrow ? 150 : 140,
      value: selectedRole,
      items: ['All Roles', 'owner', 'teacher', 'student', 'assistant'],
      onChanged: onRoleChanged,
    );

    final statusDrop = FigmaUmDropdown40(
      width: isNarrow ? 150 : 140,
      value: selectedStatus,
      items: ['All Status', 'pending', 'accepted', 'suspended', 'declined'],
      onChanged: onStatusChanged,
    );

    final search = FigmaUmSearch40(
      controller: controller,
      onChanged: onSearchChanged,
    );

    final moreFilters = FigmaUmSquareIconBtn40(
      icon: Icons.tune_rounded,
      onTap: onMoreFilters,
      tooltip: 'More filters',
    );

    final refresh = FigmaUmSquareIconBtn40(
      icon: Icons.refresh,
      onTap: onRefresh,
      tooltip: 'Refresh',
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cBorder),
        boxShadow: [
          const BoxShadow(
              color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1),),
        ],
      ),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                search,
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    roleDrop,
                    statusDrop,
                    moreFilters,
                    refresh,
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 16),
                roleDrop,
                const SizedBox(width: 12),
                statusDrop,
                const Spacer(),
                moreFilters,
                const SizedBox(width: 8),
                refresh,
              ],
            ),
    );
  }
}

class FigmaUmTableHeader extends StatelessWidget {
  final bool isNarrow;
  final double actionsColWidth;
  final double cellLeftPad;
  final double rowHPad;

  const FigmaUmTableHeader({
    super.key,
    required this.isNarrow,
    required this.actionsColWidth,
    required this.cellLeftPad,
    required this.rowHPad,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      height: 49,
      color: AppColors.cSurface,
      padding: EdgeInsets.symmetric(horizontal: rowHPad),
      child: Row(
        children: [
          const SizedBox(width: 16, height: 16),
          const SizedBox(width: 16),

          FigmaUmHeaderCellFlex(flex: 5, text: 'USER INFO', leftPad: cellLeftPad),
          FigmaUmHeaderCellFlex(flex: 2, text: 'ROLE', leftPad: cellLeftPad),

          if (!isNarrow)
            FigmaUmHeaderCellFlex(
                flex: 3, text: 'DEPARTMENT', leftPad: cellLeftPad,),
          if (!isNarrow)
            FigmaUmHeaderCellFlex(
                flex: 2, text: 'JOINED DATE', leftPad: cellLeftPad,),

          FigmaUmHeaderCellFlex(flex: 2, text: 'STATUS', leftPad: cellLeftPad),

          SizedBox(
            width: actionsColWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'ACTIONS',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 16 / 12,
                    color: AppColors.cGray500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FigmaUmHeaderCellFlex extends StatelessWidget {
  final int flex;
  final String text;
  final double leftPad;

  const FigmaUmHeaderCellFlex({
    super.key,
    required this.flex,
    required this.text,
    this.leftPad = 0,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.only(left: leftPad),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 16 / 12,
            color: AppColors.cGray500,
          ),
        ),
      ),
    );
  }
}

class FigmaUmEmptyTableState extends StatelessWidget {
  final String message;
  const FigmaUmEmptyTableState({
    super.key,
    this.message = 'No users match your filters right now.',
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Row(
      children: [
        Icon(Icons.inbox_outlined, color: AppColors.cGray500),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 20 / 14,
              color: AppColors.cGray500,
            ),
          ),
        ),
      ],
    );
  }
}

class FigmaUmTableFooter extends StatelessWidget {
  final String showingText;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const FigmaUmTableFooter({
    super.key,
    required this.showingText,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      height: 71,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cSurface,
        border: Border(top: BorderSide(color: AppColors.cBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              showingText,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 20 / 14,
                color: AppColors.cGray500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              FigmaUmPageBtn(
                label: 'Previous',
                icon: Icons.chevron_left,
                enabled: onPrev != null,
                onTap: onPrev,
                width: 105,
                trailingIcon: false,
              ),
              const SizedBox(width: 8),
              FigmaUmPageBtn(
                label: 'Next',
                icon: Icons.chevron_right,
                enabled: onNext != null,
                onTap: onNext,
                width: 79,
                trailingIcon: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FigmaUmPageBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  final double width;
  final bool trailingIcon;

  const FigmaUmPageBtn({
    super.key,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.width,
    required this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: SizedBox(
        width: width,
        height: 38,
        child: OutlinedButton(
          onPressed: enabled ? onTap : null,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.borderSoft),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            backgroundColor: AppColors.cBg,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: trailingIcon
                ? [
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 20 / 14,
                          color: AppColors.cGray500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(icon, size: 18, color: AppColors.cGray500),
                  ]
                : [
                    Icon(icon, size: 18, color: AppColors.cGray500),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 20 / 14,
                          color: AppColors.cGray500,
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

/* ============================================================
   Join Requests - Figma Reusables (NO UI CHANGE)
============================================================ */

@Deprecated('Use AppCardShell(maxWidth: ...)')

class JrHScroll extends StatelessWidget {
  final Widget child;
  const JrHScroll({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: child,
    );
  }
}

class JrHeaderTxt extends StatelessWidget {
  final String text;
  const JrHeaderTxt(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textGray500,
      ),
    );
  }
}

@Deprecated('Use FigmaUmEmptyTableState(message: ...)')

class JrEmptyTableState extends StatelessWidget {
  const JrEmptyTableState({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return const FigmaUmEmptyTableState(
      message: 'No pending join requests right now.',
    );
  }
}

class JrRefreshIconBtnFigma extends StatelessWidget {
  final VoidCallback? onPressed;
  const JrRefreshIconBtnFigma({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return SizedBox(
      height: 40,
      width: 40,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(color: AppColors.borderGray),
          backgroundColor: AppColors.surfaceBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Icon(Icons.refresh, size: 18, color: AppColors.textGray500),
      ),
    );
  }
}

/* =========================
   Role + Status
========================= */
