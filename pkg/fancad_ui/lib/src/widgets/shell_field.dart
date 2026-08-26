import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'shell_icon_button.dart';

/// A text field styled for the shell rather than for Material.
class ShellTextField extends StatelessWidget {
  const ShellTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.onSubmitted,
    this.onChanged,
    this.style,
    this.obscureText = false,
    this.autofocus = false,
    this.prefix,
    this.suffix,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;
  final bool obscureText;
  final bool autofocus;
  final Widget? prefix;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final effective = style ?? tokens.monoStyle;
    return Row(
      children: [
        ?prefix,
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            obscureText: obscureText,
            style: effective,
            cursorColor: tokens.accent,
            cursorWidth: 1.5,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: hintText,
              hintStyle: effective.copyWith(color: tokens.textFaint),
            ),
            onSubmitted: onSubmitted,
            onChanged: onChanged,
          ),
        ),
        ?suffix,
      ],
    );
  }
}

/// A dense outlined field with an accent focus ring.
class SettingsTextField extends StatefulWidget {
  const SettingsTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.style,
  });

  final TextEditingController controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final TextStyle? style;

  @override
  State<SettingsTextField> createState() => _SettingsTextFieldState();
}

class _SettingsTextFieldState extends State<SettingsTextField> {
  late final FocusNode _focus;
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _focus.addListener(_onFocus);
    _obscured = widget.obscureText;
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      height: 32,
      padding: EdgeInsets.only(
        left: FanCadTokens.space2,
        right: widget.obscureText ? 0 : FanCadTokens.space2,
      ),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        borderRadius: BorderRadius.circular(FanCadTokens.radius),
        border: Border.all(
          color: focused ? tokens.accent : tokens.borderStrong,
          width: focused ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ShellTextField(
              controller: widget.controller,
              focusNode: _focus,
              hintText: widget.hintText,
              obscureText: _obscured,
              style: widget.style ?? tokens.bodyStyle,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
            ),
          ),
          if (widget.obscureText)
            ShellIconButton(
              icon: _obscured
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 24,
              iconSize: FanCadTokens.iconSmall,
              onPressed: () => setState(() => _obscured = !_obscured),
            ),
        ],
      ),
    );
  }
}
