import 'dart:async';

import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../panels/ai_panel.dart';
import '../panels/extensions_panel.dart';
import '../panels/layers_panel.dart';
import '../panels/plugin_editor_panel.dart';
import '../panels/properties_panel.dart';
import '../state/plugin_bootstrap.dart';
import '../state/providers.dart';
import '../state/settings.dart';
import '../state/workspace.dart';
import '../theme/tokens.dart';
import 'command_line.dart';
import 'command_palette.dart';
import 'document_view.dart';
import 'shell_widgets.dart';
import 'title_bar.dart';

/// The application shell.
///
/// Laid out as fixed chrome around one flexible canvas: title bar, activity bar,
/// sidebar, tab strip, drawing, command line, status bar. The proportions are
/// deliberate — everything except the drawing has a fixed height in pixels, so
/// the canvas gets every pixel that is left rather than being squeezed by a
/// panel that grew.
class Workbench extends ConsumerStatefulWidget {
  const Workbench({super.key});

  @override
  ConsumerState<Workbench> createState() => _WorkbenchState();
}

class _WorkbenchState extends ConsumerState<Workbench> {
  /// Focus for the command line. Held here because the canvas hands focus back
  /// to it on every click, which is what makes typing mid-command work.
  final FocusNode _commandFocus = FocusNode(debugLabel: 'command-line');

  StreamSubscription<String>? _panelReveals;
  StreamSubscription<ApprovalRequest>? _approvals;

  @override
  void initState() {
    super.initState();
    // Subscribed in initState rather than in build so a rebuild does not
    // register a second listener and pop two dialogs for one request.
    final workspace = ref.read(workspaceProvider);
    _panelReveals = workspace.panelReveals.listen((panelId) {
      ref.read(sidebarProvider.notifier).reveal(panelId);
    });
    _approvals = workspace.approvals.listen(_showApproval);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _commandFocus.requestFocus();
      // The extension host is started after the first frame so third-party
      // code cannot sit between launch and a usable window.
      unawaited(ref.read(pluginBootstrapProvider).start());
    });
  }

  @override
  void dispose() {
    _panelReveals?.cancel();
    _approvals?.cancel();
    _commandFocus.dispose();
    super.dispose();
  }

  Future<void> _showApproval(ApprovalRequest request) async {
    final workspace = ref.read(workspaceProvider);
    workspace.setPendingHighlights(request.highlightIds);
    final tokens = context.tokens;
    final approved = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => AlertDialog(
        backgroundColor: tokens.surfaceOverlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
          side: BorderSide(color: tokens.borderStrong),
        ),
        title: Text(
          request.title,
          style: tokens.bodyStyle.copyWith(fontSize: 15),
        ),
        content: Text(request.details, style: tokens.labelStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: tokens.bodyStyle),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    workspace.setPendingHighlights(const []);
    if (approved ?? false) {
      request.approve();
    } else {
      request.reject();
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceProvider);
    return ListenableBuilder(
      listenable: workspace,
      builder: (context, _) => _buildShell(context, workspace),
    );
  }

  Widget _buildShell(BuildContext context, Workspace workspace) {
    final tokens = context.tokens;
    final sidebar = ref.watch(sidebarProvider);
    final commandPane = ref.watch(commandPaneProvider);
    final paletteOpen = ref.watch(paletteOpenProvider);

    return CallbackShortcuts(
      bindings: _shortcuts(workspace),
      child: Focus(
        autofocus: true,
        // Material rather than a bare ColoredBox because the shell hosts
        // Material descendants — text fields, tooltips, dialogs — and they
        // require an ancestor to paint on.
        child: Material(
          color: tokens.surface,
          child: Column(
            children: [
              TitleBar(
                workspace: workspace,
                onTogglePalette: () => ref
                    .read(paletteOpenProvider.notifier)
                    .update((open) => !open),
                onToggleSidebar: ref.read(sidebarProvider.notifier).toggle,
                onToggleTheme: ref
                    .read(themeBrightnessProvider.notifier)
                    .toggle,
              ),
              Expanded(
                child: Stack(
                  children: [
                    Row(
                      children: [
                        _ActivityBar(
                          activeViewId: sidebar.isOpen ? sidebar.viewId : '',
                          onSelect: ref.read(sidebarProvider.notifier).select,
                        ),
                        if (sidebar.isOpen) ...[
                          SizedBox(
                            width: sidebar.width,
                            child: ColoredBox(
                              color: tokens.surface,
                              child: _sidebarBody(sidebar.viewId, workspace),
                            ),
                          ),
                          ShellSplitter(
                            axis: Axis.vertical,
                            onDrag: (delta) => ref
                                .read(sidebarProvider.notifier)
                                .resize(sidebar.width + delta),
                            onDragEnd: ref
                                .read(sidebarProvider.notifier)
                                .commitWidth,
                          ),
                        ],
                        Expanded(
                          child: Column(
                            children: [
                              DocumentTabStrip(workspace: workspace),
                              Expanded(child: _canvasArea(workspace)),
                              SizedBox(
                                height: commandPane.height,
                                child: CommandLinePane(
                                  workspace: workspace,
                                  height: commandPane.height,
                                  focusNode: _commandFocus,
                                  onResize: (delta) => ref
                                      .read(commandPaneProvider.notifier)
                                      .resize(commandPane.height + delta),
                                  onResizeEnd: ref
                                      .read(commandPaneProvider.notifier)
                                      .commitHeight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (paletteOpen)
                      CommandPalette(
                        workspace: workspace,
                        onDismiss: () =>
                            ref.read(paletteOpenProvider.notifier).state =
                                false,
                      ),
                    Positioned(
                      right: FanCadTokens.space4,
                      bottom: FanCadTokens.space4,
                      child: _Notices(workspace: workspace),
                    ),
                  ],
                ),
              ),
              StatusBar(workspace: workspace),
            ],
          ),
        ),
      ),
    );
  }

  Widget _canvasArea(Workspace workspace) {
    final tab = workspace.active;
    if (tab == null) {
      return EmptyWorkspace(
        recentFiles: workspace.settings.getStringList(SettingsKeys.recentFiles),
        onOpenRecent: (path) =>
            workspace.run('file.open', args: {'path': path}),
        onOpen: () => workspace.run('file.open'),
        onNew: () => workspace.run('file.new'),
      );
    }
    return DocumentView(
      // Keyed by tab so switching tabs gets a fresh canvas state rather than
      // one holding another drawing's tessellation cache.
      key: ValueKey(tab.session.id),
      workspace: workspace,
      tab: tab,
      commandLineFocus: _commandFocus,
    );
  }

  Widget _sidebarBody(String viewId, Workspace workspace) => switch (viewId) {
    'layers' => LayersPanel(workspace: workspace),
    'properties' => PropertiesPanel(workspace: workspace),
    'commands' => _CommandListPanel(workspace: workspace),
    'plugins' => ExtensionsPanel(
      workspace: workspace,
      host: ref.watch(pluginHostProvider),
    ),
    'editor' => PluginEditorPanel(
      workspace: workspace,
      host: ref.watch(pluginHostProvider),
    ),
    'ai' => AiPanel(controller: ref.watch(aiControllerProvider)),
    _ => const SizedBox.shrink(),
  };

  Map<ShortcutActivator, VoidCallback> _shortcuts(Workspace workspace) {
    // Control and Meta are both bound because Flutter treats them as
    // different keys: Ctrl+S on Windows/Linux, ⌘S on a Mac.
    Map<ShortcutActivator, VoidCallback> chord(
      LogicalKeyboardKey key,
      VoidCallback run, {
      bool shift = false,
    }) => {
      SingleActivator(key, control: true, shift: shift): run,
      SingleActivator(key, meta: true, shift: shift): run,
    };

    return {
      ...chord(
        LogicalKeyboardKey.keyP,
        () => ref.read(paletteOpenProvider.notifier).update((open) => !open),
        shift: true,
      ),
      ...chord(
        LogicalKeyboardKey.keyB,
        ref.read(sidebarProvider.notifier).toggle,
      ),
      ...chord(LogicalKeyboardKey.keyN, () => workspace.run('file.new')),
      ...chord(LogicalKeyboardKey.keyO, () => workspace.run('file.open')),
      ...chord(LogicalKeyboardKey.keyS, () => workspace.run('file.save')),
      ...chord(
        LogicalKeyboardKey.keyS,
        () => workspace.run('file.saveAs'),
        shift: true,
      ),
      ...chord(LogicalKeyboardKey.keyW, () => workspace.run('file.close')),
      ...chord(LogicalKeyboardKey.keyZ, () => workspace.run('edit.undo')),
      ...chord(
        LogicalKeyboardKey.keyZ,
        () => workspace.run('edit.redo'),
        shift: true,
      ),
      ...chord(LogicalKeyboardKey.keyA, () => workspace.run('select.all')),
      ...chord(
        LogicalKeyboardKey.keyA,
        () => workspace.run('select.none'),
        shift: true,
      ),
      ...chord(
        LogicalKeyboardKey.keyE,
        () => workspace.run('view.zoomExtents'),
        shift: true,
      ),
      ...chord(LogicalKeyboardKey.equal, () => workspace.run('view.zoomIn')),
      ...chord(LogicalKeyboardKey.minus, () => workspace.run('view.zoomOut')),
      ...chord(
        LogicalKeyboardKey.numpadAdd,
        () => workspace.run('view.zoomIn'),
      ),
      ...chord(
        LogicalKeyboardKey.numpadSubtract,
        () => workspace.run('view.zoomOut'),
      ),
    };
  }
}

/// The vertical strip of view switchers on the left.
class _ActivityBar extends StatelessWidget {
  const _ActivityBar({required this.activeViewId, required this.onSelect});

  final String activeViewId;
  final ValueChanged<String> onSelect;

  static const List<({String id, IconData icon, String label})> _views = [
    (id: 'layers', icon: Icons.layers_outlined, label: 'Layers'),
    (id: 'properties', icon: Icons.tune, label: 'Properties'),
    (id: 'commands', icon: Icons.terminal, label: 'Commands'),
    (id: 'plugins', icon: Icons.extension_outlined, label: 'Extensions'),
    (id: 'editor', icon: Icons.code, label: 'Re-Editor'),
    (id: 'ai', icon: Icons.auto_awesome_outlined, label: 'Assistant'),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: FanCadTokens.activityBarWidth,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(right: BorderSide(color: tokens.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: FanCadTokens.space2),
          for (final view in _views)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: ShellIconButton(
                icon: view.icon,
                tooltip: view.label,
                size: FanCadTokens.activityBarWidth,
                iconSize: 20,
                isActive: activeViewId == view.id,
                showActiveBar: true,
                onPressed: () => onSelect(view.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// A browsable list of every registered command.
///
/// Worth a panel of its own because it is the honest answer to "what can this
/// application do", and because it is the same list the assistant sees.
class _CommandListPanel extends StatefulWidget {
  const _CommandListPanel({required this.workspace});

  final Workspace workspace;

  @override
  State<_CommandListPanel> createState() => _CommandListPanelState();
}

class _CommandListPanelState extends State<_CommandListPanel> {
  final TextEditingController _filter = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final commands = widget.workspace.commands.search(_query, limit: 500);
    final byCategory = <String, List<CommandDescriptor>>{};
    for (final descriptor in commands) {
      byCategory.putIfAbsent(descriptor.category, () => []).add(descriptor);
    }
    final categories = byCategory.keys.toList()..sort();

    return Column(
      children: [
        const PanelHeader(title: 'Commands'),
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space3),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: ShellTextField(
            controller: _filter,
            hintText: 'Filter commands',
            style: tokens.bodyStyle,
            prefix: Padding(
              padding: const EdgeInsets.only(right: FanCadTokens.space2),
              child: Icon(Icons.search, size: 13, color: tokens.textFaint),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final category in categories)
                PanelSection(
                  title: category,
                  children: [
                    for (final descriptor in byCategory[category]!)
                      ShellRow(
                        onTap: () => widget.workspace.run(descriptor.id),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                descriptor.title,
                                style: tokens.bodyStyle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (descriptor.aliases.isNotEmpty)
                              Text(
                                descriptor.aliases.first.toUpperCase(),
                                style: tokens.monoStyle.copyWith(
                                  fontSize: 10.5,
                                  color: tokens.textFaint,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: FanCadTokens.space4),
            ],
          ),
        ),
      ],
    );
  }
}

/// Transient notifications, stacked above the status bar.
class _Notices extends StatelessWidget {
  const _Notices({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final notices = workspace.notices.reversed.take(3).toList();
    if (notices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final notice in notices)
          Padding(
            padding: const EdgeInsets.only(top: FanCadTokens.space2),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: FanCadTokens.space3,
                  vertical: FanCadTokens.space2,
                ),
                decoration: BoxDecoration(
                  color: tokens.surfaceOverlay,
                  borderRadius: BorderRadius.circular(FanCadTokens.radius),
                  border: Border.all(
                    color: notice.isError ? tokens.danger : tokens.border,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      notice.isError ? Icons.error_outline : Icons.info_outline,
                      size: 14,
                      color: notice.isError ? tokens.danger : tokens.accent,
                    ),
                    const SizedBox(width: FanCadTokens.space2),
                    Expanded(
                      child: Text(notice.message, style: tokens.bodyStyle),
                    ),
                    const SizedBox(width: FanCadTokens.space2),
                    ShellIconButton(
                      icon: Icons.close,
                      size: 18,
                      iconSize: 12,
                      onPressed: () => workspace.dismissNotice(notice),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
