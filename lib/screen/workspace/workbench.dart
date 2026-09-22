import 'dart:async';

import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../commands/keybindings.dart';
import '../../l10n/l10n.dart';
import '../../models/command_line.dart';
import '../../models/workspace.dart';
import '../../services/assistant.dart';
import '../../services/command_line.dart';
import '../../services/plugin.dart';
import '../../services/sidebar.dart';
import '../../services/workspace.dart';
import '../assistant/ai_panel.dart';
import '../command_line/command_line.dart';
import '../command_line/command_palette.dart';
import '../plugin/extensions_panel.dart';
import '../plugin/plugin_editor_panel.dart';
import '../settings/settings_dialog.dart';
import '../widgets/activity_bar.dart';
import '../widgets/title_bar.dart';
import '../widgets/tokens.dart';
import '../widgets/widgets.dart';
import 'canvas_hud.dart';
import 'document_view.dart';
import 'empty_workspace.dart';
import 'layers_panel.dart';
import 'layouts_panel.dart';
import 'properties_panel.dart';

/// The drawing window.
///
/// Laid out as a title bar, activity bar, sidebar, tab strip, drawing and
/// status bar around one flexible canvas. Operations and the command line
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

  static const _escapeChannel = MethodChannel('fancad/escape');

  StreamSubscription<String>? _panelReveals;
  StreamSubscription<PendingApproval>? _approvals;
  StreamSubscription<CommandRegistry>? _commandChanges;
  bool _listeningForWindowClose = false;
  bool _closingWindow = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareEscape);
    _escapeChannel.setMethodCallHandler(_onNativeEscape);
    // Subscribed in initState rather than in build so a rebuild does not
    // register a second listener and pop two dialogs for one request.
    final workspace = ref.read(workspaceNotifierProvider.notifier);
    _panelReveals = workspace.panelReveals.listen((panelId) {
      if (panelId == 'ai') {
        ref.read(assistantNotifierProvider.notifier).setAssistantOpen(true);
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
      ref.read(sidebarNotifierProvider.notifier).reveal(panelId);
    });
    _approvals = workspace.approvals.listen(_showApproval);
    _commandChanges = workspace.commands.changes.listen((_) {
      if (mounted) setState(() {});
    });
    unawaited(_bindWindowClose());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _commandFocus.requestFocus();
      // The extension host is started after the first frame so third-party
      // code cannot sit between launch and a usable window.
      unawaited(_startPlugins());
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareEscape);
    _escapeChannel.setMethodCallHandler(null);
    if (_listeningForWindowClose) {
      windowManager.removeListener(this);
    }
    _panelReveals?.cancel();
    _approvals?.cancel();
    _commandChanges?.cancel();
    _commandFocus.dispose();
    super.dispose();
  }

  Future<void> _startPlugins() async {
    await ref.read(pluginNotifierProvider.notifier).start();
  }

  /// Text fields on macOS swallow Escape before Focus.onKeyEvent. This runs
  /// earlier, so a canvas click that focused the command line still cancels.
  bool _onHardwareEscape(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    if (ref.read(commandLineNotifierProvider).paletteOpen) return false;
    ref.read(workspaceNotifierProvider.notifier).cancelActive();
    return true;
  }

  Future<void> _onNativeEscape(MethodCall call) async {
    if (call.method != 'escape') return;
    ref.read(workspaceNotifierProvider.notifier).cancelActive();
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
      final workspace = ref.read(workspaceNotifierProvider.notifier);
      while (workspace.tabs.isNotEmpty) {
        if (!mounted) return;
        final dirtyIndex = workspace.tabs.indexWhere((tab) => tab.isDirty);
        if (dirtyIndex >= 0 &&
            ref.read(workspaceNotifierProvider).activeIndex != dirtyIndex) {
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

  Future<void> _showApproval(PendingApproval pending) async {
    final request = pending.request;
    final workspace = ref.read(workspaceNotifierProvider.notifier);
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
                Text(request.title, style: tokens.dialogTitleStyle),
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
    if (approved == 'save') {
      final result = await workspace.run('file.save');
      if (result.isOk) {
        pending.approve();
      } else {
        pending.reject();
      }
    } else if (approved == 'continue' || approved == 'discard') {
      pending.approve();
    } else {
      pending.reject();
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.read(workspaceNotifierProvider.notifier);
    ref.watch(
      workspaceNotifierProvider.select((s) => (s.tabStrip, s.recentFiles)),
    );
    ref.watch(pluginNotifierProvider.select((s) => s.epoch));
    return _buildWindow(context, workspace);
  }

  Widget _buildWindow(BuildContext context, Workspace workspace) {
    final tokens = context.tokens;
    final sidebar = ref.watch(sidebarNotifierProvider);
    final assistant = ref.watch(
      assistantNotifierProvider.select((s) => s.pane),
    );
    final paletteOpen = ref.watch(
      commandLineNotifierProvider.select((s) => s.paletteOpen),
    );

    return CallbackShortcuts(
      bindings: _shortcuts(workspace),
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          // Handle Escape here so a click on chrome cannot let the key fall
          // through to the OS, which would leave native fullscreen.
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey != LogicalKeyboardKey.escape) {
            return KeyEventResult.ignored;
          }
          workspace.cancelActive();
          return KeyEventResult.handled;
        },
        // Material rather than a bare ColoredBox because the window hosts
        // Material descendants — text fields, tooltips, dialogs — and they
        // require an ancestor to paint on.
        child: Material(
          color: tokens.surface,
          child: Column(
            children: [
              TitleBar(
                assistantOpen: assistant.isOpen,
                onTogglePalette: () => ref
                    .read(commandLineNotifierProvider.notifier)
                    .togglePalette(),
                onToggleAssistant: ref
                    .read(assistantNotifierProvider.notifier)
                    .toggleAssistant,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Row(
                          children: [
                            ActivityBar(
                              activeViewId: sidebar.isOpen
                                  ? sidebar.viewId
                                  : '',
                              onSelect: ref
                                  .read(sidebarNotifierProvider.notifier)
                                  .select,
                              onOpenSettings: () {
                                unawaited(showSettingsDialog(context));
                              },
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
                                    controller: ref.read(
                                      assistantNotifierProvider.notifier,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (sidebar.isOpen)
                          Positioned(
                            left: FanCadSplitter.overlayOrigin(
                              FanCadTokens.activityBarWidth + sidebar.width,
                            ),
                            top: 0,
                            bottom: 0,
                            width: CommandLineLayout.splitterHit,
                            child: Tooltip(
                              message: context.l10n.resize_reset_width,
                              waitDuration: const Duration(milliseconds: 500),
                              child: FanCadSplitter(
                                key: const Key('sidebar-splitter'),
                                axis: Axis.vertical,
                                onDrag: (delta) => ref
                                    .read(sidebarNotifierProvider.notifier)
                                    .resize(sidebar.width + delta),
                                onDragEnd: ref
                                    .read(sidebarNotifierProvider.notifier)
                                    .commitWidth,
                                onDoubleTap: ref
                                    .read(sidebarNotifierProvider.notifier)
                                    .resetWidth,
                              ),
                            ),
                          ),
                        if (assistant.isOpen)
                          Positioned(
                            left: FanCadSplitter.overlayOrigin(
                              constraints.maxWidth - assistant.width,
                            ),
                            top: 0,
                            bottom: 0,
                            width: CommandLineLayout.splitterHit,
                            child: Tooltip(
                              message: context.l10n.resize_reset_width,
                              waitDuration: const Duration(milliseconds: 500),
                              child: FanCadSplitter(
                                key: const Key('assistant-splitter'),
                                axis: Axis.vertical,
                                onDrag: (delta) => ref
                                    .read(assistantNotifierProvider.notifier)
                                    .resizeAssistant(assistant.width - delta),
                                onDragEnd: ref
                                    .read(assistantNotifierProvider.notifier)
                                    .commitAssistantWidth,
                                onDoubleTap: ref
                                    .read(assistantNotifierProvider.notifier)
                                    .resetAssistantWidth,
                              ),
                            ),
                          ),
                        if (paletteOpen)
                          CommandPalette(
                            workspace: workspace,
                            onDismiss: () => ref
                                .read(commandLineNotifierProvider.notifier)
                                .setPaletteOpen(false),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const StatusBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _canvasArea(Workspace workspace) {
    final tab = workspace.active;
    final showStart = tab == null || tab.isStartPage;
    final body = showStart
        ? EmptyWorkspace(
            recentFiles: ref.read(workspaceNotifierProvider).recentFiles,
            onOpenRecent: (path) =>
                workspace.run('file.open', args: {'path': path}),
            onOpen: () => workspace.run('file.open'),
            onNew: () => workspace.run('file.new'),
            onShowCommands: () => ref
                .read(commandLineNotifierProvider.notifier)
                .setPaletteOpen(true),
          )
        : DocumentView(
            // Keyed by tab so switching tabs gets a fresh canvas state rather
            // than one holding another drawing's tessellation cache.
            key: ValueKey(tab.session.id),
            workspace: workspace,
            tab: tab,
            commandLineFocus: _commandFocus,
            onAddSelectionToChat: () {
              ref.read(assistantNotifierProvider.notifier).pinSelection();
              workspace.revealPanel('ai');
            },
            onStopAssistant: () =>
                ref.read(assistantNotifierProvider.notifier).stop(),
          );
    final sidebar = ref.watch(sidebarNotifierProvider);
    final stack = Stack(
      children: [
        body,
        Positioned(
          right: FanCadTokens.space4,
          top: FanCadTokens.space3,
          child: _Notices(workspace: workspace),
        ),
      ],
    );
    if (showStart) return stack;
    return CanvasHud(
      workspace: workspace,
      commandFocus: _commandFocus,
      historyOpen: sidebar.isOpen && sidebar.viewId == 'history',
      onOpenHistory: () => workspace.revealPanel('history'),
      child: stack,
    );
  }

  Widget _sidebarBody(String viewId, Workspace workspace) => switch (viewId) {
    'layers' => LayersPanel(workspace: workspace),
    'properties' => PropertiesPanel(workspace: workspace),
    'layouts' => LayoutsPanel(workspace: workspace),
    'history' => CommandLogPanel(workspace: workspace),
    'commands' => _CommandListPanel(
      workspace: workspace,
      onOpenPalette: () =>
          ref.read(commandLineNotifierProvider.notifier).setPaletteOpen(true),
    ),
    'plugins' => ExtensionsPanel(workspace: workspace),
    'editor' => PluginEditorPanel(workspace: workspace),
    _ => const SizedBox.shrink(),
  };

  Map<ShortcutActivator, VoidCallback> _shortcuts(Workspace workspace) {
    final pluginKeys = [
      if (ref.read(pluginNotifierProvider.notifier).host case final host?)
        for (final binding in host.contributions.keybindings)
          (binding.key, binding.commandId),
    ];
    return {
      ...commandShortcutBindings(
        workspace.commands,
        workspace.run,
        extra: pluginKeys,
      ),
      ..._windowShortcuts(workspace),
    };
  }

  /// Chrome that is not a command: palette, sidebar, command-line focus, and
  /// the F-key drawing aids.
  Map<ShortcutActivator, VoidCallback> _windowShortcuts(Workspace workspace) {
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
        () => ref.read(commandLineNotifierProvider.notifier).togglePalette(),
        shift: true,
      ),
      ...chord(
        LogicalKeyboardKey.keyB,
        ref.read(sidebarNotifierProvider.notifier).toggle,
      ),
      ...chord(LogicalKeyboardKey.keyU, () {
        ref.read(assistantNotifierProvider.notifier).pinSelection();
        workspace.revealPanel('ai');
      }, shift: true),
      const SingleActivator(LogicalKeyboardKey.f2): _commandFocus.requestFocus,
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

/// A browsable list of every registered command.
///
/// Worth a panel of its own because it is the honest answer to "what can this
/// application do", and because it is the same list the assistant sees.
class _CommandListPanel extends ConsumerStatefulWidget {
  const _CommandListPanel({
    required this.workspace,
    required this.onOpenPalette,
  });

  final Workspace workspace;
  final VoidCallback onOpenPalette;

  @override
  ConsumerState<_CommandListPanel> createState() => _CommandListPanelState();
}

class _CommandListPanelState extends ConsumerState<_CommandListPanel> {
  final TextEditingController _filter = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = ref.watch(
      workspaceNotifierProvider.select((s) => s.runningCommand),
    );
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
            FanCadIconButton(
              icon: Icons.search,
              tooltip:
                  '${l10n.command_palette}  ${formatKeybinding('ctrl+shift+p')}',
              iconSize: FanCadTokens.iconMedium,
              onPressed: widget.onOpenPalette,
            ),
          ],
        ),
        Container(
          height: FanCadTokens.filterBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space3),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: FanCadTextField(
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
                : FanCadIconButton(
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
                        children: [_commandRow(tokens, last, running)],
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
                            _commandRow(tokens, descriptor, running),
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

  Widget _commandRow(
    FanCadTokens tokens,
    CommandDescriptor descriptor,
    String? running,
  ) {
    final l10n = context.l10n;
    final hint = [
      if (descriptor.description.isNotEmpty)
        l10n.commandDescription(descriptor.id, descriptor.description),
      if (descriptor.aliases.isNotEmpty)
        l10n.alias_named(descriptor.aliases.first.toUpperCase()),
      if (descriptor.defaultKeybinding != null)
        formatKeybinding(descriptor.defaultKeybinding!),
    ].join('\n');
    final row = FanCadRow(
      isSelected: running == descriptor.id,
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
              formatKeybinding(descriptor.defaultKeybinding!),
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

/// Transient notifications, stacked in the canvas corner.
class _Notices extends ConsumerWidget {
  const _Notices({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref
        .watch(workspaceNotifierProvider.select((s) => s.notices))
        .reversed
        .take(3)
        .toList();
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
  final NoticeModel notice;

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
      child: FanCadToast(
        message: notice.message,
        tone: notice.isError ? FanCadTone.danger : FanCadTone.success,
        onTap: _copy,
        tapTooltip: context.l10n.copy_and_dismiss,
        onDismiss: () => widget.workspace.dismissNotice(notice),
        dismissTooltip: context.l10n.dismiss,
      ),
    );
  }
}
