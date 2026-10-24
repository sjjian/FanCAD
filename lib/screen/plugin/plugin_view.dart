import 'dart:async';
import 'dart:io';

import 'package:fancad_extension/fancad_extension.dart';
import 'package:fancad_widget/fancad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../l10n/l10n.dart';
import '../../models/plugin.dart';
import '../../services/plugin.dart';
import '../../services/workspace.dart';
import '../widgets/panel.dart';

/// Icon for a plugin activity-bar entry. Unknown names use the extension icon.
IconData pluginActivityIcon(String? name) => fanCadNamedIcon(name);

/// Every contributed panel at [location], drawn under the built-in chrome.
class PluginLocationViews extends ConsumerWidget {
  const PluginLocationViews({
    super.key,
    required this.location,
    required this.workspace,
    this.onlyId,
    this.expand = false,
  });

  final String location;
  final Workspace workspace;

  /// When set, only this panel id is drawn. The sidebar uses this so each
  /// activity-bar entry shows its own tree.
  final String? onlyId;

  /// Sidebar bodies want the tree to fill the pane. A properties section does not.
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panels = ref.watch(
      pluginNotifierProvider.select(
        (model) => [
          for (final panel in model.panels)
            if (panel.location == location &&
                (onlyId == null || panel.id == onlyId))
              panel,
        ],
      ),
    );
    if (panels.isEmpty) return const SizedBox.shrink();
    final children = [
      for (final panel in panels)
        PluginPanelBody(panel: panel, workspace: workspace, expand: expand),
    ];
    if (!expand) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    if (children.length == 1) return children.single;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final child in children) Expanded(child: child)],
    );
  }
}

class PluginPanelBody extends ConsumerWidget {
  const PluginPanelBody({
    super.key,
    required this.panel,
    required this.workspace,
    required this.expand,
  });

  final PluginPanelModel panel;
  final Workspace workspace;
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(
      pluginNotifierProvider.select((model) => model.viewTrees[panel.id]),
    );
    final body = tree == null
        ? FanCadEmpty(message: panel.title)
        : PluginView(
            key: ValueKey(panel.id),
            viewId: panel.id,
            pluginId: panel.pluginId,
            treeJson: tree,
            workspace: workspace,
          );
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(title: panel.title),
        if (expand) Expanded(child: body) else body,
      ],
    );
    return column;
  }
}

/// Paints one validated view tree. State stays in the plugin; this widget
/// only sends events keyed by node id.
class PluginView extends ConsumerStatefulWidget {
  const PluginView({
    super.key,
    required this.viewId,
    required this.pluginId,
    required this.treeJson,
    required this.workspace,
    this.onPromptValue,
  });

  final String viewId;
  final String pluginId;
  final String treeJson;
  final Workspace workspace;

  /// Set by the dialog when a prompt should read the `value` field back.
  final void Function(String nodeId, String value)? onPromptValue;

  @override
  ConsumerState<PluginView> createState() => PluginViewState();
}

class PluginViewState extends ConsumerState<PluginView> {
  @override
  Widget build(BuildContext context) {
    ref.watch(pluginNotifierProvider.select((model) => model.epoch));
    final document = widget.workspace.active?.document;
    return FanCadView(
      tree: widget.treeJson,
      invalidLabel: context.l10n.plugin_view_invalid,
      host: FanCadViewHost(
        closedViewerLabel: context.l10n.plugin_viewer_closed,
        layers: [
          if (document != null)
            for (final layer in document.layers.values) layer.name,
        ],
        imageFile: _imageFile,
        viewer: _viewer,
        flashEntity: _flash,
        onEvent: (nodeId, event, value) {
          widget.onPromptValue?.call(nodeId, value is String ? value : '');
          ref.read(pluginNotifierProvider.notifier).manager?.emit(
            widget.pluginId,
            'ui.event',
            {
              'viewId': widget.viewId,
              'nodeId': nodeId,
              'event': event,
              'value': value,
            },
          );
        },
      ),
    );
  }

  String? _directory() {
    final plugins = ref.read(pluginNotifierProvider).plugins;
    for (final plugin in plugins) {
      if (plugin.id == widget.pluginId) return plugin.directory;
    }
    return null;
  }

  File? _imageFile(String asset) {
    final directory = _directory();
    if (directory == null || asset.isEmpty) return null;
    final file = File(p.normalize(p.join(directory, asset)));
    final root = p.normalize(directory);
    if (!p.isWithin(root, file.path) || !file.existsSync()) return null;
    return file;
  }

  FanCadViewerBinding? _viewer(String canvasId) {
    final viewer = ref
        .read(pluginNotifierProvider.notifier)
        .viewerFor(widget.pluginId, canvasId);
    if (viewer == null) return null;
    return FanCadViewerBinding(
      document: viewer.session.document,
      viewport: viewer.viewport,
      changes: viewer.session.changes,
      retain: viewer.retain,
      release: viewer.release,
    );
  }

  void _flash(int id) {
    final sessionId = widget.workspace.activeSession?.id;
    if (sessionId == null) return;
    widget.workspace.flashHighlightsOn(sessionId, [id]);
  }
}

/// The window a plugin asked for. One at a time; a newer request replaces it.
///
/// This is [FanCadCanvasWindow], the same card text editing parks on the
/// drawing: a title you can drag, edges you can resize, and a corner close.
class PluginDialogLayer extends ConsumerStatefulWidget {
  const PluginDialogLayer({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<PluginDialogLayer> createState() => _PluginDialogLayerState();
}

/// Title-bar menu for `titlebar/tools` contributions.
class PluginToolsButton extends ConsumerWidget {
  const PluginToolsButton({super.key, required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _pluginCommands(ref, 'titlebar/tools');
    if (items.isEmpty) return const SizedBox.shrink();
    return FanCadIconButton(
      icon: Icons.extension_outlined,
      tooltip: context.l10n.extensions,
      onPressed: () async {
        final chosen = await showFanCadMenu<String>(
          context: context,
          position: fanCadMenuPosition(
            (context.findRenderObject() as RenderBox?)?.localToGlobal(
                  Offset.zero,
                ) ??
                Offset.zero,
          ),
          items: [
            for (final item in items)
              fanCadMenuItem(context, value: item.commandId, label: item.label),
          ],
        );
        if (chosen != null) unawaited(workspace.run(chosen));
      },
    );
  }
}

List<({String commandId, String label})> _pluginCommands(
  WidgetRef ref,
  String menuId,
) {
  final host = ref.read(pluginNotifierProvider.notifier).manager;
  if (host == null) return const [];
  final workspace = ref.read(workspaceNotifierProvider.notifier);
  final hasSelection = workspace.active?.selection.isNotEmpty ?? false;
  final commandIdle =
      ref.read(workspaceNotifierProvider).runningCommand == null;
  return [
    for (final item in host.contributions.menu(menuId))
      if (contributionWhen(
        item.when,
        hasSelection: hasSelection,
        commandIdle: commandIdle,
      ))
        (
          commandId: item.commandId,
          label:
              workspace.commands.find(item.commandId)?.title ?? item.commandId,
        ),
  ];
}

/// Canvas context-menu rows a plugin contributed.
List<PopupMenuEntry<String>> pluginCanvasMenuItems(
  BuildContext context,
  WidgetRef ref,
) {
  final commands = _pluginCommands(ref, 'canvas/context');
  if (commands.isEmpty) return const [];
  return [
    const PopupMenuDivider(),
    for (final item in commands)
      fanCadMenuItem(context, value: item.commandId, label: item.label),
  ];
}

class _PluginDialogLayerState extends ConsumerState<PluginDialogLayer> {
  String _promptValue = '';

  void _finish(Object? value) {
    ref.read(pluginNotifierProvider.notifier).completeDialog(value);
  }

  @override
  Widget build(BuildContext context) {
    final dialog = ref.watch(
      pluginNotifierProvider.select((model) => model.dialog),
    );
    if (dialog == null) return const SizedBox.shrink();
    // Same floating window as text editing: drag the title, resize from the
    // edges, close from the corner. A viewer needs a taller card; a confirm
    // stays short. The token keeps a refresh from jumping the window back.
    final roomy =
        dialog.bodyJson.contains('"type":"preview"') ||
        dialog.bodyJson.contains('"type":"viewer"');
    final size = roomy ? const Size(520, 640) : const Size(420, 320);
    final minSize = roomy ? const Size(400, 360) : const Size(320, 180);
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounds = Size(constraints.maxWidth, constraints.maxHeight);
          if (!bounds.isFinite || bounds.isEmpty) {
            return const SizedBox.shrink();
          }
          return Stack(
            children: [
              FanCadCanvasWindow(
                key: ValueKey(dialog.token),
                // The token is part of the name. Replacing the dialog keeps
                // the previous window mounted until the end of the frame, and
                // a shared name fails the debug check while both exist.
                name: 'plugin-dialog-${dialog.token}',
                title: dialog.title,
                origin: Offset(
                  (bounds.width - size.width) / 2,
                  (bounds.height - size.height) / 2,
                ),
                bounds: bounds,
                initialSize: size,
                minSize: minSize,
                closeTooltip: context.l10n.close,
                onClose: () => _finish(null),
                onBarrierTap: () => _finish(null),
                footer: dialog.buttons.isEmpty
                    ? null
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: FanCadTokens.space3,
                          vertical: FanCadTokens.space2,
                        ),
                        child: Wrap(
                          spacing: FanCadTokens.space2,
                          alignment: WrapAlignment.end,
                          children: [
                            for (final button in dialog.buttons)
                              FanCadButton(
                                props: FanCadButtonProps(label: button),
                                onPressed: () {
                                  final cancel =
                                      button.toLowerCase() == 'cancel';
                                  _finish(
                                    dialog.prompt
                                        ? (cancel ? null : _promptValue)
                                        : button,
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                child: PluginView(
                  key: ValueKey(dialog.token),
                  viewId: 'dialog',
                  pluginId: dialog.pluginId,
                  treeJson: dialog.bodyJson,
                  workspace: widget.workspace,
                  onPromptValue: (_, value) => _promptValue = value,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
