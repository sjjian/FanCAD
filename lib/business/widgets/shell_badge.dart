import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A compact accent tag, as used on command palette rows.
class ShellBadge extends StatelessWidget {
  const ShellBadge({super.key, required this.text, this.onTap, this.selected});

  final String text;
  final VoidCallback? onTap;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (onTap != null) {
      final isOn = selected ?? false;
      return Material(
        color: isOn ? tokens.selection : tokens.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FanCadTokens.radius),
          side: BorderSide(color: isOn ? tokens.accent : tokens.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FanCadTokens.radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FanCadTokens.space2,
              vertical: FanCadTokens.space1,
            ),
            child: Text(
              text,
              style: tokens.monoStyle.copyWith(
                fontSize: 11,
                color: isOn ? tokens.text : tokens.textMuted,
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: tokens.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: tokens.labelStyle.copyWith(fontSize: 9.5, color: tokens.accent),
      ),
    );
  }
}

/// A status light for list rows.
class ShellDot extends StatelessWidget {
  const ShellDot({super.key, required this.color, this.tooltip});

  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (tooltip == null || tooltip!.isEmpty) return dot;
    return Tooltip(message: tooltip!, child: dot);
  }
}
