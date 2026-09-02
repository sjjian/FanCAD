import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A flat square icon button, as used in the activity bar and tab strip.
class ShellIconButton extends StatefulWidget {
  const ShellIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.isActive = false,
    this.size = 28,
    this.iconSize = FanCadTokens.iconMedium,
    this.showActiveBar = false,
    this.enabled = true,
    this.destructive = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isActive;
  final double size;
  final double iconSize;

  /// Activity-bar item: a quiet rounded chip instead of an accent rail.
  final bool showActiveBar;
  final bool enabled;

  /// Window-close and similar actions: hover tints the icon with [FanCadTokens.danger].
  final bool destructive;

  @override
  State<ShellIconButton> createState() => _ShellIconButtonState();
}

class _ShellIconButtonState extends State<ShellIconButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final enabled = widget.enabled && widget.onPressed != null;
    final color = !enabled
        ? tokens.disabled
        : widget.destructive && _hovered
        ? tokens.danger
        : widget.isActive
        ? tokens.text
        : tokens.textMuted;
    final fill = !enabled
        ? Colors.transparent
        : widget.destructive && _hovered
        ? tokens.danger.withValues(alpha: tokens.isDark ? 0.16 : 0.12)
        : widget.isActive && widget.showActiveBar
        ? tokens.pressed
        : _hovered
        ? tokens.hover
        : Colors.transparent;

    Widget button = FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onShowHoverHighlight: (show) => setState(() => _hovered = show),
      onShowFocusHighlight: (show) => setState(() => _focused = show),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(
              widget.showActiveBar
                  ? FanCadTokens.radius
                  : FanCadTokens.radiusSmall,
            ),
            border: _focused
                ? Border.all(color: tokens.focusRing, width: 2)
                : null,
          ),
          child: Center(
            child: Icon(widget.icon, size: widget.iconSize, color: color),
          ),
        ),
      ),
    );

    final tooltip = widget.tooltip;
    if (tooltip != null && tooltip.isNotEmpty) {
      button = Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 500),
        child: button,
      );
    }
    return button;
  }
}
