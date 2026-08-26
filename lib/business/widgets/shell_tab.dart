import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// How a [ShellTab] paints its selected and hover chrome.
enum ShellTabStyle {
  /// Document and assistant session tabs: top accent, right hairline.
  strip,

  /// A full-width list row, as used for layout names.
  row,

  /// Settings navigation: accent ink and a 2px underline.
  underline,
}

/// Shared hover and selected chrome for a tab or nav item.
///
/// The parent still owns the label, close button and leftover keys.
class ShellTab extends StatefulWidget {
  const ShellTab({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.style = ShellTabStyle.strip,
    this.height,
    this.padding,
    this.constraints,
    this.tooltip,
    this.onClose,
    this.onDoubleTap,
    this.onSecondaryTap,
    this.onSecondaryTapDown,
    this.onHoverChanged,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final ShellTabStyle style;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final String? tooltip;
  final VoidCallback? onClose;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onSecondaryTap;
  final void Function(Offset globalPosition)? onSecondaryTapDown;
  final ValueChanged<bool>? onHoverChanged;

  @override
  State<ShellTab> createState() => _ShellTabState();
}

class _ShellTabState extends State<ShellTab> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    widget.onHoverChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final fill = widget.selected
        ? tokens.selection
        : _hovered
        ? tokens.hover
        : Colors.transparent;

    late final Widget painted;
    switch (widget.style) {
      case ShellTabStyle.strip:
        painted = Container(
          constraints: widget.constraints,
          height: widget.height,
          padding:
              widget.padding ??
              const EdgeInsets.only(
                left: FanCadTokens.space3,
                right: FanCadTokens.space1,
              ),
          decoration: BoxDecoration(
            color: fill,
            border: Border(
              right: BorderSide(color: tokens.border),
              top: BorderSide(
                color: widget.selected ? tokens.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: widget.child,
        );
      case ShellTabStyle.row:
        painted = Container(
          constraints: widget.constraints,
          height: widget.height ?? FanCadTokens.tabBarHeight,
          padding:
              widget.padding ??
              const EdgeInsets.symmetric(horizontal: FanCadTokens.space3),
          color: fill,
          child: widget.child,
        );
      case ShellTabStyle.underline:
        painted = Padding(
          padding:
              widget.padding ?? const EdgeInsets.only(top: FanCadTokens.space1),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.child,
                const SizedBox(height: 6),
                ColoredBox(
                  color: widget.selected ? tokens.accent : Colors.transparent,
                  child: const SizedBox(height: 2),
                ),
              ],
            ),
          ),
        );
    }

    Widget tab = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onTertiaryTapUp: widget.onClose == null
            ? null
            : (_) => widget.onClose!(),
        onSecondaryTap: widget.onSecondaryTap,
        onSecondaryTapDown: widget.onSecondaryTapDown == null
            ? null
            : (details) => widget.onSecondaryTapDown!(details.globalPosition),
        child: painted,
      ),
    );
    final tooltip = widget.tooltip;
    if (tooltip != null && tooltip.isNotEmpty) {
      tab = Tooltip(message: tooltip, child: tab);
    }
    return tab;
  }
}
