import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../commands/keybindings.dart';
import '../../l10n/l10n.dart';
import '../../services/command_line.dart';
import '../../services/workspace.dart';
import '../command_line/command_line.dart';
import '../widgets/tokens.dart';
import '../widgets/widgets.dart';

/// Drawing chrome that floats over the canvas as one card.
///
/// Operations sit on the top row, the command line on the bottom. Layout names
/// and the command log live in the left sidebar. Cursor, selection, layer and
/// zoom sit in the canvas corners. The window still keeps a thin [StatusBar].
class CanvasHud extends StatelessWidget {
  const CanvasHud({
    super.key,
    required this.workspace,
    required this.commandFocus,
    required this.onOpenHistory,
    required this.child,
    this.historyOpen = false,
  });

  final Workspace workspace;
  final FocusNode commandFocus;
  final VoidCallback onOpenHistory;
  final bool historyOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget readouts() => Stack(
      children: [
        Positioned(
          left: FanCadTokens.space3,
          bottom: FanCadTokens.space1,
          child: _CoordinateReadout(
            key: const Key('canvas-readout-cursor'),
            workspace: workspace,
          ),
        ),
        if (workspace.active != null)
          Positioned(
            right: FanCadTokens.space3,
            bottom: FanCadTokens.space1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SelectionReadout(
                  key: const Key('canvas-readout-selection'),
                  workspace: workspace,
                  tab: workspace.active!,
                ),
                _CurrentLayerIndicator(
                  key: const Key('canvas-readout-layer'),
                  workspace: workspace,
                ),
                _ZoomReadout(
                  key: const Key('canvas-readout-zoom'),
                  workspace: workspace,
                  tab: workspace.active!,
                ),
              ],
            ),
          ),
      ],
    );
    return Stack(
      key: const Key('canvas-hud'),
      children: [
        child,
        Positioned(
          left: FanCadTokens.space3,
          right: FanCadTokens.space3,
          bottom: canvasHudDockBottom,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: canvasHudMaxWidth),
              child: _HudDock(
                workspace: workspace,
                commandFocus: commandFocus,
                historyOpen: historyOpen,
                onOpenHistory: onOpenHistory,
              ),
            ),
          ),
        ),
        readouts(),
      ],
    );
  }
}

/// How wide the floating card may grow. Wide enough for a typed prompt,
/// still narrower than a dock that ate the drawing.
@visibleForTesting
const canvasHudMaxWidth = 640.0;

/// Floor under the floating card: readout height with equal pads so the
/// corner status sits between the canvas floor and the card.
@visibleForTesting
const canvasHudDockBottom =
    FanCadTokens.space1 + FanCadTokens.statusBarHeight + FanCadTokens.space1;

/// Corner radius on the floating card. Same large chrome radius as dialogs.
@visibleForTesting
const canvasHudRadius = FanCadTokens.radiusLarge;

/// Inset so tools and mode chips sit inside the rounded corners.
@visibleForTesting
const canvasHudPadding = EdgeInsets.symmetric(horizontal: FanCadTokens.space2);

/// The bottom card plus the command-suggest popup stacked above it so both
/// share the same max width and stretch to the same left and right edges.
class _HudDock extends StatefulWidget {
  const _HudDock({
    required this.workspace,
    required this.commandFocus,
    required this.onOpenHistory,
    required this.historyOpen,
  });

  final Workspace workspace;
  final FocusNode commandFocus;
  final VoidCallback onOpenHistory;
  final bool historyOpen;

  @override
  State<_HudDock> createState() => _HudDockState();
}

class _HudDockState extends State<_HudDock> {
  final TextEditingController _input = TextEditingController();
  final GlobalKey<CommandSuggestState> _suggestKey = GlobalKey();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CommandSuggest(
          key: _suggestKey,
          input: _input,
          workspace: widget.workspace,
          onAccept: (descriptor) {
            _input.clear();
            widget.workspace.run(descriptor.id);
          },
        ),
        _HudCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionBar(workspace: widget.workspace),
              const FanCadHairline(),
              _CommandBar(
                workspace: widget.workspace,
                commandFocus: widget.commandFocus,
                historyOpen: widget.historyOpen,
                onOpenHistory: widget.onOpenHistory,
                input: _input,
                suggestKey: _suggestKey,
              ),
            ],
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
      elevation: 3,
      shadowColor: tokens.shadow,
      borderRadius: BorderRadius.circular(canvasHudRadius),
      child: Container(
        key: const Key('canvas-bottom-card'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(canvasHudRadius),
          border: Border.all(color: tokens.borderStrong),
        ),
        clipBehavior: Clip.antiAlias,
        padding: canvasHudPadding,
        child: child,
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
  (commandId: 'edit.move', icon: Icons.open_with, alias: 'M', fallback: 'Move'),
];

String _saveTooltip(
  AppLocalizations l10n,
  DocumentTab? tab,
  CommandRegistry commands,
) {
  final chord = shortcutLabelForCommand(commands, 'file.save') ?? '';
  if (tab == null || tab.isStartPage) {
    return '${l10n.save}  $chord';
  }
  if (tab.isDirty) return '${l10n.save_unsaved_changes}  $chord';
  if (tab.filePath == null) return '${l10n.save_this_drawing}  $chord';
  return l10n.saved_write_again(chord);
}

String _undoTooltip(
  AppLocalizations l10n,
  DocumentTab? tab,
  CommandRegistry commands,
) {
  final label = tab?.history.nextUndoLabel;
  final chord = shortcutLabelForCommand(commands, 'edit.undo') ?? '';
  return label == null
      ? l10n.nothing_to_undo
      : '${l10n.undo_named(label)}  $chord';
}

String _redoTooltip(
  AppLocalizations l10n,
  DocumentTab? tab,
  CommandRegistry commands,
) {
  final label = tab?.history.nextRedoLabel;
  final chord = shortcutLabelForCommand(commands, 'edit.redo') ?? '';
  return label == null
      ? l10n.nothing_to_redo
      : '${l10n.redo_named(label)}  $chord';
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final running = ref.watch(
      workspaceNotifierProvider.select((s) => s.runningCommand),
    );
    final activeId = ref.watch(
      workspaceNotifierProvider.select((s) => s.activeSessionId),
    );
    if (activeId != null) {
      ref.watch(
        documentTabNotifierProvider(activeId).select((s) => s.contentEpoch),
      );
    }
    ref.watch(
      workspaceNotifierProvider.select((s) => s.active?.isDirty),
    );
    final tab = workspace.active;
    return SizedBox(
      key: const Key('canvas-action-card'),
      height: FanCadTokens.tabBarHeight,
      child: Row(
        children: [
          FanCadIconButton(
            key: const Key('canvas-tool-save'),
            icon: tab?.isDirty == true ? Icons.save : Icons.save_outlined,
            tooltip: _saveTooltip(l10n, tab, workspace.commands),
            size: 24,
            enabled: tab != null && !tab.isStartPage,
            onPressed: () => workspace.run('file.save'),
          ),
          const SizedBox(width: FanCadTokens.space1),
          FanCadIconButton(
            key: const Key('canvas-tool-undo'),
            icon: Icons.undo,
            tooltip: _undoTooltip(l10n, tab, workspace.commands),
            size: 24,
            enabled: tab?.history.canUndo ?? false,
            onPressed: () => workspace.run('edit.undo'),
          ),
          const SizedBox(width: FanCadTokens.space1),
          FanCadIconButton(
            key: const Key('canvas-tool-redo'),
            icon: Icons.redo,
            tooltip: _redoTooltip(l10n, tab, workspace.commands),
            size: 24,
            enabled: tab?.history.canRedo ?? false,
            onPressed: () => workspace.run('edit.redo'),
          ),
          for (final tool in canvasQuickTools) ...[
            const SizedBox(width: FanCadTokens.space1),
            FanCadIconButton(
              key: Key('canvas-tool-${tool.commandId}'),
              icon: tool.icon,
              tooltip:
                  '${l10n.commandTitle(tool.commandId, tool.fallback)}  ${tool.alias}',
              size: 24,
              enabled: tab != null,
              isActive: running == tool.commandId,
              onPressed: () => workspace.run(tool.commandId),
            ),
          ],
          const Spacer(),
          _DraftingModes(workspace: workspace),
        ],
      ),
    );
  }
}

class _CommandBar extends StatelessWidget {
  const _CommandBar({
    required this.workspace,
    required this.commandFocus,
    required this.historyOpen,
    required this.onOpenHistory,
    required this.input,
    required this.suggestKey,
  });

  final Workspace workspace;
  final FocusNode commandFocus;
  final bool historyOpen;
  final VoidCallback onOpenHistory;
  final TextEditingController input;
  final GlobalKey<CommandSuggestState> suggestKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('canvas-command-dock'),
      height: FanCadTokens.tabBarHeight,
      child: CommandLinePane(
        workspace: workspace,
        focusNode: commandFocus,
        historyOpen: historyOpen,
        onOpenHistory: onOpenHistory,
        input: input,
        suggestKey: suggestKey,
      ),
    );
  }
}

class _DraftingModes extends ConsumerWidget {
  const _DraftingModes({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(
      workspaceNotifierProvider.select(
        (s) => (s.snapEnabled, s.ortho, s.polar, s.snapModes, s.active?.showGrid),
      ),
    );
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
        const SizedBox(width: FanCadTokens.space1),
        StatusToggle(
          key: const Key('canvas-mode-ortho'),
          label: l10n.ortho,
          isOn: snap.tracking.ortho,
          tooltip: l10n.ortho_tooltip,
          onPressed: () => workspace.setOrtho(!snap.tracking.ortho),
        ),
        const SizedBox(width: FanCadTokens.space1),
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
        const SizedBox(width: FanCadTokens.space1),
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
  final chosen = await showFanCadMenu<Object>(
    context: context,
    position: fanCadMenuPosition(globalPosition),
    placement: FanCadMenuPlacement.up,
    items: [
      for (final mode in SnapMode.values)
        fanCadMenuItem<Object>(
          context,
          value: mode,
          label: context.l10n.snapModeLabel(mode),
          checked: workspace.snapEngine.modes.contains(mode),
        ),
      const PopupMenuDivider(),
      fanCadMenuItem<Object>(
        context,
        value: 'defaults',
        label: context.l10n.restore_defaults,
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
  final current = _polarDegrees(workspace.snapEngine.tracking.polarIncrement);
  final chosen = await showFanCadMenu<int>(
    context: context,
    position: fanCadMenuPosition(globalPosition),
    placement: FanCadMenuPlacement.up,
    items: [
      for (final degrees in _polarIncrements)
        fanCadMenuItem<int>(
          context,
          value: degrees,
          label: '$degrees°',
          checked: degrees == current,
        ),
    ],
  );
  if (chosen == null) return;
  workspace.setPolarIncrement(chosen * math.pi / 180);
}

/// The live cursor. A click copies it, or feeds it to a command that is
/// already asking for a point — so a measured XY does not have to be retyped.
class _CoordinateReadout extends ConsumerStatefulWidget {
  const _CoordinateReadout({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<_CoordinateReadout> createState() => _CoordinateReadoutState();
}

class _CoordinateReadoutState extends ConsumerState<_CoordinateReadout> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final awaiting = ref.watch(
      commandLineNotifierProvider.select((s) => s.prompt != null),
    );
    final tab = widget.workspace.active;
    if (tab == null) {
      return _chrome(context, cursor: null, awaiting: awaiting);
    }
    return ListenableBuilder(
      listenable: tab.viewport,
      builder: (context, _) => _chrome(
        context,
        cursor: tab.viewport.pointer,
        awaiting: awaiting,
      ),
    );
  }

  Widget _chrome(
    BuildContext context, {
    required Vec2? cursor,
    required bool awaiting,
  }) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final text = cursor == null
        ? null
        : '${cursor.x.toStringAsFixed(3)}, ${cursor.y.toStringAsFixed(3)}';
    final enabled = text != null;
    return Tooltip(
      message: text == null
          ? l10n.cursor
          : awaiting
          ? l10n.use_as_next_point(text)
          : l10n.copy_text(text),
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
    workspace.notify(context.l10n.copied_text(text));
  }
}

class _SelectionReadout extends ConsumerWidget {
  const _SelectionReadout({
    super.key,
    required this.workspace,
    required this.tab,
  });

  final Workspace workspace;
  final DocumentTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(
      documentTabNotifierProvider(tab.session.id).select(
        (s) => s.selectionEpoch,
      ),
    );
    final l10n = context.l10n;
    return FanCadTextButton(
      label: l10n.selected_count(tab.selection.length),
      tooltip: tab.selection.isEmpty
          ? l10n.nothing_selected
          : l10n.open_properties_selection,
      enabled: tab.selection.isNotEmpty,
      onPressed: () => workspace.revealPanel('properties'),
    );
  }
}

class _CurrentLayerIndicator extends ConsumerStatefulWidget {
  const _CurrentLayerIndicator({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<_CurrentLayerIndicator> createState() =>
      _CurrentLayerIndicatorState();
}

class _CurrentLayerIndicatorState
    extends ConsumerState<_CurrentLayerIndicator> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tab = widget.workspace.active;
    if (tab != null) {
      ref.watch(
        documentTabNotifierProvider(tab.session.id).select(
          (s) => s.contentEpoch,
        ),
      );
    }
    final tokens = context.tokens;
    if (tab == null) return const SizedBox.shrink();
    final name = tab.document.currentLayer;
    final layer = tab.document.layer(name);
    final hidden = layer != null && !layer.isEffectivelyVisible;
    final locked = layer?.locked ?? false;
    final l10n = context.l10n;
    final states = [
      if (hidden) l10n.layer_hidden,
      if (locked) l10n.layer_locked,
    ];
    return Tooltip(
      message: [
        '${l10n.current_layer_named(name)}${states.isEmpty ? '' : ' (${states.join(', ')})'}',
        l10n.current_layer_hint,
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
                  width: 12,
                  height: 12,
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
                    size: FanCadTokens.iconSmall,
                    color: tokens.textFaint,
                  ),
                ],
                if (locked) ...[
                  const SizedBox(width: FanCadTokens.space1),
                  Icon(
                    Icons.lock_outline,
                    size: FanCadTokens.iconSmall,
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
    final workspace = widget.workspace;
    final chosen = await showFanCadMenu<String>(
      context: context,
      position: fanCadMenuPosition(globalPosition),
      placement: FanCadMenuPlacement.up,
      items: [
        fanCadMenuItem(
          context,
          value: 'visible',
          label: hidden
              ? context.l10n.turn_layer_on
              : context.l10n.turn_layer_off,
        ),
        fanCadMenuItem(
          context,
          value: 'lock',
          label: locked ? context.l10n.unlock_layer : context.l10n.lock_layer,
        ),
        const PopupMenuDivider(),
        fanCadMenuItem(
          context,
          value: 'manage',
          label: context.l10n.manage_layers,
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

class _ZoomReadout extends StatelessWidget {
  const _ZoomReadout({super.key, required this.workspace, required this.tab});

  final Workspace workspace;
  final DocumentTab tab;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tab.viewport,
      builder: (context, _) => _label(context),
    );
  }

  Widget _label(BuildContext context) {
    final l10n = context.l10n;
    final scene = tab.lastScene;
    return FanCadTextButton(
      label: '1:${(1 / tab.viewport.viewport.scale).toStringAsFixed(2)}',
      tooltip: scene == null
          ? l10n.zoom_extents_tooltip
          : '${l10n.zoom_extents_tooltip}\n${l10n.draw_calls_visible(scene.drawCallCount, scene.entityCount)}',
      onPressed: () => workspace.run('view.zoomExtents'),
    );
  }
}
