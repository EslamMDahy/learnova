import 'package:flutter/material.dart';
import '../design_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AppLabeledTextField  —  THE canonical text input for the whole project.
//
//  Usage:
//    AppLabeledTextField(label: 'Email', controller: ctrl, hint: 'you@email.com')
//    AppLabeledTextField(label: 'Bio', controller: ctrl, hint: '...', expands: true, height: 100)
//    AppLabeledTextField(label: 'Password', controller: ctrl, hint: '••••', obscureText: true)
//
//  All other text-input widgets in this file are thin wrappers or aliases.
// ─────────────────────────────────────────────────────────────────────────────

class AppLabeledTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final String? helper;
  final String? errorText;
  final double height;
  final EdgeInsets contentPadding;
  final bool expands;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool enabled;
  final Widget? suffix;
  final TextInputAction? textInputAction;

  const AppLabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.helper,
    this.errorText,
    this.height = 44,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.expands = false,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.enabled = true,
    this.suffix,
    this.textInputAction,
  });

  @override
  State<AppLabeledTextField> createState() => _AppLabeledTextFieldState();
}

class _AppLabeledTextFieldState extends State<AppLabeledTextField> {
  late final FocusNode _focus;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusNode ?? FocusNode();
    _focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() => _focused = _focus.hasFocus);

  @override
  void dispose() {
    if (widget.focusNode == null) _focus.dispose();
    _focus.removeListener(_onFocus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final borderColor = hasError
        ? AppColors.dangerBorder
        : _focused
            ? AppColors.primary
            : AppColors.borderSoft;
    final borderWidth = _focused || hasError ? 1.5 : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label, style: AppText.label),
        AppSpacing.gap6,
        Container(
          height: widget.expands ? null : widget.height,
          constraints: widget.expands
              ? BoxConstraints(minHeight: widget.height)
              : null,
          decoration: BoxDecoration(
            color: widget.enabled ? Colors.white : AppColors.pageBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          padding: widget.contentPadding,
          alignment: widget.expands ? null : Alignment.centerLeft,
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.obscureText,
            expands: widget.expands,
            maxLines: widget.expands ? null : widget.maxLines,
            minLines: widget.expands ? null : widget.minLines,
            keyboardType: widget.keyboardType,
            enabled: widget.enabled,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            textInputAction: widget.textInputAction,
            textAlignVertical: widget.expands
                ? TextAlignVertical.top
                : TextAlignVertical.center,
            style: AppText.input.copyWith(
              height: widget.expands ? 20 / 14 : null,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: AppText.hint.copyWith(
                  height: widget.expands ? 20 / 14 : null,),
              suffixIcon: widget.suffix,
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              filled: false,
            ),
          ),
        ),
        if (hasError) ...[
          AppSpacing.gap4,
          Text(widget.errorText!,
              style: AppText.mutedSmall.copyWith(color: AppColors.dangerText),),
        ] else if (widget.helper != null) ...[
          AppSpacing.gap6,
          Text(widget.helper!, style: AppText.mutedSmall),
        ],
      ],
    );
  }
}

// ─── Aliases (convenience, not extra classes) ─────────────────────────────────

/// Alias for AppLabeledTextField — same thing, different name kept for compat.
typedef AppLabeledInput = AppLabeledTextField;

// ─── Search field (header variant) ───────────────────────────────────────────

/// The search bar used in the top header and filters bars.
/// Preferred over AppSearchField for all new code.
class FigmaUmSearch40 extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  const FigmaUmSearch40({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search by name, ID, or email...',
  });

  static const Color _text   = Color(0xFF111418);
  static const Color _muted  = Color(0xFF617589);
  static const Color _bg     = Color(0xFFF0F2F4);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SizedBox(
          height: 40,
          child: Row(children: [
            const SizedBox(width: 14),
            const Icon(Icons.search, size: 18, color: _muted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textAlignVertical: TextAlignVertical.center,
                cursorHeight: 16,
                style: AppText.input.copyWith(
                      color: AppColors.textTitle,
                      height: 1.0, 
                      leadingDistribution: TextLeadingDistribution.even,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  hint: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 19 / 14,
                      color: _muted,
                    ),
                  ),
                  isCollapsed: true,
                ),
              ),
            ),
          ],),
        ),
      ),
    );
  }
}

// ─── Read-only display field ──────────────────────────────────────────────────

class AppReadOnlyInput extends StatelessWidget {
  final String label;
  final String value;
  final String? rightTag;
  final IconData icon;

  const AppReadOnlyInput({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.rightTag,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        AppSpacing.gap6,
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.pageBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(children: [
            const SizedBox(width: 14),
            Icon(icon, size: 18, color: AppColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: AppText.input.copyWith(
                    fontWeight: FontWeight.w500, color: AppColors.muted,),
              ),
            ),
            if (rightTag != null) ...[
              Text(rightTag!.toUpperCase(), style: AppText.mutedSmall.copyWith(
                  fontWeight: FontWeight.w700, letterSpacing: 0.3,),),
              const SizedBox(width: 14),
            ],
          ],),
        ),
      ],
    );
  }
}

// ─── Deprecated aliases (kept for backward compatibility only) ────────────────

@Deprecated('Use AppLabeledTextField(obscureText: true)')
class AppLabeledPassword extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? helper;

  const AppLabeledPassword({
    super.key,
    required this.label,
    required this.controller,
    this.helper,
  });

  @override
  Widget build(BuildContext context) => AppLabeledTextField(
        label: label,
        controller: controller,
        hint: '••••••••••••',
        obscureText: true,
        helper: helper,
      );
}

@Deprecated('Use AppLabeledTextField(expands: true, height: 100)')
class AppLabeledTextarea extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const AppLabeledTextarea({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) => AppLabeledTextField(
        label: label,
        controller: controller,
        hint: hint,
        height: 100,
        expands: true,
        contentPadding: const EdgeInsets.all(14),
      );
}

@Deprecated('Use FigmaUmSearch40')
class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) => FigmaUmSearch40(
        controller: controller,
        onChanged: (_) {},
        hint: hintText,
      );
}

@Deprecated('Use FigmaUmSearch40')
class AppHeaderSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;

  const AppHeaderSearchField({
    super.key,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => FigmaUmSearch40(
        controller: TextEditingController(),
        onChanged: onChanged ?? (_) {},
        hint: hint,
      );
}
