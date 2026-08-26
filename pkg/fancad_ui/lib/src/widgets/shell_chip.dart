import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A clickable keyword offered by the current command prompt.
///
/// A prompt that can only be answered by typing is a dead end for anyone who
/// has not memorised the options. The same chip is used on the command line and
/// on the canvas HUD so a click means the same thing in both places.
class PromptKeywordChip extends StatefulWidget {
  const PromptKeywordChip({
    required this.label,
    required this.onPressed,
    this.muted = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool muted;

  @override
  State<PromptKeywordChip> createState() => _PromptKeywordChipState();
}

class _PromptKeywordChipState extends State<PromptKeywordChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final accent = widget.muted ? tokens.textMuted : tokens.accent;
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
            color: _hovered ? tokens.selection : Colors.transparent,
            border: Border.all(color: _hovered ? accent : tokens.borderStrong),
            borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
          ),
          child: Text(
            widget.label,
            style: tokens.labelStyle.copyWith(
              color: _hovered ? accent : tokens.text,
            ),
          ),
        ),
      ),
    );
  }
}
