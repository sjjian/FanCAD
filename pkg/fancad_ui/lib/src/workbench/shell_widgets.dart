import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme/tokens.dart';

/// A modifier-aware shortcut label for chrome that mentions keystrokes.
String shellShortcut(String key, {bool shift = false}) {
  final prefix = Platform.isMacOS ? '⌘' : 'Ctrl';
  return shift ? '$prefix Shift $key' : '$prefix $key';
}

/// The small widgets the shell is assembled from.
///
/// Gathered in one file because they are only meaningful together: a CAD shell
/// is a dense grid of 24-pixel rows, and keeping the row, the icon button and
/// the splitter side by side is what stops them drifting out of alignment.

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

  /// Draws the accent bar an activity-bar item uses to show which view is open.
  final bool showActiveBar;
  final bool enabled;

  /// Window-close and similar actions: hover tints the icon with [FanCadTokens.danger].
  final bool destructive;

  @override
  State<ShellIconButton> createState() => _ShellIconButtonState();
}

class _ShellIconButtonState extends State<ShellIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final enabled = widget.enabled && widget.onPressed != null;
    final color = !enabled
        ? tokens.textFaint
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
        ? (_hovered ? tokens.pressed : tokens.selection)
        : _hovered
        ? tokens.hover
        : Colors.transparent;

    Widget button = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(widget.icon, size: widget.iconSize, color: color),
              ),
              if (widget.showActiveBar && widget.isActive)
                Positioned(
                  left: 0,
                  top: 4,
                  bottom: 4,
                  child: Container(width: 2, color: tokens.accent),
                ),
            ],
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
    this.padding = const EdgeInsets.symmetric(
      horizontal: FanCadTokens.space2,
    ),
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

/// A draggable divider between two regions.
///
/// The hit area is deliberately wider than the visible line: a one-pixel target
/// is technically a splitter and practically a source of complaint.
class ShellSplitter extends StatefulWidget {
  const ShellSplitter({
    super.key,
    required this.axis,
    required this.onDrag,
    this.onDragEnd,
    this.onDoubleTap,
    this.thickness = 1,
    this.hitSize = FanCadTokens.splitterHit,
    this.strong = false,
  });

  /// The axis the splitter runs along; a vertical splitter resizes horizontally.
  final Axis axis;

  final void Function(double delta) onDrag;
  final VoidCallback? onDragEnd;

  /// A double-click snaps the pane to a remembered large or small size.
  final VoidCallback? onDoubleTap;
  final double thickness;
  final double hitSize;

  /// A harder rule, used where two similar surfaces would otherwise merge.
  final bool strong;

  @override
  State<ShellSplitter> createState() => _ShellSplitterState();
}

class _ShellSplitterState extends State<ShellSplitter> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isVertical = widget.axis == Axis.vertical;
    return MouseRegion(
      cursor: isVertical
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _active = true),
      onExit: (_) => setState(() => _active = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onDoubleTap,
        onHorizontalDragUpdate: isVertical
            ? (details) => widget.onDrag(details.delta.dx)
            : null,
        onHorizontalDragEnd: isVertical
            ? (_) => widget.onDragEnd?.call()
            : null,
        onVerticalDragUpdate: isVertical
            ? null
            : (details) => widget.onDrag(details.delta.dy),
        onVerticalDragEnd: isVertical
            ? null
            : (_) => widget.onDragEnd?.call(),
        child: SizedBox(
          width: isVertical ? widget.hitSize : null,
          height: isVertical ? null : widget.hitSize,
          child: Center(
            child: Container(
              width: isVertical ? widget.thickness : double.infinity,
              height: isVertical ? double.infinity : widget.thickness,
              color: _active
                  ? tokens.accent
                  : widget.strong
                  ? tokens.borderStrong
                  : tokens.border,
            ),
          ),
        ),
      ),
    );
  }
}

/// The header above a panel's contents.
class PanelHeader extends StatelessWidget {
  const PanelHeader({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      height: FanCadTokens.tabBarHeight,
      padding: const EdgeInsets.only(
        left: FanCadTokens.space3,
        right: FanCadTokens.space1,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: tokens.sectionTitleStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// A labelled section inside a panel.
class PanelSection extends StatelessWidget {
  const PanelSection({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: FanCadTokens.space3,
            right: FanCadTokens.space2,
            top: FanCadTokens.space3,
            bottom: FanCadTokens.space1,
          ),
          child: Row(
            children: [
              Expanded(child: Text(title, style: tokens.sectionTitleStyle)),
              ?trailing,
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

/// A name and value on one line, as the properties panel uses.
class PropertyRow extends StatelessWidget {
  const PropertyRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.isEditable = false,
    this.copyText,
    this.onCopied,
  });

  final String label;
  final Widget value;
  final VoidCallback? onTap;
  final bool isEditable;

  /// Copied on right-click, or on a left-click when the row is not editable.
  final String? copyText;
  final ValueChanged<String>? onCopied;

  void _copy(BuildContext context) {
    final text = copyText;
    if (text == null || text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    onCopied?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tooltip = onTap != null
        ? context.l10n.click_to_change(label)
        : copyText != null
        ? context.l10n.click_to_copy_label(label)
        : null;
    Widget row = ShellRow(
      onTap: onTap ?? (copyText == null ? null : () => _copy(context)),
      onSecondaryTap: copyText == null ? null : () => _copy(context),
      height: FanCadTokens.rowHeight,
      padding: const EdgeInsets.only(left: FanCadTokens.space3, right: 4),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: tokens.labelStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: DefaultTextStyle(
              style: tokens.monoStyle.copyWith(
                color: isEditable ? tokens.text : tokens.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              child: value,
            ),
          ),
          if (isEditable)
            Icon(
              Icons.chevron_right,
              size: FanCadTokens.iconSmall,
              color: tokens.textFaint,
            ),
        ],
      ),
    );
    if (tooltip == null) return row;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: row,
    );
  }
}

/// A compact toggle used in the status bar for ortho, snap and grid.
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
          padding: const EdgeInsets.symmetric(
            horizontal: FanCadTokens.space2,
          ),
          decoration: BoxDecoration(
            color: widget.isOn
                ? tokens.selection
                : _hovered
                ? tokens.hover
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: widget.isOn ? tokens.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: tokens.labelStyle.copyWith(
              color: widget.isOn ? tokens.accent : tokens.textFaint,
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
            border: Border.all(
              color: _hovered ? accent : tokens.borderStrong,
            ),
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

/// The empty state shown when no drawing is open.
class EmptyWorkspace extends StatelessWidget {
  const EmptyWorkspace({
    super.key,
    required this.recentFiles,
    required this.onOpenRecent,
    required this.onOpen,
    required this.onNew,
    required this.onShowCommands,
  });

  final List<String> recentFiles;
  final ValueChanged<String> onOpenRecent;
  final VoidCallback onOpen;
  final VoidCallback onNew;
  final VoidCallback onShowCommands;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      color: tokens.canvas,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FanCadTokens.space5,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: tokens.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: FanCadTokens.space3),
                Text(
                  'FanCAD',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 4,
                    color: tokens.text,
                  ),
                ),
                const SizedBox(height: FanCadTokens.space1),
                Text(
                  context.l10n.empty_tagline,
                  style: tokens.labelStyle.copyWith(fontSize: 13),
                ),
                const SizedBox(height: FanCadTokens.space5),
                _Action(
                  label: context.l10n.new_drawing,
                  shortcut: shellShortcut('N'),
                  onPressed: onNew,
                ),
                _Action(
                  label: context.l10n.open_drawing_file,
                  shortcut: shellShortcut('O'),
                  onPressed: onOpen,
                ),
                _Action(
                  label: context.l10n.show_all_commands,
                  shortcut: shellShortcut('P', shift: true),
                  onPressed: onShowCommands,
                ),
                if (recentFiles.isNotEmpty) ...[
                  const SizedBox(height: FanCadTokens.space5),
                  Text(context.l10n.recent.toUpperCase(), style: tokens.sectionTitleStyle),
                  const SizedBox(height: FanCadTokens.space2),
                  for (final path in recentFiles.take(8))
                    _Recent(path: path, onPressed: () => onOpenRecent(path)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.shortcut,
    required this.onPressed,
  });

  final String label;
  final String shortcut;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ShellRow(
      onTap: onPressed,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space1),
      child: Row(
        children: [
          Text(
            label,
            style: tokens.bodyStyle.copyWith(color: tokens.accent),
          ),
          const Spacer(),
          Text(shortcut, style: tokens.labelStyle),
        ],
      ),
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.path, required this.onPressed});

  final String path;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final separator = path.contains(r'\') ? r'\' : '/';
    final parts = path.split(separator);
    final name = parts.isEmpty ? path : parts.last;
    final folder = parts.length > 1
        ? parts.sublist(0, parts.length - 1).join(separator)
        : '';
    final missing = !File(path).existsSync();
    final l10n = context.l10n;
    return Tooltip(
      message: missing ? l10n.missing_path(path) : path,
      waitDuration: const Duration(milliseconds: 400),
      child: ShellRow(
        onTap: onPressed,
        onSecondaryTap: missing ? null : () => _revealOnDisk(path),
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space1),
        child: Row(
          children: [
            Icon(
              missing
                  ? Icons.broken_image_outlined
                  : Icons.insert_drive_file_outlined,
              size: FanCadTokens.iconMedium,
              color: missing ? tokens.textFaint : tokens.textMuted,
            ),
            const SizedBox(width: FanCadTokens.space2),
            Text(
              name,
              style: tokens.bodyStyle.copyWith(
                color: missing ? tokens.textFaint : tokens.accent,
                decoration: missing ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(width: FanCadTokens.space2),
            Expanded(
              child: Text(
                missing ? l10n.missing_folder(folder) : folder,
                style: tokens.labelStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!missing)
              ShellIconButton(
                icon: Icons.folder_open_outlined,
                size: 20,
                iconSize: FanCadTokens.iconSmall,
                tooltip: l10n.revealInFolder(),
                onPressed: () => _revealOnDisk(path),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _revealOnDisk(String path) async {
  try {
    if (Platform.isMacOS) {
      await Process.start('open', ['-R', path]);
    } else if (Platform.isWindows) {
      await Process.start('explorer', ['/select,', path]);
    } else {
      await Process.start('xdg-open', [File(path).parent.path]);
    }
  } catch (_) {}
}
