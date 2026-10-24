import 'package:flutter/material.dart';

import 'tokens.dart';

/// A clickable keyword offered by the current command prompt.
///
/// A prompt that can only be answered by typing is a dead end for anyone who
/// has not memorised the options. The same chip is used on the command line and
/// on the canvas HUD so a click means the same thing in both places.
class PromptKeywordChip extends StatefulWidget {
  const PromptKeywordChip({
    super.key,
    required this.label,
    required this.onPressed,
    this.muted = false,
    this.filled = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool muted;

  /// Solid accent fill, for the one action a prompt is asking for.
  final bool filled;

  @override
  State<PromptKeywordChip> createState() => _PromptKeywordChipState();
}

class _PromptKeywordChipState extends State<PromptKeywordChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final accent = widget.muted ? tokens.textMuted : tokens.accent;
    final fill = widget.filled
        ? (_hovered
              ? Color.alphaBlend(
                  Colors.white.withValues(alpha: 0.12),
                  tokens.accent,
                )
              : tokens.accent)
        : (_hovered ? tokens.selection : Colors.transparent);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          padding: const EdgeInsets.symmetric(
            horizontal: FanCadTokens.space2,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(
              color: widget.filled
                  ? tokens.accent
                  : (_hovered ? accent : tokens.borderStrong),
            ),
            borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
          ),
          child: Text(
            widget.label,
            style: tokens.labelStyle.copyWith(
              color: widget.filled
                  ? tokens.accentText
                  : (_hovered ? accent : tokens.text),
            ),
          ),
        ),
      ),
    );
  }
}
