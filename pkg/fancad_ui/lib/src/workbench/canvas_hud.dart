import 'dart:math' as math;

import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../state/document_tab.dart';
import '../state/workspace.dart';
import '../theme/tokens.dart';
import 'command_line.dart';
import 'layout_bar.dart';
import 'shell_widgets.dart';

/// Drawing chrome that lives on the canvas, not in the window chrome.
///
/// Tools, the command line, layout tabs and drafting modes are things you
/// click while looking at the drawing. Parking them in a sibling row stole
/// canvas pixels; a [Stack] overlay keeps the same hit targets without a
/// reserved strip. Readouts stay on [StatusBar].
class CanvasHud extends StatelessWidget {
  const CanvasHud({
    super.key,
    required this.workspace,
    required this.commandFocus,
    required this.commandHeight,
    required this.isExpanded,
    required this.onResize,
    required this.onResizeEnd,
    required this.onToggleExpand,
  });

  final Workspace workspace;
  final FocusNode commandFocus;
  final double commandHeight;
  final bool isExpanded;
  final void Function(double delta) onResize;
  final VoidCallback onResizeEnd;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const Key('canvas-hud'),
      children: [
        Positioned(
          left: FanCadTokens.space3,
          top: FanCadTokens.space3,
          child: _ToolStrip(workspace: workspace),
        ),
        Positioned(
          left: FanCadTokens.space3,
          right: FanCadTokens.space3,
          bottom: FanCadTokens.space3,
          child: _CommandDock(
            workspace: workspace,
            commandFocus: commandFocus,
            commandHeight: commandHeight,
            isExpanded: isExpanded,
            onResize: onResize,
            onResizeEnd: onResizeEnd,
            onToggleExpand: onToggleExpand,
          ),
        ),
      ],
    );
  }
}

class _HudCard extends StatelessWidget {
  const _HudCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: tokens.surfaceOverlay,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(FanCadTokens.radius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FanCadTokens.radius),
          border: Border.all(color: tokens.borderStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _ToolStrip extends StatelessWidget {
  const _ToolStrip({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tab = workspace.active;
    return _HudCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space1),
        child: Row(
          key: const Key('canvas-tool-strip'),
          mainAxisSize: MainAxisSize.min,
          children: [
            ShellIconButton(
              key: const Key('canvas-tool-undo'),
              icon: Icons.undo,
              tooltip: _undoTooltip(l10n, tab),
              enabled: tab?.history.canUndo ?? false,
              onPressed: () => workspace.run('edit.undo'),
            ),
            ShellIconButton(
              key: const Key('canvas-tool-redo'),
              icon: Icons.redo,
              tooltip: _redoTooltip(l10n, tab),
              enabled: tab?.history.canRedo ?? false,
              onPressed: () => workspace.run('edit.redo'),
            ),
            for (final tool in canvasQuickTools)
              ShellIconButton(
                key: Key('canvas-tool-${tool.commandId}'),
                icon: tool.icon,
                tooltip:
                    '${l10n.commandTitle(tool.commandId, tool.fallback)}  ${tool.alias}',
                enabled: tab != null,
                isActive: workspace.runningCommand == tool.commandId,
                onPressed: () => workspace.run(tool.commandId),
              ),
          ],
        ),
      ),
    );
  }
}

/// The drawing verbs that earn a permanent home on the canvas.
@visibleForTesting
const List<({String commandId, IconData icon, String alias, String fallback})>
canvasQuickTools = [
  (
    commandId: 'draw.line',
    icon: Icons.show_chart,
    alias: 'L',
    fallback: 'Line',
  ),
  (
    commandId: 'draw.circle',
    icon: Icons.circle_outlined,
    alias: 'C',
    fallback: 'Circle',
  ),
  (
    commandId: 'edit.move',
    icon: Icons.open_with,
    alias: 'M',
    fallback: 'Move',
  ),
];

String _undoTooltip(AppLocalizations l10n, DocumentTab? tab) {
  final label = tab?.history.nextUndoLabel;
  return label == null
      ? l10n.nothing_to_undo
      : '${l10n.undo_named(label)}  ${shellShortcut('Z')}';
}

String _redoTooltip(AppLocalizations l10n, DocumentTab? tab) {
  final label = tab?.history.nextRedoLabel;
  return label == null
      ? l10n.nothing_to_redo
      : '${l10n.redo_named(label)}  ${shellShortcut('Z', shift: true)}';
}

class _CommandDock extends StatelessWidget {
  const _CommandDock({
    required this.workspace,
    required this.commandFocus,
    required this.commandHeight,
    required this.isExpanded,
    required this.onResize,
    required this.onResizeEnd,
    required this.onToggleExpand,
  });

  final Workspace workspace;
  final FocusNode commandFocus;
  final double commandHeight;
  final bool isExpanded;
  final void Function(double delta) onResize;
  final VoidCallback onResizeEnd;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return _HudCard(
      child: IntrinsicHeight(
        child: Row(
          key: const Key('canvas-command-dock'),
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: LayoutTabStrip(workspace: workspace),
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: tokens.border,
            ),
            Expanded(
              child: CommandLinePane(
                workspace: workspace,
                height: commandHeight,
                isExpanded: isExpanded,
                focusNode: commandFocus,
                onResize: onResize,
                onResizeEnd: onResizeEnd,
                onToggleExpand: onToggleExpand,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: tokens.border,
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: _DraftingModes(workspace: workspace),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftingModes extends StatelessWidget {
  const _DraftingModes({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tab = workspace.active;
    final snap = workspace.snapEngine;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusToggle(
          key: const Key('canvas-mode-snap'),
          label: l10n.snap,
          isOn: snap.enabled,
          tooltip: l10n.snap_tooltip,
          onPressed: () => workspace.setSnapEnabled(!snap.enabled),
          onContextMenu: (position) =>
              _openSnapModeMenu(context, workspace, position),
        ),
        StatusToggle(
          key: const Key('canvas-mode-ortho'),
          label: l10n.ortho,
          isOn: snap.tracking.ortho,
          tooltip: l10n.ortho_tooltip,
          onPressed: () => workspace.setOrtho(!snap.tracking.ortho),
        ),
        StatusToggle(
          key: const Key('canvas-mode-polar'),
          label: l10n.polar,
          isOn: snap.tracking.polar,
          tooltip: l10n.polar_tooltip(
            _polarDegrees(snap.tracking.polarIncrement),
          ),
          onPressed: () => workspace.setPolar(!snap.tracking.polar),
          onContextMenu: (position) =>
              _openPolarIncrementMenu(context, workspace, position),
        ),
        StatusToggle(
          key: const Key('canvas-mode-grid'),
          label: l10n.grid,
          isOn: tab?.showGrid ?? false,
          tooltip: l10n.grid_tooltip,
          onPressed: () {
            if (tab != null) workspace.setShowGrid(!tab.showGrid);
          },
        ),
      ],
    );
  }
}

const _polarIncrements = [5, 15, 30, 45, 90];

int _polarDegrees(double radians) => (radians * 180 / math.pi).round();

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
                    ? Icon(
                        Icons.check,
                        size: FanCadTokens.iconSmall,
                        color: tokens.accent,
                      )
                    : null,
              ),
              const SizedBox(width: FanCadTokens.space2),
              Text(context.l10n.snapModeLabel(mode), style: tokens.bodyStyle),
            ],
          ),
        ),
      const PopupMenuDivider(),
      PopupMenuItem<Object>(
        value: 'defaults',
        height: 32,
        child: Text(context.l10n.restore_defaults, style: tokens.bodyStyle),
      ),
    ],
  );
  if (chosen is SnapMode) {
    workspace.toggleSnapMode(chosen);
  } else if (chosen == 'defaults') {
    workspace.resetSnapModes();
  }
}

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
                    ? Icon(
                        Icons.check,
                        size: FanCadTokens.iconSmall,
                        color: tokens.accent,
                      )
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
