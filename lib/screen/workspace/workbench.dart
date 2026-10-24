import 'dart:async';

import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../commands/keybindings.dart';
import '../../l10n/l10n.dart';
import '../../models/assistant.dart';
import '../../models/layout.dart';
import '../../models/sidebar.dart';
import '../../models/workspace.dart';
import '../../services/assistant.dart';
import '../../services/command_line.dart';
import '../../services/layout.dart';
import '../../services/workspace.dart';
import '../assistant/ai_panel.dart';
import '../command_line/command_line.dart';
import '../command_line/command_palette.dart';
import '../plugin/scripts_panel.dart';
import '../settings/settings_dialog.dart';
import '../widgets/activity_bar.dart';
import '../widgets/title_bar.dart';
import '../widgets/tokens.dart';
import '../widgets/widgets.dart';
import 'blocks_panel.dart';
import 'canvas_hud.dart';
import 'document_view.dart';
import 'empty_workspace.dart';
import 'export_panel.dart';
import 'layers_panel.dart';
import 'layouts_panel.dart';
import 'properties_panel.dart';

/// The drawing window.
///
/// Laid out as a title bar, then one split row: the sidebar, the document
/// tabs over the drawing, and the assistant. Operations and the command line
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
  late final FanCadSplitController _sidebarSplit;
  late final FanCadSplitController _assistantSplit;
  bool _listeningForWindowClose = false;
  bool _closingWindow = false;

  @override
  void initState() {
    super.initState();
    final layout = ref.read(layoutNotifierProvider);
    _sidebarSplit = FanCadSplitController(
      extent: layout.sidebarWidth,
      minExtent: SidebarLayout.minWidth,
      maxExtent: SidebarLayout.maxWidth,
    );
    _assistantSplit = FanCadSplitController(
      extent: layout.assistantWidth,
      minExtent: AssistantPaneLayout.minWidth,
      maxExtent: AssistantPaneLayout.maxWidth,
    );
    _sidebarSplit.addListener(_noteViewOcclusion);
    _assistantSplit.addListener(_noteViewOcclusion);
    _noteViewOcclusion();
    HardwareKeyboard.instance.addHandler(_onHardwareEscape);
    HardwareKeyboard.instance.addHandler(_onHardwareCopy);
    HardwareKeyboard.instance.addHandler(_onHardwareFind);
    _escapeChannel.setMethodCallHandler(_onNativeEscape);
    // Subscribed in initState rather than in build so a rebuild does not
    // register a second listener and pop two dialogs for one request.
    final workspace = ref.read(workspaceNotifierProvider.notifier);
    _panelReveals = workspace.panelReveals.listen((panelId) {
      if (panelId == 'ai') {
        ref.read(layoutNotifierProvider.notifier).setAssistantOpen(true);
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
      ref.read(layoutNotifierProvider.notifier).reveal(panelId);
    });
    _approvals = workspace.approvals.listen(_showApproval);
    unawaited(_bindWindowClose());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _commandFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareEscape);
    HardwareKeyboard.instance.removeHandler(_onHardwareCopy);
    HardwareKeyboard.instance.removeHandler(_onHardwareFind);
    _escapeChannel.setMethodCallHandler(null);
    if (_listeningForWindowClose) {
      windowManager.removeListener(this);
    }
    _panelReveals?.cancel();
    _approvals?.cancel();
    _sidebarSplit.removeListener(_noteViewOcclusion);
    _assistantSplit.removeListener(_noteViewOcclusion);
    _sidebarSplit.dispose();
    _assistantSplit.dispose();
    _commandFocus.dispose();
    super.dispose();
  }

  /// Text fields on macOS swallow Ctrl+C before Focus.onKeyEvent. A collapsed
  /// field, which is where a canvas click leaves focus, copies the drawing
  /// selection here instead of starting COPYCLIP. The dynamic-input readout
  /// stays fully selected so the next digit replaces it; that is not a text
  /// selection the user asked to copy.
  bool _onHardwareCopy(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyC) return false;
    final keys = HardwareKeyboard.instance;
    final primary = keys.isControlPressed || keys.isMetaPressed;
    if (!primary || keys.isAltPressed || keys.isShiftPressed) return false;
    if (_textFieldHasSelection()) return false;
    ref.read(workspaceNotifierProvider.notifier).copySelection();
    return true;
  }

  bool _textFieldHasSelection() {
    final nodeContext = FocusManager.instance.primaryFocus?.context;
    if (nodeContext == null || _insideDynamicInput(nodeContext)) return false;
    final editor = nodeContext.findAncestorStateOfType<EditableTextState>();
    if (editor == null) return false;
    final selection = editor.textEditingValue.selection;
    return selection.isValid && !selection.isCollapsed;
  }

  bool _insideDynamicInput(BuildContext context) {
    var found = false;
    context.visitAncestorElements((element) {
      if (element.widget.key == const Key('dynamic-input-hud')) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  /// Text fields on macOS swallow Escape before Focus.onKeyEvent. This runs
  /// earlier, so a canvas click that focused the command line still cancels.
  bool _onHardwareEscape(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    if (ref.read(commandLineNotifierProvider).paletteOpen) return false;
    final workspace = ref.read(workspaceNotifierProvider.notifier);
    final tab = workspace.active;
    if (tab != null &&
        !tab.isStartPage &&
        !tab.isOpeningShell &&
        tab.textSearch.handleEscape()) {
      return true;
    }
    workspace.cancelActive();
    return true;
  }

  /// Ctrl/Cmd+F opens drawing search on the command dock. In-place edit and
  /// the attribute dialog keep the chord. The command field is the search
  /// field, so the chord still switches it.
  bool _onHardwareFind(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyF) return false;
    final keys = HardwareKeyboard.instance;
    final primary = keys.isControlPressed || keys.isMetaPressed;
    if (!primary || keys.isAltPressed || keys.isShiftPressed) return false;
    // The command field stays focused so a verb can be typed without a click.
    // That field is the search field too, so the chord still switches mode.
    if (_focusInEditableText() &&
        FocusManager.instance.primaryFocus != _commandFocus) {
      return false;
    }
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    final workspace = ref.read(workspaceNotifierProvider.notifier);
    final tab = workspace.active;
    if (tab == null || tab.isStartPage || tab.isOpeningShell) return false;
    ref.read(commandLineNotifierProvider.notifier).setPaletteOpen(false);
    tab.textSearch.request();
    _commandFocus.requestFocus();
    return true;
  }

  bool _focusInEditableText() {
    final nodeContext = FocusManager.instance.primaryFocus?.context;
    if (nodeContext == null) return false;
    return nodeContext.findAncestorStateOfType<EditableTextState>() != null;
  }

  Future<void> _onNativeEscape(MethodCall call) async {
    if (call.method != 'escape') return;
    final workspace = ref.read(workspaceNotifierProvider.notifier);
    final tab = workspace.active;
    if (tab != null &&
        !tab.isStartPage &&
        !tab.isOpeningShell &&
        tab.textSearch.handleEscape()) {
      return;
    }
    workspace.cancelActive();
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
      _persistLayout();
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
      builder: (context) {
        // The stroke is painted inside the box, so the outline reads shorter
        // than the filled button unless the box is taller by the stroke.
        final outlined = OutlinedButton.styleFrom(
          foregroundColor: tokens.text,
          minimumSize: const Size(0, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space2),
          side: BorderSide(color: tokens.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FanCadTokens.radiusSmall),
          ),
        );
        return Dialog(
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
                      if (unsaved)
                        OutlinedButton(
                          style: outlined.copyWith(
                            foregroundColor: WidgetStatePropertyAll(
                              tokens.danger,
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop('discard'),
                          child: Text(
                            context.l10n.dont_save,
                            style: tokens.bodyStyle.copyWith(
                              color: tokens.danger,
                            ),
                          ),
                        ),
                      const Spacer(),
                      OutlinedButton(
                        style: outlined,
                        onPressed: () => Navigator.of(context).pop('cancel'),
                        child: Text(
                          context.l10n.cancel,
                          style: tokens.bodyStyle,
                        ),
                      ),
                      const SizedBox(width: FanCadTokens.space2),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                            horizontal: FanCadTokens.space2,
                          ),
                        ),
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
        );
      },
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
    return _buildWindow(context, workspace);
  }

  Widget _buildWindow(BuildContext context, Workspace workspace) {
    final tokens = context.tokens;
    final layout = ref.watch(
      layoutNotifierProvider.select(
        (s) => (
          sidebarView: s.sidebarView,
          sidebarOpen: s.sidebarOpen,
          assistantOpen: s.assistantOpen,
        ),
      ),
    );
    final exporting = ref.watch(
      workspaceNotifierProvider.select(
        (s) => s.openExportOf(s.activeSessionId ?? '') != null,
      ),
    );
    ref.listen(layoutNotifierProvider.select((s) => s.sidebarOpen), (
      previous,
      next,
    ) {
      if (previous == true && !next) {
        ref.read(workspaceNotifierProvider.notifier).endExport();
      }
    });
    final paletteOpen = ref.watch(
      commandLineNotifierProvider.select((s) => s.paletteOpen),
    );
    final activeId = ref.watch(
      workspaceNotifierProvider.select((s) => s.activeSessionId),
    );
    if (activeId != null) {
      ref.watch(
        documentTabNotifierProvider(activeId).select((s) => s.selectionEpoch),
      );
    }
    ref.watch(workspaceNotifierProvider.select((s) => s.runningCommand));

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
          ref.read(assistantNotifierProvider.notifier).stopBboxPick();
          final tab = workspace.active;
          if (tab != null &&
              !tab.isStartPage &&
              !tab.isOpeningShell &&
              tab.textSearch.handleEscape()) {
            return KeyEventResult.handled;
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
                assistantOpen: layout.assistantOpen,
                onTogglePalette: () => ref
                    .read(commandLineNotifierProvider.notifier)
                    .togglePalette(),
                onToggleAssistant: ref
                    .read(layoutNotifierProvider.notifier)
                    .toggleAssistant,
              ),
              Expanded(
                child: Stack(
                  children: [
                    Row(
                      children: [
                        ActivityBar(
                          activeViewId: !layout.sidebarOpen
                              ? ''
                              : exporting
                              ? 'export'
                              : layout.sidebarView,
                          onSelect: (id) => _selectSidebar(id),
                          onOpenSettings: () {
                            unawaited(showSettingsDialog(context));
                          },
                        ),
                        Expanded(
                          child: _splitPanes(context, workspace, layout),
                        ),
                      ],
                    ),
                    if (paletteOpen)
                      CommandPalette(
                        workspace: workspace,
                        onDismiss: () => ref
                            .read(commandLineNotifierProvider.notifier)
                            .setPaletteOpen(false),
                      ),
                  ],
                ),
              ),
              const StatusBar(),
            ],
          ),
        ),
      ),
    );
  }

  /// Export is a per-drawing pane. It is not stored in [LayoutModel.sidebarView],
  /// so the next launch still opens on the last real sidebar.
  void _selectSidebar(String id) {
    final workspace = ref.read(workspaceNotifierProvider.notifier);
    final layout = ref.read(layoutNotifierProvider.notifier);
    final state = ref.read(workspaceNotifierProvider);
    final exporting = state.openExportOf(state.activeSessionId ?? '') != null;
    if (id == 'export') {
      final open = ref.read(layoutNotifierProvider).sidebarOpen;
      if (exporting && open) {
        workspace.endExport();
        layout.setSidebarOpen(false);
        return;
      }
      if (exporting) {
        layout.setSidebarOpen(true);
        return;
      }
      final tab = workspace.active;
      if (tab == null || tab.isStartPage || tab.isOpeningShell) return;
      workspace.beginExport();
      return;
    }
    if (exporting) {
      workspace.suspendExport();
      final current = ref.read(layoutNotifierProvider);
      if (!current.sidebarOpen || current.sidebarView != id) {
        layout.reveal(id);
      }
      return;
    }
    layout.select(id);
  }

  /// Writes the live pane widths the camera does not follow.
  ///
  /// The controllers already notify the split. This only stores the crop, so
  /// a drag does not rebuild the canvas.
  void _noteViewOcclusion() {
    final layout = ref.read(layoutNotifierProvider);
    ref
        .read(workspaceNotifierProvider.notifier)
        .noteViewOcclusion(
          left: layout.sidebarOpen ? _sidebarSplit.extent : 0,
          right: layout.assistantOpen ? _assistantSplit.extent : 0,
        );
  }

  Widget _splitPanes(
    BuildContext context,
    Workspace workspace,
    ({String sidebarView, bool sidebarOpen, bool assistantOpen}) layout,
  ) {
    final exporting = ref.watch(
      workspaceNotifierProvider.select(
        (state) => state.openExportOf(state.activeSessionId ?? '') != null,
      ),
    );
    final tooltip = context.l10n.resize_reset_width;
    _noteViewOcclusion();
    final shell = ref.watch(
      workspaceNotifierProvider.select((s) {
        final active = s.active;
        return (
          start: active == null || active.isStartPage,
          loading: active?.loading ?? false,
          openError: active?.openError ?? '',
        );
      }),
    );
    final showStart = shell.start;
    final showOpening =
        !showStart && (shell.loading || shell.openError.isNotEmpty);
    // The document tabs share this row with the sidebar header and the
    // assistant tabs. The drawing itself stays full-bleed under the side
    // panes, starting just below that row.
    final hasDocumentTabs = ref.watch(
      workspaceNotifierProvider.select((s) => s.sessionIds.isNotEmpty),
    );
    final center = Column(
      children: [
        DocumentTabStrip(workspace: workspace),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (showStart)
                EmptyWorkspace(
                  onOpenRecent: (path) =>
                      workspace.run('file.open', args: {'path': path}),
                  onOpen: () => workspace.run('file.open'),
                  onNew: () => workspace.run('file.new'),
                  onShowCommands: () => ref
                      .read(commandLineNotifierProvider.notifier)
                      .setPaletteOpen(true),
                )
              else if (showOpening)
                _OpeningCanvas(workspace: workspace)
              else ...[
                CanvasHud(workspace: workspace, commandFocus: _commandFocus),
                CanvasViewportChrome(
                  workspace: workspace,
                  onStopAssistant: () =>
                      ref.read(assistantNotifierProvider.notifier).stop(),
                ),
              ],
              Positioned(
                right: FanCadTokens.space4,
                top: FanCadTokens.space3,
                child: _Notices(workspace: workspace),
              ),
            ],
          ),
        ),
      ],
    );
    Widget viewport = center;
    if (layout.sidebarOpen) {
      viewport = FanCadSplit(
        controller: _sidebarSplit,
        flexMinExtent: ViewportLayout.minWidth,
        tooltip: tooltip,
        handleKey: const Key('sidebar-splitter'),
        onDoubleTap: () => _sidebarSplit.extent = SidebarLayout.defaultWidth,
        first: ColoredBox(
          color: context.tokens.surface,
          child: exporting
              ? ExportPanel(workspace: workspace)
              : _sidebarBody(layout.sidebarView, workspace),
        ),
        second: viewport,
      );
    }
    if (layout.assistantOpen) {
      viewport = FanCadSplit(
        controller: _assistantSplit,
        reverse: true,
        flexMinExtent: layout.sidebarOpen
            ? SidebarLayout.minWidth + ViewportLayout.minWidth
            : ViewportLayout.minWidth,
        tooltip: tooltip,
        handleKey: const Key('assistant-splitter'),
        onDoubleTap: () =>
            _assistantSplit.extent = AssistantPaneLayout.defaultWidth,
        first: viewport,
        second: ColoredBox(
          color: context.tokens.surface,
          child: AiPanel(
            controller: ref.read(assistantNotifierProvider.notifier),
          ),
        ),
      );
    }
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: hasDocumentTabs ? FanCadTokens.tabBarHeight : 0,
          ),
          child: _canvasArea(workspace),
        ),
        viewport,
      ],
    );
  }

  /// Copies the live sash widths into the layout and writes the file.
  ///
  /// Widths stay on the split controllers until the process is leaving.
  void _persistLayout() {
    final layoutNotifier = ref.read(layoutNotifierProvider.notifier);
    layoutNotifier.resizeSidebar(_sidebarSplit.extent);
    layoutNotifier.resizeAssistant(_assistantSplit.extent);
    layoutNotifier.persist();
  }

  Widget _canvasArea(Workspace workspace) {
    ref.watch(
      workspaceNotifierProvider.select((s) {
        final active = s.active;
        return (active?.id, active?.loading, active?.openError);
      }),
    );
    final tab = workspace.active;
    final showStart = tab == null || tab.isStartPage || tab.isOpeningShell;
    final body = showStart
        ? ColoredBox(color: context.tokens.canvas)
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
          );
    return body;
  }

  Widget _sidebarBody(String viewId, Workspace workspace) => switch (viewId) {
    'layers' => LayersPanel(workspace: workspace),
    'blocks' => BlocksPanel(workspace: workspace),
    'properties' => PropertiesPanel(workspace: workspace),
    'layouts' => LayoutsPanel(workspace: workspace),
    'history' => CommandLogPanel(workspace: workspace),
    'commands' => _CommandListPanel(
      workspace: workspace,
      onOpenPalette: () =>
          ref.read(commandLineNotifierProvider.notifier).setPaletteOpen(true),
    ),
    'plugins' => ScriptsPanel(workspace: workspace),
    _ => LayersPanel(workspace: workspace),
  };

  Map<ShortcutActivator, VoidCallback> _shortcuts(Workspace workspace) {
    return {
      ...commandShortcutBindings(workspace.commands, workspace.run),
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
      ...chord(LogicalKeyboardKey.keyP, () {
        workspace.active?.textSearch.close();
        ref.read(commandLineNotifierProvider.notifier).togglePalette();
      }, shift: true),
      ...chord(
        LogicalKeyboardKey.keyB,
        ref.read(layoutNotifierProvider.notifier).toggleSidebar,
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
            suffix: ListenableBuilder(
              listenable: _filter,
              builder: (context, _) => _filter.text.isEmpty
                  ? const SizedBox.shrink()
                  : FanCadIconButton(
                      icon: Icons.close,
                      size: 18,
                      iconSize: FanCadTokens.iconSmall,
                      tooltip: l10n.clear_filter,
                      onPressed: _filter.clear,
                    ),
            ),
          ),
        ),
        Expanded(
          child: _CommandMatchList(
            filter: _filter,
            workspace: widget.workspace,
            running: running,
          ),
        ),
      ],
    );
  }
}

/// The filtered command list. It listens to the field's text controller so a
/// keystroke does not rebuild the field.
class _CommandMatchList extends StatefulWidget {
  const _CommandMatchList({
    required this.filter,
    required this.workspace,
    required this.running,
  });

  final TextEditingController filter;
  final Workspace workspace;
  final String? running;

  @override
  State<_CommandMatchList> createState() => _CommandMatchListState();
}

class _CommandMatchListState extends State<_CommandMatchList> {
  String _query = '';
  bool _scheduled = false;
  StreamSubscription<CommandRegistry>? _registry;

  @override
  void initState() {
    super.initState();
    widget.filter.addListener(_schedule);
    _registry = widget.workspace.commands.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(_CommandMatchList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) {
      oldWidget.filter.removeListener(_schedule);
      widget.filter.addListener(_schedule);
    }
    if (oldWidget.workspace != widget.workspace) {
      _registry?.cancel();
      _registry = widget.workspace.commands.changes.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    widget.filter.removeListener(_schedule);
    _registry?.cancel();
    super.dispose();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final next = widget.filter.text;
      if (next == _query) return;
      setState(() => _query = next);
    });
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
    final running = widget.running;
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

/// Canvas stand-in while a file is reading, or after that read failed.
///
/// The tab is already open. This fills the drawing area so the start page is
/// not what the user stares at, and a failure stays in the tab that asked.
class _OpeningCanvas extends StatelessWidget {
  const _OpeningCanvas({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final tab = workspace.active;
    if (tab == null) return const SizedBox.shrink();
    final tokens = context.tokens;
    final failed = tab.openError.isNotEmpty;
    return ColoredBox(
      color: tokens.canvas,
      child: Center(
        child: failed
            ? _OpenFailedCard(workspace: workspace, tab: tab)
            : _OpeningProgress(title: tab.title),
      ),
    );
  }
}

class _OpeningProgress extends StatelessWidget {
  const _OpeningProgress({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      key: const Key('opening-canvas'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: tokens.dialogTitleStyle),
        const SizedBox(height: FanCadTokens.space4),
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: tokens.accent,
          ),
        ),
        const SizedBox(height: FanCadTokens.space3),
        Text(context.l10n.opening_drawing, style: tokens.labelStyle),
      ],
    );
  }
}

class _OpenFailedCard extends StatelessWidget {
  const _OpenFailedCard({required this.workspace, required this.tab});

  final Workspace workspace;
  final DocumentTab tab;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Material(
        key: const Key('open-failed-card'),
        color: tokens.surfaceOverlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
          side: BorderSide(color: tokens.borderStrong),
        ),
        child: Padding(
          padding: const EdgeInsets.all(FanCadTokens.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tab.title, style: tokens.dialogTitleStyle),
              const SizedBox(height: FanCadTokens.space3),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: SingleChildScrollView(
                  child: Text(tab.openError, style: tokens.bodyStyle),
                ),
              ),
              const SizedBox(height: FanCadTokens.space4),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const Key('open-failed-close'),
                  onPressed: () {
                    final index = workspace.indexOfSession(tab.session);
                    workspace.closeTab(index, force: true);
                  },
                  child: Text(context.l10n.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
