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
        // Space finishes a selection prompt, matching AutoCAD, but only when
        // the user has not started typing a value.
        if (_input.text.isEmpty && _model.isAwaitingInput) {
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
    return Container(
      height: FanCadTokens.commandLineHeight,
      padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space3),
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          if (prompt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: FanCadTokens.space2),
              child: Text(
                prompt,
                style: tokens.monoStyle.copyWith(
                  color: _model.isAwaitingInput
                      ? tokens.accent
                      : tokens.textMuted,
                ),
              ),
            ),
          Expanded(
            child: Focus(
              onKeyEvent: _onKey,
              child: ShellTextField(
                controller: _input,
                focusNode: widget.focusNode,
                hintText: prompt.isEmpty ? 'Type a command' : null,
                onSubmitted: _submit,
              ),
            ),
          ),
          for (final keyword in keywords.take(6))
            Padding(
              padding: const EdgeInsets.only(left: FanCadTokens.space1),
              child: _Keyword(
                label: keyword,
                onPressed: () => _submit(keyword),
              ),
            ),
        ],
      ),
    );
  }
}

/// A clickable keyword option offered by the current prompt.
///
/// Present because a keyword prompt that can only be answered by typing is a
/// discoverability dead end for anyone who has not memorised the options.
class _Keyword extends StatelessWidget {
  const _Keyword({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: FanCadTokens.space2,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: tokens.borderStrong),
            borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
          ),
          child: Text(
            label,
            style: tokens.labelStyle.copyWith(color: tokens.text),
          ),
        ),
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
            child: Text(
              cursor == null
                  ? '—'
                  : '${cursor.x.toStringAsFixed(3)}, '
                        '${cursor.y.toStringAsFixed(3)}',
              style: tokens.monoStyle.copyWith(
                fontSize: 11,
                color: tokens.textMuted,
              ),
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
            onPressed: () => tab?.setShowGrid(!tab.showGrid),
          ),
          const Spacer(),
          if (tab != null) ...[
            Text('${tab.selection.length} selected', style: tokens.labelStyle),
            const SizedBox(width: FanCadTokens.space4),
            Text(
              '${tab.document.entityCount} objects',
              style: tokens.labelStyle,
            ),
            const SizedBox(width: FanCadTokens.space4),
            // The zoom and draw-call readout is here because it is the fastest
            // way to tell a slow drawing from a slow renderer.
            Text(
              '1:${(1 / tab.viewport.viewport.scale).toStringAsFixed(2)}',
              style: tokens.labelStyle,
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

class _CurrentLayerIndicator extends StatelessWidget {
  const _CurrentLayerIndicator({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tab = workspace.active;
    if (tab == null) return const SizedBox.shrink();
    final name = tab.document.currentLayer;
    final layer = tab.document.layer(name);
    return Tooltip(
      message: 'Current layer',
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
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: FanCadTokens.space2),
          Text(name, style: tokens.labelStyle.copyWith(color: tokens.text)),
        ],
      ),
    );
  }
}
