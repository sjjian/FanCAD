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

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onSecondaryTap: widget.onSecondaryTap,
        child: Container(
          height: widget.height,
          padding: widget.padding,
          color: widget.isSelected
              ? tokens.selection
              : _hovered
              ? tokens.hover
              : Colors.transparent,
          alignment: Alignment.centerLeft,
          child: widget.child,
        ),
      ),
    );
  }
}
