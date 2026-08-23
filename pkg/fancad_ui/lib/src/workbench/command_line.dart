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
    required this.focusNode,
  });

  final Workspace workspace;
  final double height;
  final void Function(double delta) onResize;
  final VoidCallback onResizeEnd;

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
        ShellSplitter(
          axis: Axis.horizontal,
          // Dragging the splitter up has to make the pane taller, so the
          // delta is inverted relative to the pointer.
          onDrag: (delta) => widget.onResize(-delta),
          onDragEnd: widget.onResizeEnd,
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
    return Scrollbar(
      controller: _scroll,
      thickness: 6,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(
          horizontal: FanCadTokens.space3,
          vertical: FanCadTokens.space1,
        ),
        itemCount: lines.length,
        itemExtent: 17,
        itemBuilder: (context, index) {
          final line = lines[index];
          return Text(
            line.text,
            style: tokens.monoStyle.copyWith(
              fontSize: 11.5,
              color: switch (line.level) {
                HistoryLevel.normal => tokens.textMuted,
                HistoryLevel.prompt => tokens.text,
                HistoryLevel.success => tokens.success,
                HistoryLevel.warning => tokens.warning,
                HistoryLevel.error => tokens.danger,
              },
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
            child: _CoordinateReadout(
              cursor: cursor,
              tokens: tokens,
              onCopy: (text) => workspace.notify('Copied $text'),
            ),
          ),
          StatusToggle(
            label: 'SNAP',
            isOn: snap.enabled,
            tooltip: 'Object snapping (F3)',
            onPressed: () => workspace.setSnapEnabled(!snap.enabled),
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
            tooltip: 'Polar angle tracking (F10)',
            onPressed: () => workspace.setPolar(!snap.tracking.polar),
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
            Tooltip(
              message: tab.selection.isEmpty
                  ? 'Nothing selected'
                  : 'Inspect properties',
              child: InkWell(
                onTap: tab.selection.isEmpty
                    ? null
                    : () => workspace.revealPanel('properties'),
                child: Text(
                  '${tab.selection.length} selected',
                  style: tokens.labelStyle.copyWith(
                    color: tab.selection.isEmpty
                        ? tokens.textMuted
                        : tokens.text,
                  ),
                ),
              ),
            ),
            const SizedBox(width: FanCadTokens.space4),
            Tooltip(
              message: 'Select all',
              child: InkWell(
                onTap: tab.document.entityCount == 0
                    ? null
                    : () => workspace.run('select.all'),
                child: Text(
                  '${tab.document.entityCount} objects',
                  style: tokens.labelStyle,
                ),
              ),
            ),
            const SizedBox(width: FanCadTokens.space4),
            // The zoom and draw-call readout is here because it is the fastest
            // way to tell a slow drawing from a slow renderer.
            Tooltip(
              message: 'Zoom extents',
              child: InkWell(
                onTap: () => workspace.run('view.zoomExtents'),
                child: Text(
                  '1:${(1 / tab.viewport.viewport.scale).toStringAsFixed(2)}',
                  style: tokens.labelStyle,
                ),
              ),
            ),
            if (scene != null) ...[
              const SizedBox(width: FanCadTokens.space4),
              Tooltip(
                message: 'Batches drawn / entities visible in the viewport',
                child: Text(
                  '${scene.drawCallCount} draw calls · ${scene.entityCount} visible',
                  style: tokens.labelStyle,
                ),
              ),
            ],
          ],
          const SizedBox(width: FanCadTokens.space3),
          _CurrentLayerIndicator(workspace: workspace),
          const SizedBox(width: FanCadTokens.space3),
        ],
      ),
    );
  }
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
        'Click to manage layers',
      ].join('\n'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => widget.workspace.revealPanel('layers'),
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
}

/// The live cursor, clickable so a measured point can leave the window.
class _CoordinateReadout extends StatelessWidget {
  const _CoordinateReadout({
    required this.cursor,
    required this.tokens,
    required this.onCopy,
  });

  final Vec2? cursor;
  final FanCadTokens tokens;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final text = cursor == null
        ? null
        : '${cursor!.x.toStringAsFixed(3)}, ${cursor!.y.toStringAsFixed(3)}';
    return Tooltip(
      message: text == null ? 'Cursor' : 'Copy $text',
      child: InkWell(
        onTap: text == null
            ? null
            : () {
                Clipboard.setData(ClipboardData(text: text));
                onCopy(text);
              },
        child: Text(
          text ?? '—',
          style: tokens.monoStyle.copyWith(
            fontSize: 11,
            color: tokens.textMuted,
          ),
        ),
      ),
    );
  }
}
