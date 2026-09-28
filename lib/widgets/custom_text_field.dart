import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Standard text field used across auth forms, the post-car form, filters,
/// etc. Wraps [TextFormField] so validation/decoration stays consistent
/// without every screen re-declaring the same InputDecoration.
///
/// Capitalizes the first word as the user types and turns on the system
/// spell-checker by default — the sensible default for prose-like fields
/// (names, addresses, descriptions, comments). Fields where that would be
/// actively wrong (email, password, phone, numbers) opt out automatically
/// based on [obscureText]/[keyboardType]; pass [textCapitalization] or
/// [enableSpellCheck] explicitly to override either one directly. Fields
/// that need word-by-word capitalization (e.g. "Toyota Corolla") or
/// sentence-by-sentence capitalization mid-string (free-form prose) still
/// pair this with a [CapitalizeWordsFormatter] / [CapitalizeSentencesFormatter]
/// via [inputFormatters] — [textCapitalization] alone only hints the
/// on-screen keyboard, it doesn't rewrite text a keyboard ignores it for.
///
/// Also owns a focus-tracking [FocusNode] purely for visual polish: a soft
/// brand-colored glow fades in around the field while it's focused, on top
/// of the theme's own border-color change, so typing somewhere feels like
/// a deliberate, lit-up moment rather than a static box.
class CustomTextField extends StatefulWidget {
  const CustomTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.enabled = true,
    this.textInputAction,
    this.onChanged,
    this.onFieldSubmitted,
    this.onFocusChange,
    this.autofocus = false,
    this.inputFormatters,
    this.textCapitalization,
    this.enableSpellCheck = true,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final bool enabled;
  final TextInputAction? textInputAction;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;

  /// Called with the new focus state whenever the field gains or loses
  /// focus — e.g. to act "on blur" once the user moves to the next field.
  final ValueChanged<bool>? onFocusChange;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization? textCapitalization;
  final bool enableSpellCheck;

  // Keyboard types where auto-capitalizing or spell-checking what's typed
  // would just get in the way (emails, phone numbers, raw digits).
  // TextInputType overrides ==, which disqualifies it from a const set
  // literal, hence the plain (non-const) list here.
  static final _plainTextKeyboardTypes = [
    TextInputType.emailAddress,
    TextInputType.phone,
    TextInputType.number,
    TextInputType.url,
    TextInputType.visiblePassword,
  ];

  bool get _isPlainTextEntry =>
      obscureText || (keyboardType != null && _plainTextKeyboardTypes.contains(keyboardType));

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  final _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_hasFocus != _focusNode.hasFocus) {
        setState(() => _hasFocus = _focusNode.hasFocus);
        widget.onFocusChange?.call(_focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: _hasFocus
                ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.18), blurRadius: 14, spreadRadius: 1)]
                : const [],
          ),
          child: TextFormField(
            focusNode: _focusNode,
            controller: widget.controller,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            validator: widget.validator,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            enabled: widget.enabled,
            inputFormatters: widget.inputFormatters,
            textInputAction: widget.textInputAction,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onFieldSubmitted,
            autofocus: widget.autofocus,
            textCapitalization: widget.textCapitalization ??
                (widget._isPlainTextEntry ? TextCapitalization.none : TextCapitalization.sentences),
            spellCheckConfiguration:
                (widget.enableSpellCheck && !widget._isPlainTextEntry) ? const SpellCheckConfiguration() : null,
            style: AppTextStyles.bodyLarge,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon, color: AppColors.textMuted, size: 20) : null,
              suffixIcon: widget.suffixIcon,
            ),
          ),
        ),
      ],
    );
  }
}
