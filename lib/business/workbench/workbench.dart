import 'dart:async';

import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../services/plugin_bootstrap.dart';
import '../../services/providers.dart';
import '../../services/workspace.dart';
import '../../storage/settings.dart';
import '../l10n/l10n.dart';
import '../panels/ai_panel.dart';
import '../panels/extensions_panel.dart';
import '../panels/layers_panel.dart';
import '../panels/layouts_panel.dart';
import '../panels/plugin_editor_panel.dart';
import '../panels/properties_panel.dart';
import '../theme/tokens.dart';
import 'canvas_hud.dart';
import 'command_line.dart';
import 'command_palette.dart';
import 'document_view.dart';
import 'settings_dialog.dart';
import 'shell_widgets.dart';
import 'title_bar.dart';

/// The application shell.
///
/// Laid out as fixed chrome around one flexible canvas: title bar, activity bar,
/// sidebar, tab strip, drawing, status bar. Operations and the command line
/// share one floating card on the canvas. Layout names live in the left sidebar.
class Workbench extends ConsumerStatefulWidget {
  const Workbench({super.key});

  @override
  ConsumerState<Workbench> createState() => _WorkbenchState();
}

class _WorkbenchState extends ConsumerState<Workbench> with WindowListener {
  /// Focus for the command line. Held here because the canvas hands focus back
  /// to it on every click, which is what makes typing mid-command work.
  final FocusNode _commandFocus = FocusNode(debugLabel: 'command-line');

  StreamSubscription<String>? _panelReveals;
  StreamSubscription<ApprovalRequest>? _approvals;
  bool _listeningForWindowClose = false;
  bool _closingWindow = false;

  @override
  void initState() {
    super.initState();
    // Subscribed in initState rather than in build so a rebuild does not
    // register a second listener and pop two dialogs for one request.
    final workspace = ref.read(workspaceProvider);
    _panelReveals = workspace.panelReveals.listen((panelId) {
      if (panelId == 'ai') {
        ref.read(assistantPaneProvider.notifier).setOpen(true);
        return;
      }
      if (isPreferencesPanel(panelId)) {
        if (!mounted) return;
        unawaited(
          showSettingsDialog(
            context,
            initialTab: settingsTabFromPanelId(panelId),
          ),
        );
        return;
      }
      ref.read(sidebarProvider.notifier).reveal(panelId);
    });
    _approvals = workspace.approvals.listen(_showApproval);
    unawaited(_bindWindowClose());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _commandFocus.requestFocus();
      // The extension host is started after the first frame so third-party
      // code cannot sit between launch and a usable window.
      unawaited(ref.read(pluginBootstrapProvider).start());
    });
  }

  @override
  void dispose() {
    if (_listeningForWindowClose) {
      windowManager.removeListener(this);
    }
    _panelReveals?.cancel();
    _approvals?.cancel();
    _commandFocus.dispose();
    super.dispose();
  }

  Future<void> _bindWindowClose() async {
    try {
      await windowManager.ensureInitialized();
      windowManager.addListener(this);
      await windowManager.setPreventClose(true);
      _listeningForWindowClose = true;
    } catch (_) {
      // Headless tests have no window plugin; the shell must still mount.
    }
  }

  @override
  void onWindowClose() {
    unawaited(_confirmWindowClose());
  }

  /// The red button and Alt+F4 used to skip the same Save / Don't save /
  /// Cancel path a tab close already offers.
  Future<void> _confirmWindowClose() async {
    if (_closingWindow) return;
    _closingWindow = true;
    try {
      final workspace = ref.read(workspaceProvider);
      while (workspace.tabs.isNotEmpty) {
        if (!mounted) return;
        final dirtyIndex = workspace.tabs.indexWhere((tab) => tab.isDirty);
        if (dirtyIndex >= 0 && workspace.activeIndex != dirtyIndex) {
          workspace.activate(dirtyIndex);
        }
        final result = await workspace.run('file.close');
        if (!result.isOk) return;
      }
      if (!mounted) return;
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } catch (_) {
      // Leave the window up if the plugin cannot finish the destroy.
    } finally {
      _closingWindow = false;
    }
  }

  Future<void> _showApproval(ApprovalRequest request) async {
    final workspace = ref.read(workspaceProvider);
    workspace.setPendingHighlights(request.highlightIds);
    final tokens = context.tokens;
    final title = request.title.toLowerCase();
    final unsaved = title.contains('unsaved') || title.contains('discard');
    final approved = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => Dialog(
        backgroundColor: tokens.surfaceOverlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
          side: BorderSide(color: tokens.borderStrong),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              FanCadTokens.space4,
              FanCadTokens.space3,
              FanCadTokens.space4,
              FanCadTokens.space3,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  request.title,
                  style: tokens.bodyStyle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: FanCadTokens.space3),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in request.details.split('\n'))
                          if (line.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: FanCadTokens.space1,
                              ),
                              child: Text(line, style: tokens.bodyStyle),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: FanCadTokens.space3),
                Row(
                  children: [
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop('cancel'),
                      child: Text(context.l10n.cancel, style: tokens.bodyStyle),
                    ),
                    if (unsaved)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop('discard'),
                        child: Text(
                          context.l10n.dont_save,
                          style: tokens.bodyStyle.copyWith(
                            color: tokens.danger,
                          ),
                        ),
                      ),
                    FilledButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(unsaved ? 'save' : 'continue'),
                      child: Text(
                        unsaved
                            ? context.l10n.save
                            : context.l10n.continue_action,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    workspace.setPendingHighlights(const []);
    if (approved == 'save') {
      final result = await workspace.run('file.save');
      if (result.isOk) {
        request.approve();
      } else {
        request.reject();
      }
    } else if (approved == 'continue' || approved == 'discard') {
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
    final assistant = ref.watch(assistantPaneProvider);
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
                assistantOpen: assistant.isOpen,
                onTogglePalette: () => ref
                    .read(paletteOpenProvider.notifier)
                    .update((open) => !open),
                onToggleAssistant: ref
                    .read(assistantPaneProvider.notifier)
                    .toggle,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Row(
                          children: [
                            _ActivityBar(
                              activeViewId: sidebar.isOpen
                                  ? sidebar.viewId
                                  : '',
                              onSelect: ref
                                  .read(sidebarProvider.notifier)
                                  .select,
                            ),
                            if (sidebar.isOpen)
                              SizedBox(
                                width: sidebar.width,
                                child: ColoredBox(
                                  color: tokens.surface,
                                  child: _sidebarBody(
                                    sidebar.viewId,
                                    workspace,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Column(
                                children: [
                                  DocumentTabStrip(workspace: workspace),
                                  Expanded(child: _canvasArea(workspace)),
                                ],
                              ),
                            ),
                            if (assistant.isOpen)
                              SizedBox(
                                width: assistant.width,
                                child: ColoredBox(
                                  color: tokens.surface,
                                  child: AiPanel(
                                    controller: ref.watch(aiControllerProvider),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (sidebar.isOpen)
                          Positioned(
                            left: ShellSplitter.overlayOrigin(
                              FanCadTokens.activityBarWidth + sidebar.width,
                            ),
                            top: 0,
                            bottom: 0,
                            width: FanCadTokens.splitterHit,
                            child: Tooltip(
                              message: context.l10n.resize_reset_width,
                              waitDuration: const Duration(milliseconds: 500),
                              child: ShellSplitter(
                                key: const Key('sidebar-splitter'),
                                axis: Axis.vertical,
                                strong: true,
                                onDrag: (delta) => ref
                                    .read(sidebarProvider.notifier)
                                    .resize(sidebar.width + delta),
                                onDragEnd: ref
                                    .read(sidebarProvider.notifier)
                                    .commitWidth,
                                onDoubleTap: ref
                                    .read(sidebarProvider.notifier)
                                    .resetWidth,
                              ),
                            ),
                          ),
                        if (assistant.isOpen)
                          Positioned(
                            left: ShellSplitter.overlayOrigin(
                              constraints.maxWidth - assistant.width,
                            ),
                            top: 0,
                            bottom: 0,
                            width: FanCadTokens.splitterHit,
                            child: Tooltip(
                              message: context.l10n.resize_reset_width,
                              waitDuration: const Duration(milliseconds: 500),
                              child: ShellSplitter(
                                key: const Key('assistant-splitter'),
                                axis: Axis.vertical,
                                strong: true,
                                onDrag: (delta) => ref
                                    .read(assistantPaneProvider.notifier)
                                    .resize(assistant.width - delta),
                                onDragEnd: ref
                                    .read(assistantPaneProvider.notifier)
                                    .commitWidth,
                                onDoubleTap: ref
                                    .read(assistantPaneProvider.notifier)
                                    .resetWidth,
                              ),
                            ),
                          ),
                        if (paletteOpen)
                          CommandPalette(
                            workspace: workspace,
                            onDismiss: () =>
                                ref.read(paletteOpenProvider.notifier).state =
                                    false,
                          ),
                      ],
                    );
                  },
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
    final body = tab == null
        ? EmptyWorkspace(
            recentFiles: workspace.settings.getStringList(
              SettingsKeys.recentFiles,
            ),
            onOpenRecent: (path) =>
                workspace.run('file.open', args: {'path': path}),
            onOpen: () => workspace.run('file.open'),
            onNew: () => workspace.run('file.new'),
            onShowCommands: () =>
                ref.read(paletteOpenProvider.notifier).state = true,
          )
        : DocumentView(
            // Keyed by tab so switching tabs gets a fresh canvas state rather
            // than one holding another drawing's tessellation cache.
            key: ValueKey(tab.session.id),
            workspace: workspace,
            tab: tab,
            commandLineFocus: _commandFocus,
          );
    final sidebar = ref.watch(sidebarProvider);
    return CanvasHud(
      workspace: workspace,
      commandFocus: _commandFocus,
      historyOpen: sidebar.isOpen && sidebar.viewId == 'history',
      onOpenHistory: () => workspace.revealPanel('history'),
      child: Stack(
        children: [
          body,
          Positioned(
            right: FanCadTokens.space4,
            top: FanCadTokens.space3,
            child: _Notices(workspace: workspace),
          ),
        ],
      ),
    );
  }

  Widget _sidebarBody(String viewId, Workspace workspace) => switch (viewId) {
    'layers' => LayersPanel(workspace: workspace),
    'properties' => PropertiesPanel(workspace: workspace),
    'layouts' => LayoutsPanel(workspace: workspace),
    'history' => CommandLogPanel(workspace: workspace),
    'commands' => _CommandListPanel(
      workspace: workspace,
      onOpenPalette: () => ref.read(paletteOpenProvider.notifier).state = true,
    ),
    'plugins' => ExtensionsPanel(
      workspace: workspace,
      host: ref.watch(pluginHostProvider),
      folder: ref.watch(pluginsDirectoryProvider),
    ),
    'editor' => PluginEditorPanel(
      workspace: workspace,
      host: ref.watch(pluginHostProvider),
    ),
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
      ...chord(
        LogicalKeyboardKey.comma,
        () => workspace.run('workbench.preferences'),
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
      ...chord(
        LogicalKeyboardKey.keyI,
        () => workspace.run('view.isolateObjects'),
        shift: true,
      ),
      ...chord(
        LogicalKeyboardKey.keyH,
        () => workspace.run('view.hideObjects'),
        shift: true,
      ),
      ...chord(
        LogicalKeyboardKey.keyU,
        () => workspace.run('view.unisolateObjects'),
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
      const SingleActivator(LogicalKeyboardKey.f2): _commandFocus.requestFocus,
      const SingleActivator(LogicalKeyboardKey.home): () =>
          workspace.run('view.zoomExtents'),
      const SingleActivator(LogicalKeyboardKey.f3): () =>
          workspace.setSnapEnabled(!workspace.snapEngine.enabled),
      const SingleActivator(LogicalKeyboardKey.f8): () =>
          workspace.setOrtho(!workspace.snapEngine.tracking.ortho),
      const SingleActivator(LogicalKeyboardKey.f10): () =>
          workspace.setPolar(!workspace.snapEngine.tracking.polar),
      const SingleActivator(LogicalKeyboardKey.f7): () {
        final tab = workspace.active;
        if (tab != null) workspace.setShowGrid(!tab.showGrid);
      },
    };
  }
}

/// The vertical strip of view switchers on the left.
class _ActivityBar extends StatelessWidget {
  const _ActivityBar({required this.activeViewId, required this.onSelect});

  final String activeViewId;
  final ValueChanged<String> onSelect;

  static const List<({String id, IconData icon})> _views = [
    (id: 'layers', icon: Icons.layers_outlined),
    (id: 'properties', icon: Icons.tune),
    (id: 'layouts', icon: Icons.dashboard_outlined),
    (id: 'history', icon: Icons.history),
    (id: 'commands', icon: Icons.terminal),
    (id: 'plugins', icon: Icons.extension_outlined),
    (id: 'editor', icon: Icons.code),
  ];

  ({String label, String hint}) _copy(AppLocalizations l10n, String id) {
    return switch (id) {
      'layers' => (label: l10n.layers, hint: l10n.view_layers_hint),
      'properties' => (label: l10n.properties, hint: l10n.view_properties_hint),
      'layouts' => (label: l10n.layouts, hint: l10n.view_layouts_hint),
      'history' => (label: l10n.command_history, hint: l10n.view_history_hint),
      'commands' => (label: l10n.commands, hint: l10n.view_commands_hint),
      'plugins' => (label: l10n.extensions, hint: l10n.view_extensions_hint),
      _ => (label: l10n.re_editor, hint: l10n.view_editor_hint),
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    return Container(
      width: FanCadTokens.activityBarWidth,
      decoration: BoxDecoration(
        color: tokens.canvas,
        border: Border(right: BorderSide(color: tokens.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: FanCadTokens.space2),
          for (final view in _views)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: ShellIconButton(
                key: Key('activity-${view.id}'),
                icon: view.icon,
                tooltip: () {
                  final copy = _copy(l10n, view.id);
                  return activeViewId == view.id
                      ? '${l10n.hide_view(copy.label)}\n${copy.hint}'
                      : '${copy.label}\n${copy.hint}';
                }(),
                size: FanCadTokens.activityBarWidth,
                iconSize: FanCadTokens.iconLarge,
                isActive: activeViewId == view.id,
                showActiveBar: true,
                onPressed: () => onSelect(view.id),
              ),
            ),
          const Spacer(),
          ShellIconButton(
            icon: Icons.menu,
            tooltip: activeViewId.isEmpty
                ? '${l10n.show_sidebar}  ${shellShortcut('B')}'
                : '${l10n.hide_sidebar}  ${shellShortcut('B')}',
            size: FanCadTokens.activityBarWidth,
            iconSize: FanCadTokens.iconLarge,
            onPressed: () =>
                onSelect(activeViewId.isEmpty ? _views.first.id : activeViewId),
          ),
          const SizedBox(height: FanCadTokens.space2),
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
  const _CommandListPanel({
    required this.workspace,
    required this.onOpenPalette,
  });

  final Workspace workspace;
  final VoidCallback onOpenPalette;

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
    final l10n = context.l10n;
    final commands = searchCommandsLocalized(
      widget.workspace.commands,
      _query,
      l10n,
      limit: 500,
    );
    final lastId = widget.workspace.commands.lastCommandId;
    final last = _query.trim().isEmpty && lastId != null
        ? widget.workspace.commands.find(lastId)
        : null;
    final byCategory = <String, List<CommandDescriptor>>{};
    for (final descriptor in commands) {
      if (last != null && descriptor.id == last.id) continue;
      byCategory.putIfAbsent(descriptor.category, () => []).add(descriptor);
    }
    final categories = byCategory.keys.toList()..sort();

    return Column(
      children: [
        PanelHeader(
          title: l10n.commands,
          actions: [
            ShellIconButton(
              icon: Icons.search,
              tooltip:
                  '${l10n.command_palette}  ${shellShortcut('P', shift: true)}',
              iconSize: FanCadTokens.iconMedium,
              onPressed: widget.onOpenPalette,
            ),
          ],
        ),
        Container(
          height: FanCadTokens.statusBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space3),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: ShellTextField(
            controller: _filter,
            hintText: l10n.filter_commands,
            style: tokens.bodyStyle,
            prefix: Padding(
              padding: const EdgeInsets.only(right: FanCadTokens.space2),
              child: Icon(
                Icons.search,
                size: FanCadTokens.iconSmall,
                color: tokens.textFaint,
              ),
            ),
            onChanged: (value) => setState(() => _query = value),
            suffix: _query.isEmpty
                ? null
                : ShellIconButton(
                    icon: Icons.close,
                    size: 18,
                    iconSize: FanCadTokens.iconSmall,
                    tooltip: l10n.clear_filter,
                    onPressed: () {
                      _filter.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
        Expanded(
          child: commands.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(FanCadTokens.space4),
                    child: Text(
                      _query.trim().isEmpty
                          ? l10n.no_commands_registered
                          : l10n.no_commands_match(_query.trim()),
                      style: tokens.labelStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  children: [
                    if (last != null)
                      PanelSection(
                        title: l10n.last_used,
                        children: [_commandRow(tokens, last)],
                      ),
                    for (final category in categories)
                      PanelSection(
                        title: l10n.commandCategory(category),
                        trailing: Text(
                          '${byCategory[category]!.length}',
                          style: tokens.labelStyle,
                        ),
                        children: [
                          for (final descriptor in byCategory[category]!)
                            _commandRow(tokens, descriptor),
                        ],
                      ),
                    const SizedBox(height: FanCadTokens.space4),
                  ],
                ),
        ),
        Container(
          height: FanCadTokens.statusBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space3),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: tokens.border)),
          ),
          child: Text(
            '${l10n.commandCount(commands.length)}'
            '${_query.trim().isEmpty ? '' : l10n.commands_matching}',
            style: tokens.labelStyle,
          ),
        ),
      ],
    );
  }

  Widget _commandRow(FanCadTokens tokens, CommandDescriptor descriptor) {
    final l10n = context.l10n;
    final hint = [
      if (descriptor.description.isNotEmpty) descriptor.description,
      if (descriptor.aliases.isNotEmpty)
        l10n.alias_named(descriptor.aliases.first.toUpperCase()),
      if (descriptor.defaultKeybinding != null)
        descriptor.defaultKeybinding!.toUpperCase(),
    ].join('\n');
    final row = ShellRow(
      isSelected: widget.workspace.runningCommand == descriptor.id,
      onTap: () => widget.workspace.run(descriptor.id),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.commandTitle(descriptor.id, descriptor.title),
              style: tokens.bodyStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (descriptor.defaultKeybinding != null)
            Text(
              descriptor.defaultKeybinding!.toUpperCase(),
              style: tokens.monoStyle.copyWith(
                fontSize: 10.5,
                color: tokens.textFaint,
              ),
            )
          else if (descriptor.aliases.isNotEmpty)
            Text(
              descriptor.aliases.first.toUpperCase(),
              style: tokens.monoStyle.copyWith(
                fontSize: 10.5,
                color: tokens.textFaint,
              ),
            ),
        ],
      ),
    );
    if (hint.isEmpty) return row;
    return Tooltip(
      message: hint,
      waitDuration: const Duration(milliseconds: 500),
      child: row,
    );
  }
}

/// Transient notifications, stacked above the status bar.
class _Notices extends StatelessWidget {
  const _Notices({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final notices = workspace.notices.reversed.take(3).toList();
    if (notices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final notice in notices)
          Padding(
            padding: const EdgeInsets.only(top: FanCadTokens.space2),
            child: _NoticeToast(
              key: ValueKey(
                '${notice.at.microsecondsSinceEpoch}:${notice.message}',
              ),
              workspace: workspace,
              notice: notice,
            ),
          ),
      ],
    );
  }
}

/// A toast that can be copied, dismissed, and — for non-errors — fades itself.
class _NoticeToast extends StatefulWidget {
  const _NoticeToast({
    super.key,
    required this.workspace,
    required this.notice,
  });

  final Workspace workspace;
  final Notice notice;

  @override
  State<_NoticeToast> createState() => _NoticeToastState();
}

class _NoticeToastState extends State<_NoticeToast> {
  Timer? _timer;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _arm() {
    _timer?.cancel();
    if (widget.notice.isError) return;
    _timer = Timer(const Duration(seconds: 6), () {
      if (mounted && !_hovered) {
        widget.workspace.dismissNotice(widget.notice);
      }
    });
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.notice.message));
    widget.workspace.dismissNotice(widget.notice);
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        _timer?.cancel();
      },
      onExit: (_) {
        setState(() => _hovered = false);
        _arm();
      },
      child: ShellToast(
        message: notice.message,
        tone: notice.isError ? ShellTone.danger : ShellTone.success,
        onTap: _copy,
        tapTooltip: context.l10n.copy_and_dismiss,
        onDismiss: () => widget.workspace.dismissNotice(notice),
        dismissTooltip: context.l10n.dismiss,
      ),
    );
  }
}
