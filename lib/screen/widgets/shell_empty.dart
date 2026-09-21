import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A panel-centered empty state. Optional action is a leftover accent row.
class ShellEmpty extends StatelessWidget {
  const ShellEmpty({
    super.key,
    required this.message,
    this.detail,
    this.actionLabel,
    this.onAction,
    this.messageStyle,
  });

  final String message;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;
  final TextStyle? messageStyle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FanCadTokens.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style:
                  messageStyle ??
                  tokens.bodyStyle.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if (detail != null) ...[
              const SizedBox(height: FanCadTokens.space2),
              Text(
                detail!,
                style: tokens.labelStyle,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: FanCadTokens.space3),
              _EmptyAction(label: actionLabel!, onPressed: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shrink-wrapped so a short label stays under the centered copy instead of
/// stretching into a left-aligned list row.
class _EmptyAction extends StatefulWidget {
  const _EmptyAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_EmptyAction> createState() => _EmptyActionState();
}

class _EmptyActionState extends State<_EmptyAction> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (show) => setState(() => _hovered = show),
      onShowFocusHighlight: (show) => setState(() => _focused = show),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _hovered ? tokens.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
            border: _focused
                ? Border.all(color: tokens.focusRing, width: 2)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FanCadTokens.space2,
              vertical: FanCadTokens.space1,
            ),
            child: Text(
              widget.label,
              style: tokens.bodyStyle.copyWith(color: tokens.accent),
            ),
          ),
        ),
      ),
    );
  }
}
