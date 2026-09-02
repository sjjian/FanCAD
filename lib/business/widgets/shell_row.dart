import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A dense selectable row, the building block of every panel list.
class ShellRow extends StatefulWidget {
  const ShellRow({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onSecondaryTap,
    this.isSelected = false,
    this.height = FanCadTokens.rowHeight,
    this.padding = const EdgeInsets.symmetric(horizontal: FanCadTokens.space2),
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onSecondaryTap;
  final bool isSelected;
  final double height;
  final EdgeInsets padding;

  @override
  State<ShellRow> createState() => _ShellRowState();
}

class _ShellRowState extends State<ShellRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tappable = widget.onTap != null;
    return FocusableActionDetector(
      enabled: tappable,
      mouseCursor: tappable
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onShowHoverHighlight: (show) => setState(() => _hovered = show),
      onShowFocusHighlight: (show) => setState(() => _focused = show),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onSecondaryTap: widget.onSecondaryTap,
        child: Container(
          height: widget.height,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? tokens.selection
                : _hovered
                ? tokens.hover
                : Colors.transparent,
            border: _focused
                ? Border.all(color: tokens.focusRing, width: 2)
                : null,
          ),
          alignment: Alignment.centerLeft,
          child: widget.child,
        ),
      ),
    );
  }
}
