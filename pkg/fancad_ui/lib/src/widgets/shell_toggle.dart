import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A compact drafting-mode toggle.
///
/// On is a slightly darker grey wash and the same ink as the rest of the
/// card — leftover accent text made a drafting mode look like a link.
class StatusToggle extends StatefulWidget {
  const StatusToggle({
    super.key,
    required this.label,
    required this.isOn,
    required this.onPressed,
    this.onContextMenu,
    this.tooltip,
  });

  final String label;
  final bool isOn;
  final VoidCallback onPressed;

  /// Right-click, for choosing which SNAP modes are live.
  final void Function(Offset globalPosition)? onContextMenu;
  final String? tooltip;

  @override
  State<StatusToggle> createState() => _StatusToggleState();
}

class _StatusToggleState extends State<StatusToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    Widget child = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        onSecondaryTapDown: widget.onContextMenu == null
            ? null
            : (details) => widget.onContextMenu!(details.globalPosition),
        child: Container(
          height: FanCadTokens.statusBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space2),
          decoration: BoxDecoration(
            color: widget.isOn
                ? tokens.pressed
                : _hovered
                ? tokens.hover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: tokens.labelStyle.copyWith(
              color: widget.isOn ? tokens.text : tokens.textFaint,
              fontWeight: widget.isOn ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
    final tooltip = widget.tooltip;
    if (tooltip != null) {
      child = Tooltip(message: tooltip, child: child);
    }
    return child;
  }
}

/// A status-bar count that does something, so it looks like SNAP rather than
/// a dead label someone only discovers by accident.
class ShellTextButton extends StatefulWidget {
  const ShellTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool enabled;

  @override
  State<ShellTextButton> createState() => _ShellTextButtonState();
}

class _ShellTextButtonState extends State<ShellTextButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    Widget child = MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onPressed : null,
        child: Container(
          height: FanCadTokens.statusBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space2),
          color: widget.enabled && _hovered
              ? tokens.hover
              : Colors.transparent,
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: tokens.labelStyle.copyWith(
              color: widget.enabled ? tokens.text : tokens.textMuted,
            ),
          ),
        ),
      ),
    );
    final tooltip = widget.tooltip;
    if (tooltip != null) {
      child = Tooltip(message: tooltip, child: child);
    }
    return child;
  }
}
