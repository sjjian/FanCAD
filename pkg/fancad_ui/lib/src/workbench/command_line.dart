import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/workspace.dart';
import '../theme/tokens.dart';
import 'command_line_model.dart';
import 'shell_widgets.dart';

/// The command line and its history pane.
///
/// This is the component that decides whether the application feels like CAD.
/// Three behaviours carry most of that weight: the history is always visible so
/// prompts are never missed, the input keeps focus so typing a verb always works
/// without clicking first, and Escape always cancels whatever is running.
class CommandLinePane extends StatefulWidget {
  const CommandLinePane({
    super.key,
    required this.workspace,
    required this.height,
    required this.onResize,
    required this.onResizeEnd,
    required this.onToggleExpand,
    required this.isExpanded,
    required this.focusNode,
  });

  final Workspace workspace;
  final double height;
  final void Function(double delta) onResize;
  final VoidCallback onResizeEnd;
  final VoidCallback onToggleExpand;
  final bool isExpanded;

  /// Owned by the workbench so that the canvas can hand focus back here after
  /// a click, which is what keeps typed input working mid-command.
  final FocusNode focusNode;

  @override
  State<CommandLinePane> createState() => _CommandLinePaneState();
}

class _CommandLinePaneState extends State<CommandLinePane> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  CommandLineController get _model => widget.workspace.commandLine;

  @override
  void initState() {
    super.initState();
    _model.addListener(_onModelChanged);
  }

  @override
  void dispose() {
    _model.removeListener(_onModelChanged);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onModelChanged() {
    if (!mounted) return;
    // The newest line is the one the user needs, so the pane follows the tail
    // unless they have scrolled away to read something.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      if (position.maxScrollExtent - position.pixels < 80) {
        _scroll.jumpTo(position.maxScrollExtent);
      }
    });
    setState(() {});
  }

  void _submit(String raw) {
    final remaining = _model.submit(raw);
    _input.clear();
    if (remaining == null) return;
    // Not consumed by a prompt, so it is a command to run. An empty line
    // repeats the previous command, which the workspace handles.
    widget.workspace.submitCommandLine(remaining);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        widget.workspace.cancelActive();
        _input.clear();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        final recalled = _model.recallPrevious();
        if (recalled == null) return KeyEventResult.ignored;
        _setText(recalled);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        final recalled = _model.recallNext();
        if (recalled == null) return KeyEventResult.ignored;
        _setText(recalled);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.space:
        // Empty space finishes a prompt or repeats the last command, which
        // is the AutoCAD muscle memory. Space inside typed text stays a
        // character so aliases like "zoom window" still work.
        if (_input.text.isEmpty) {
          _submit('');
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      default:
        return KeyEventResult.ignored;
    }
  }

  void _setText(String value) {
    _input
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      children: [
        Tooltip(
          message: 'Drag to resize · double-click to '
              '${widget.isExpanded ? 'collapse' : 'expand'}',
          waitDuration: const Duration(milliseconds: 500),
          child: ShellSplitter(
            axis: Axis.horizontal,
            // Dragging the splitter up has to make the pane taller, so the
            // delta is inverted relative to the pointer.
            onDrag: (delta) => widget.onResize(-delta),
            onDragEnd: widget.onResizeEnd,
            onDoubleTap: widget.onToggleExpand,
          ),
        ),
        Expanded(
          child: Container(
            color: tokens.surface,
            child: Column(
              children: [
                Expanded(child: _buildHistory(tokens)),
                _buildInput(tokens),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistory(FanCadTokens tokens) {
    final lines = _model.lines;
    if (lines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FanCadTokens.space3,
          vertical: FanCadTokens.space2,
        ),
        child: Text(
          'Command history will appear here. Click a line to reuse it, '
          'or press ↑ to recall the last thing you typed.',
          style: tokens.labelStyle,
        ),
      );
    }
    return Scrollbar(
      controller: _scroll,
      thickness: 6,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(
          horizontal: FanCadTokens.space2,
          vertical: FanCadTokens.space1,
        ),
        itemCount: lines.length,
        itemExtent: 17,
        itemBuilder: (context, index) {
          final line = lines[index];
          return _HistoryLine(
            line: line,
            tokens: tokens,
            onReuse: () {
              _setText(line.text.trim());
              widget.focusNode.requestFocus();
            },
          );
        },
      ),
    );
  }

  Widget _buildInput(FanCadTokens tokens) {
    final prompt = _model.promptText;
    final keywords = _model.pending?.keywords ?? const <String>[];
    final awaiting = _model.isAwaitingInput;
    return Container(
      height: FanCadTokens.commandLineHeight,
      padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space3),
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        border: Border(
          top: BorderSide(
            color: awaiting ? tokens.accent : tokens.border,
            width: awaiting ? 2 : 1,
          ),
        ),
      ),
      child: Row(
        children: [
          ShellIconButton(
            icon: widget.isExpanded
                ? Icons.expand_more
                : Icons.unfold_more,
            tooltip: widget.isExpanded
                ? 'Collapse command history'
                : 'Expand command history',
            size: 22,
            iconSize: 16,
            isActive: widget.isExpanded,
            onPressed: widget.onToggleExpand,
          ),
          ShellIconButton(
            icon: Icons.copy_outlined,
            tooltip: _model.lines.isEmpty
                ? 'Nothing to copy'
                : 'Copy command history',
            enabled: _model.lines.isNotEmpty,
            size: 22,
            iconSize: 14,
            onPressed: () {
              final text = [
                for (final line in _model.lines) line.text,
              ].join('\n');
              Clipboard.setData(ClipboardData(text: text));
              widget.workspace.notify('Copied command history');
            },
          ),
          ShellIconButton(
            icon: Icons.delete_outline,
            tooltip: _model.lines.isEmpty
                ? 'Nothing to clear'
                : 'Clear command history',
            enabled: _model.lines.isNotEmpty,
            destructive: true,
            size: 22,
            iconSize: 15,
            onPressed: _model.clear,
          ),
          const SizedBox(width: FanCadTokens.space1),
          if (prompt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: FanCadTokens.space2),
              child: Tooltip(
                message: prompt,
                waitDuration: const Duration(milliseconds: 500),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    prompt,
                    style: tokens.monoStyle.copyWith(
                      color: awaiting ? tokens.accent : tokens.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Focus(
              onKeyEvent: _onKey,
              child: ShellTextField(
                controller: _input,
                focusNode: widget.focusNode,
                hintText: awaiting
                    ? 'Click in the drawing, or type a value'
                    : prompt.isEmpty
                    ? 'Type a command'
                    : null,
                onSubmitted: _submit,
              ),
            ),
          ),
          for (final keyword in keywords.take(6))
            Padding(
              padding: const EdgeInsets.only(left: FanCadTokens.space1),
              child: PromptKeywordChip(
                label: keyword,
                onPressed: () => _submit(keyword),
              ),
            ),
          if (awaiting || widget.workspace.isBusy)
            Padding(
              padding: const EdgeInsets.only(left: FanCadTokens.space1),
              child: PromptKeywordChip(
                label: 'Cancel',
                muted: true,
                onPressed: () {
                  widget.workspace.cancelActive();
                  _input.clear();
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// The status bar: coordinates, drafting toggles and scene statistics.
/// One command-history row. A click puts the text back in the input so a
/// previous verb or coordinate does not have to be retyped from memory.
class _HistoryLine extends StatefulWidget {
  const _HistoryLine({
    required this.line,
    required this.tokens,
    required this.onReuse,
  });

  final HistoryLine line;
  final FanCadTokens tokens;
  final VoidCallback onReuse;

  @override
  State<_HistoryLine> createState() => _HistoryLineState();
}

class _HistoryLineState extends State<_HistoryLine> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onReuse,
        child: ColoredBox(
          color: _hovered ? tokens.hover : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FanCadTokens.space1,
            ),
            child: Text(
              widget.line.text,
              style: tokens.monoStyle.copyWith(
                fontSize: 11.5,
                color: switch (widget.line.level) {
                  HistoryLevel.normal => tokens.textMuted,
                  HistoryLevel.prompt => tokens.text,
                  HistoryLevel.success => tokens.success,
                  HistoryLevel.warning => tokens.warning,
                  HistoryLevel.error => tokens.danger,
                },
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tab = workspace.active;
    final snap = workspace.snapEngine;
    final cursor = tab?.tools.cursor;
    final scene = tab?.lastScene;

    return Container(
      height: FanCadTokens.statusBarHeight,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: FanCadTokens.space3),
          SizedBox(
            width: 190,
            child: _CoordinateReadout(workspace: workspace, cursor: cursor),
          ),
          StatusToggle(
            label: 'SNAP',
            isOn: snap.enabled,
            tooltip:
                'Object snapping (F3). Right-click to choose Endpoint, Midpoint…',
            onPressed: () => workspace.setSnapEnabled(!snap.enabled),
            onContextMenu: (position) =>
                _openSnapModeMenu(context, workspace, position),
          ),
          StatusToggle(
            label: 'ORTHO',
            isOn: snap.tracking.ortho,
            tooltip: 'Constrain to horizontal and vertical (F8)',
            onPressed: () => workspace.setOrtho(!snap.tracking.ortho),
          ),
          StatusToggle(
            label: 'POLAR',
            isOn: snap.tracking.polar,
            tooltip:
                'Polar tracking (F10) — ${_polarDegrees(snap.tracking.polarIncrement)}°. '
                'Right-click to change the increment',
            onPressed: () => workspace.setPolar(!snap.tracking.polar),
            onContextMenu: (position) =>
                _openPolarIncrementMenu(context, workspace, position),
          ),
          StatusToggle(
            label: 'GRID',
            isOn: tab?.showGrid ?? false,
            tooltip: 'Reference grid (F7)',
            onPressed: () {
              if (tab != null) workspace.setShowGrid(!tab.showGrid);
            },
          ),
          const Spacer(),
          if (tab != null) ...[
            _StatusAction(
              label: '${tab.selection.length} selected',
              tooltip: tab.selection.isEmpty
                  ? 'Nothing selected'
                  : 'Open properties for the selection',
              enabled: tab.selection.isNotEmpty,
              onPressed: () => workspace.revealPanel('properties'),
            ),
            _StatusAction(
              label: '${tab.document.entityCount} objects',
              tooltip: tab.document.entityCount == 0
                  ? 'The drawing is empty'
                  : 'Select every object',
              enabled: tab.document.entityCount > 0,
              onPressed: () => workspace.run('select.all'),
            ),
            _StatusAction(
              label:
                  '1:${(1 / tab.viewport.viewport.scale).toStringAsFixed(2)}',
              tooltip: 'Zoom extents — fit the drawing in the window',
              onPressed: () => workspace.run('view.zoomExtents'),
            ),
            if (scene != null)
              Tooltip(
                message: 'Batches drawn / entities visible in the viewport',
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FanCadTokens.space2,
                  ),
                  child: Text(
                    '${scene.drawCallCount} draw calls · ${scene.entityCount} visible',
                    style: tokens.labelStyle,
                  ),
                ),
              ),
          ],
          const SizedBox(width: FanCadTokens.space3),
          _CurrentLayerIndicator(workspace: workspace),
          const SizedBox(width: FanCadTokens.space3),
        ],
      ),
    );
  }
}

Future<void> _openSnapModeMenu(
  BuildContext context,
  Workspace workspace,
  Offset globalPosition,
) async {
  final tokens = context.tokens;
  final chosen = await showMenu<Object>(
    context: context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      globalPosition.dx,
      globalPosition.dy,
    ),
    color: tokens.surfaceOverlay,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FanCadTokens.radius),
      side: BorderSide(color: tokens.borderStrong),
    ),
    items: [
      for (final mode in SnapMode.values)
        PopupMenuItem<Object>(
          value: mode,
          height: 32,
          child: Row(
            children: [
              SizedBox(
                width: 18,
                child: workspace.snapEngine.modes.contains(mode)
                    ? Icon(Icons.check, size: 14, color: tokens.accent)
                    : null,
              ),
              const SizedBox(width: FanCadTokens.space2),
              Text(mode.label, style: tokens.bodyStyle),
            ],
          ),
        ),
      const PopupMenuDivider(),
      PopupMenuItem<Object>(
        value: 'defaults',
        height: 32,
        child: Text('Restore defaults', style: tokens.bodyStyle),
      ),
    ],
  );
  if (chosen is SnapMode) {
    workspace.toggleSnapMode(chosen);
  } else if (chosen == 'defaults') {
    workspace.resetSnapModes();
  }
}

const _polarIncrements = [5, 15, 30, 45, 90];

int _polarDegrees(double radians) =>
    (radians * 180 / math.pi).round();

Future<void> _openPolarIncrementMenu(
  BuildContext context,
  Workspace workspace,
  Offset globalPosition,
) async {
  final tokens = context.tokens;
  final current = _polarDegrees(workspace.snapEngine.tracking.polarIncrement);
  final chosen = await showMenu<int>(
    context: context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      globalPosition.dx,
      globalPosition.dy,
    ),
    color: tokens.surfaceOverlay,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FanCadTokens.radius),
      side: BorderSide(color: tokens.borderStrong),
    ),
    items: [
      for (final degrees in _polarIncrements)
        PopupMenuItem<int>(
          value: degrees,
          height: 32,
          child: Row(
            children: [
              SizedBox(
                width: 18,
                child: degrees == current
                    ? Icon(Icons.check, size: 14, color: tokens.accent)
                    : null,
              ),
              const SizedBox(width: FanCadTokens.space2),
              Text('$degrees°', style: tokens.bodyStyle),
            ],
          ),
        ),
    ],
  );
  if (chosen == null) return;
  workspace.setPolarIncrement(chosen * math.pi / 180);
}

class _CurrentLayerIndicator extends StatefulWidget {
  const _CurrentLayerIndicator({required this.workspace});

  final Workspace workspace;

  @override
  State<_CurrentLayerIndicator> createState() => _CurrentLayerIndicatorState();
}

class _CurrentLayerIndicatorState extends State<_CurrentLayerIndicator> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tab = widget.workspace.active;
    if (tab == null) return const SizedBox.shrink();
    final name = tab.document.currentLayer;
    final layer = tab.document.layer(name);
    final hidden = layer != null && !layer.isEffectivelyVisible;
    final locked = layer?.locked ?? false;
    final states = [
      if (hidden) 'hidden',
      if (locked) 'locked',
    ];
    return Tooltip(
      message: [
        'Current layer "$name"${states.isEmpty ? '' : ' (${states.join(', ')})'}',
        'Click to manage layers. Right-click to turn on or unlock',
      ].join('\n'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => widget.workspace.revealPanel('layers'),
          onSecondaryTapDown: (details) =>
              _openMenu(details.globalPosition, name, hidden, locked),
          child: Container(
            height: FanCadTokens.statusBarHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: FanCadTokens.space2,
            ),
            color: _hovered ? tokens.hover : Colors.transparent,
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: layer == null
                        ? tokens.textFaint
                        : (tokens.isDark ? AciPalette.dark : AciPalette.light)
                              .colorOf(layer.color),
                    border: Border.all(color: tokens.border),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: FanCadTokens.space2),
                Text(
                  name,
                  style: tokens.labelStyle.copyWith(color: tokens.text),
                ),
                if (hidden) ...[
                  const SizedBox(width: FanCadTokens.space1),
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 11,
                    color: tokens.textFaint,
                  ),
                ],
                if (locked) ...[
                  const SizedBox(width: FanCadTokens.space1),
                  Icon(
                    Icons.lock_outline,
                    size: 11,
                    color: tokens.textFaint,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMenu(
    Offset globalPosition,
    String name,
    bool hidden,
    bool locked,
  ) async {
    final tokens = context.tokens;
    final workspace = widget.workspace;
    final chosen = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      color: tokens.surfaceOverlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FanCadTokens.radius),
        side: BorderSide(color: tokens.borderStrong),
      ),
      items: [
        PopupMenuItem(
          value: 'visible',
          height: 32,
          child: Text(
            hidden ? 'Turn layer on' : 'Turn layer off',
            style: tokens.bodyStyle,
          ),
        ),
        PopupMenuItem(
          value: 'lock',
          height: 32,
          child: Text(
            locked ? 'Unlock layer' : 'Lock layer',
            style: tokens.bodyStyle,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'manage',
          height: 32,
          child: Text('Manage layers', style: tokens.bodyStyle),
        ),
      ],
    );
    if (chosen == null) return;
    switch (chosen) {
      case 'visible':
        await workspace.run('layer.toggleVisible', args: {'name': name});
      case 'lock':
        await workspace.run('layer.toggleLock', args: {'name': name});
      case 'manage':
        workspace.revealPanel('layers');
    }
  }
}

/// A status-bar count that does something, so it looks like SNAP rather than
/// a dead label someone only discovers by accident.
class _StatusAction extends StatefulWidget {
  const _StatusAction({
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  State<_StatusAction> createState() => _StatusActionState();
}

class _StatusActionState extends State<_StatusAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.enabled ? widget.onPressed : null,
          child: Container(
            height: FanCadTokens.statusBarHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: FanCadTokens.space2,
            ),
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
      ),
    );
  }
}

/// The live cursor. A click copies it, or feeds it to a command that is
/// already asking for a point — so a measured XY does not have to be retyped.
class _CoordinateReadout extends StatefulWidget {
  const _CoordinateReadout({
    required this.workspace,
    required this.cursor,
  });

  final Workspace workspace;
  final Vec2? cursor;

  @override
  State<_CoordinateReadout> createState() => _CoordinateReadoutState();
}

class _CoordinateReadoutState extends State<_CoordinateReadout> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final cursor = widget.cursor;
    final text = cursor == null
        ? null
        : '${cursor.x.toStringAsFixed(3)}, ${cursor.y.toStringAsFixed(3)}';
    final awaiting = widget.workspace.commandLine.isAwaitingInput;
    final enabled = text != null;
    return Tooltip(
      message: text == null
          ? 'Cursor'
          : awaiting
          ? 'Use $text as the next point'
          : 'Copy $text',
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: enabled ? () => _activate(text) : null,
          child: Container(
            height: FanCadTokens.statusBarHeight,
            alignment: Alignment.centerLeft,
            color: enabled && _hovered ? tokens.hover : Colors.transparent,
            child: Text(
              text ?? '—',
              style: tokens.monoStyle.copyWith(
                fontSize: 11,
                color: awaiting && enabled ? tokens.accent : tokens.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _activate(String text) {
    final workspace = widget.workspace;
    if (workspace.commandLine.isAwaitingInput) {
      final remaining = workspace.commandLine.submit(text);
      if (remaining != null) workspace.submitCommandLine(remaining);
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    workspace.notify('Copied $text');
  }
}
