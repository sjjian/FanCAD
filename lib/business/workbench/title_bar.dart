import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../services/document_tab.dart';
import '../../services/workspace.dart';
import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import 'shell_widgets.dart';

/// The custom title bar.
///
/// Replaces the OS chrome so file actions, window buttons and the assistant
/// toggle share one 32-pixel row. Drawing tools live on the canvas.
///
/// macOS keeps the native traffic lights on a hidden title bar, so the first
/// icon is inset and the Windows-style buttons stay off that platform.
class TitleBar extends StatelessWidget {
  const TitleBar({
    super.key,
    required this.workspace,
    required this.onTogglePalette,
    required this.onToggleAssistant,
    this.assistantOpen = false,
  });

  final Workspace workspace;
  final VoidCallback onTogglePalette;
  final VoidCallback onToggleAssistant;
  final bool assistantOpen;

  /// Space before the first title-bar control.
  ///
  /// The native traffic lights sit over the Flutter view; without this inset
  /// the first file icon is drawn under the red button.
  @visibleForTesting
  static double leadingInset({required bool usesNativeTrafficLights}) =>
      usesNativeTrafficLights
      ? FanCadTokens.macTrafficLightsWidth
      : FanCadTokens.space2;

  /// Space after the last title-bar control.
  ///
  /// macOS has no window-button cluster on the right, so the assistant
  /// icon would otherwise sit flush against the window edge.
  @visibleForTesting
  static double trailingInset() => FanCadTokens.space2;

  /// Whether this platform draws its own minimise / maximise / close cluster.
  @visibleForTesting
  static bool usesCustomWindowButtons({
    required bool usesNativeTrafficLights,
  }) => !usesNativeTrafficLights;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final tab = workspace.active;
    final nativeLights = Platform.isMacOS;

    return Container(
      key: const Key('title-bar'),
      height: FanCadTokens.titleBarHeight,
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        border: Border(bottom: BorderSide(color: tokens.borderMuted)),
      ),
      child: Row(
        children: [
          SizedBox(width: leadingInset(usesNativeTrafficLights: nativeLights)),
          ShellIconButton(
            icon: Icons.insert_drive_file_outlined,
            tooltip: '${l10n.new_drawing}  ${shellShortcut('N')}',
            onPressed: () => workspace.run('file.new'),
          ),
          ShellIconButton(
            icon: Icons.folder_open_outlined,
            tooltip: '${l10n.open}  ${shellShortcut('O')}',
            onPressed: () => workspace.run('file.open'),
          ),
          ShellIconButton(
            icon: tab?.isDirty == true ? Icons.save : Icons.save_outlined,
            tooltip: tab == null
                ? '${l10n.save}  ${shellShortcut('S')}'
                : tab.isDirty
                ? '${l10n.save_unsaved_changes}  ${shellShortcut('S')}'
                : tab.filePath == null
                ? '${l10n.save_this_drawing}  ${shellShortcut('S')}'
                : l10n.saved_write_again(shellShortcut('S')),
            enabled: tab != null,
            onPressed: () => workspace.run('file.save'),
          ),
          _FileMenu(workspace: workspace),
          const Expanded(child: _DragArea(child: SizedBox.expand())),
          ShellIconButton(
            icon: Icons.search,
            tooltip:
                '${l10n.command_palette}  ${shellShortcut('P', shift: true)}',
            onPressed: onTogglePalette,
          ),
          ShellIconButton(
            icon: Icons.auto_awesome_outlined,
            tooltip: assistantOpen ? l10n.hide_assistant : l10n.show_assistant,
            isActive: assistantOpen,
            onPressed: onToggleAssistant,
          ),
          if (usesCustomWindowButtons(
            usesNativeTrafficLights: nativeLights,
          )) ...[
            const ShellHairline(
              axis: Axis.vertical,
              extent: 18,
              padding: EdgeInsets.symmetric(horizontal: FanCadTokens.space2),
            ),
            const _WindowButtons(),
          ],
          SizedBox(width: trailingInset()),
        ],
      ),
    );
  }
}

/// Overflow for Save As, recent files and Close — the actions that do not
/// earn a permanent toolbar icon.
class _FileMenu extends StatelessWidget {
  const _FileMenu({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final tab = workspace.active;
    final recent = workspace.recentFiles;
    return ShellMenuButton<String>(
      tooltip: l10n.more_file_actions,
      placement: ShellMenuPlacement.down,
      onSelected: (value) {
        if (value.startsWith('recent:')) {
          workspace.run(
            'file.open',
            args: {'path': value.substring('recent:'.length)},
          );
          return;
        }
        if (value == 'clearRecent') {
          workspace.clearRecentFiles();
          return;
        }
        if (value == 'pruneRecent') {
          final removed = workspace.pruneMissingRecentFiles();
          workspace.notify(
            removed == 0
                ? l10n.recent_all_on_disk
                : removed == 1
                ? l10n.recent_removed_one
                : l10n.recent_removed_many(removed),
          );
          return;
        }
        workspace.run(value);
      },
      itemBuilder: (context) => [
        shellMenuItem(
          context,
          value: 'file.new',
          label: l10n.new_drawing,
          shortcut: shellShortcut('N'),
        ),
        shellMenuItem(
          context,
          value: 'file.open',
          label: l10n.open_ellipsis,
          shortcut: shellShortcut('O'),
        ),
        if (recent.isNotEmpty) ...[
          const PopupMenuDivider(),
          shellMenuSection<String>(context, l10n.recent),
          for (final path in recent.take(8)) _recentItem(context, tokens, path),
          if (recent.any((path) => !File(path).existsSync()))
            shellMenuItem(
              context,
              value: 'pruneRecent',
              label: l10n.remove_missing,
            ),
          shellMenuItem(
            context,
            value: 'clearRecent',
            label: l10n.clear_recent,
          ),
        ],
        const PopupMenuDivider(),
        shellMenuItem(
          context,
          value: 'file.save',
          label: l10n.save,
          shortcut: shellShortcut('S'),
          enabled: tab != null,
        ),
        shellMenuItem(
          context,
          value: 'file.saveAs',
          label: l10n.save_as,
          shortcut: shellShortcut('S', shift: true),
          enabled: tab != null,
        ),
        shellMenuItem(
          context,
          value: 'file.close',
          label: l10n.close_drawing,
          shortcut: shellShortcut('W'),
          enabled: tab != null,
        ),
      ],
      child: SizedBox(
        width: 22,
        height: 28,
        child: Icon(
          Icons.expand_more,
          size: FanCadTokens.iconMedium,
          color: tokens.textMuted,
        ),
      ),
    );
  }

  PopupMenuItem<String> _recentItem(
    BuildContext context,
    FanCadTokens tokens,
    String path,
  ) {
    final l10n = context.l10n;
    final exists = File(path).existsSync();
    return PopupMenuItem<String>(
      value: 'recent:$path',
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: exists ? path : l10n.missing_path(path),
              child: Text(
                _fileName(path),
                style: tokens.bodyStyle.copyWith(
                  color: exists ? tokens.text : tokens.textFaint,
                  decoration: exists ? null : TextDecoration.lineThrough,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (exists)
            Tooltip(
              message: l10n.revealInFolder(),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(_revealOnDisk(path, l10n));
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.folder_open_outlined,
                    size: FanCadTokens.iconSmall,
                    color: tokens.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _revealOnDisk(String path, AppLocalizations l10n) async {
    try {
      if (Platform.isMacOS) {
        await Process.start('open', ['-R', path]);
      } else if (Platform.isWindows) {
        await Process.start('explorer', ['/select,', path]);
      } else {
        await Process.start('xdg-open', [File(path).parent.path]);
      }
    } catch (error) {
      workspace.notify(l10n.could_not_reveal(path, '$error'), isError: true);
    }
  }

  static String _fileName(String path) {
    final separator = path.contains(r'\') ? r'\' : '/';
    final parts = path.split(separator);
    return parts.isEmpty ? path : parts.last;
  }
}

/// The document tab strip.
class DocumentTabStrip extends StatelessWidget {
  const DocumentTabStrip({super.key, required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tabs = workspace.tabs;
    if (tabs.isEmpty) return const SizedBox.shrink();
    return Container(
      height: FanCadTokens.tabBarHeight,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.borderMuted)),
      ),
      child: Row(
        children: [
          Flexible(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              itemCount: tabs.length,
              itemBuilder: (context, index) => _Tab(
                workspace: workspace,
                tab: tabs[index],
                isActive: index == workspace.activeIndex,
                onTap: () => workspace.activate(index),
                onClose: () {
                  if (workspace.closeTab(index)) return;
                  workspace.activate(index);
                  workspace.run('file.close');
                },
              ),
            ),
          ),
          ShellIconButton(
            key: const Key('document-new-tab'),
            icon: Icons.add,
            tooltip: '${context.l10n.new_drawing}  ${shellShortcut('N')}',
            onPressed: () => workspace.run('file.new'),
          ),
          if (tabs.length > 1) _OpenDrawingsMenu(workspace: workspace),
          const SizedBox(width: FanCadTokens.space1),
        ],
      ),
    );
  }
}

/// The strip scrolls; this list does not. A drawing that has gone off the
/// right edge is still one click away.
class _OpenDrawingsMenu extends StatelessWidget {
  const _OpenDrawingsMenu({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tabs = workspace.tabs;
    return ShellMenuButton<int>(
      tooltip: context.l10n.open_drawings(tabs.length),
      placement: ShellMenuPlacement.down,
      onSelected: workspace.activate,
      itemBuilder: (context) => [
        for (var i = 0; i < tabs.length; i++)
          shellMenuItem<int>(
            context,
            value: i,
            label: tabs[i].title,
            checked: i == workspace.activeIndex ? true : null,
            leading: i == workspace.activeIndex
                ? null
                : tabs[i].isDirty
                ? Center(
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: tokens.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      ],
      child: SizedBox(
        width: 22,
        height: 28,
        child: Icon(
          Icons.arrow_drop_down,
          size: FanCadTokens.iconMedium,
          color: tokens.textMuted,
        ),
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  const _Tab({
    required this.workspace,
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  final Workspace workspace;
  final DocumentTab tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tab = widget.tab;
    return ShellTab(
      key: Key('document-tab-${tab.session.id}'),
      selected: widget.isActive,
      onTap: widget.onTap,
      onClose: widget.onClose,
      onSecondaryTapDown: (position) {
        widget.onTap();
        _openMenu(position);
      },
      onHoverChanged: (hovered) => setState(() => _hovered = hovered),
      child: Row(
        children: [
          if (tab.diagnostics.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: FanCadTokens.space1),
              child: GestureDetector(
                onTap: () => _showImportWarnings(),
                child: Tooltip(
                  message: context.l10n.import_warnings_tooltip(
                    tab.diagnostics.length,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: FanCadTokens.iconSmall,
                    color: tokens.warning,
                  ),
                ),
              ),
            ),
          Tooltip(
            message: tab.isDirty
                ? tab.filePath == null
                      ? context.l10n.unsaved_drawing
                      : context.l10n.unsaved_changes_path(tab.filePath!)
                : tab.filePath ?? context.l10n.unsaved_drawing,
            waitDuration: const Duration(milliseconds: 500),
            child: Text(
              tab.title,
              style: tokens.bodyStyle.copyWith(
                color: widget.isActive ? tokens.text : tokens.textMuted,
              ),
            ),
          ),
          const SizedBox(width: FanCadTokens.space2),
          // The unsaved dot becomes the close button on hover, which keeps
          // the tab width from jumping as the pointer moves across it.
          SizedBox(
            width: 18,
            child: _hovered || widget.isActive
                ? ShellIconButton(
                    icon: Icons.close,
                    size: 18,
                    iconSize: FanCadTokens.iconSmall,
                    tooltip: tab.isDirty
                        ? '${context.l10n.close_unsaved}  ${shellShortcut('W')}'
                        : '${context.l10n.close}  ${shellShortcut('W')}',
                    onPressed: widget.onClose,
                  )
                : tab.isDirty
                ? Center(
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: tokens.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _openMenu(Offset globalPosition) async {
    final l10n = context.l10n;
    final workspace = widget.workspace;
    final tab = widget.tab;
    final others = workspace.tabs.length > 1;
    final path = tab.filePath;
    final chosen = await showShellMenu<String>(
      context: context,
      position: shellMenuPosition(globalPosition),
      items: [
        shellMenuItem(context, value: 'close', label: l10n.close),
        shellMenuItem(
          context,
          value: 'closeOthers',
          label: l10n.close_others,
          enabled: others,
        ),
        shellMenuItem(context, value: 'closeAll', label: l10n.close_all),
        if (path != null || tab.diagnostics.isNotEmpty) ...[
          const PopupMenuDivider(),
          if (path != null)
            shellMenuItem(context, value: 'copyPath', label: l10n.copy_path),
          if (path != null)
            shellMenuItem(
              context,
              value: 'reveal',
              label: l10n.revealInFolder(),
            ),
          if (tab.diagnostics.isNotEmpty)
            shellMenuItem(
              context,
              value: 'warnings',
              label: l10n.import_warnings(tab.diagnostics.length),
            ),
        ],
      ],
    );
    if (!mounted) return;
    switch (chosen) {
      case 'close':
        widget.onClose();
      case 'closeOthers':
        await workspace.closeOtherTabs(tab);
      case 'closeAll':
        await workspace.closeAllTabs();
      case 'copyPath':
        if (path == null) return;
        await Clipboard.setData(ClipboardData(text: path));
        workspace.notify(l10n.copied_path(path));
      case 'reveal':
        if (path == null) return;
        await _revealOnDisk(path, l10n);
      case 'warnings':
        await _showImportWarnings();
    }
  }

  Future<void> _revealOnDisk(String path, AppLocalizations l10n) async {
    try {
      if (Platform.isMacOS) {
        await Process.start('open', ['-R', path]);
      } else if (Platform.isWindows) {
        await Process.start('explorer', ['/select,', path]);
      } else {
        await Process.start('xdg-open', [File(path).parent.path]);
      }
    } catch (error) {
      widget.workspace.notify(
        l10n.could_not_reveal(path, '$error'),
        isError: true,
      );
    }
  }

  Future<void> _showImportWarnings() async {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final diagnostics = widget.tab.diagnostics;
    if (diagnostics.isEmpty) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => AlertDialog(
        backgroundColor: tokens.surfaceOverlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
          side: BorderSide(color: tokens.borderStrong),
        ),
        title: Text(
          l10n.importWarningTitle(diagnostics.length),
          style: tokens.bodyStyle.copyWith(fontSize: 15),
        ),
        content: SizedBox(
          width: 480,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final line in diagnostics)
                  Padding(
                    padding: const EdgeInsets.only(bottom: FanCadTokens.space2),
                    child: Text(line, style: tokens.labelStyle),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: diagnostics.join('\n')));
              widget.workspace.notify(l10n.copied_warnings(diagnostics.length));
              Navigator.of(context).pop();
            },
            child: Text(l10n.copy_all, style: tokens.bodyStyle),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}

/// The area of the title bar that drags the window.
class _DragArea extends StatelessWidget {
  const _DragArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onPanStart: (_) => windowManager.startDragging(),
    onDoubleTap: () async {
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    },
    child: child,
  );
}

class _WindowButtons extends StatefulWidget {
  const _WindowButtons();

  @override
  State<_WindowButtons> createState() => _WindowButtonsState();
}

class _WindowButtonsState extends State<_WindowButtons> with WindowListener {
  bool _maximized = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    unawaited(_bind());
  }

  Future<void> _bind() async {
    try {
      windowManager.addListener(this);
      _listening = true;
      final maximized = await windowManager.isMaximized();
      if (mounted) setState(() => _maximized = maximized);
    } catch (_) {
      // Headless tests have no window plugin.
    }
  }

  @override
  void dispose() {
    if (_listening) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => _setMaximized(true);

  @override
  void onWindowUnmaximize() => _setMaximized(false);

  void _setMaximized(bool value) {
    if (!mounted || _maximized == value) return;
    setState(() => _maximized = value);
  }

  Future<void> _toggleMaximize() async {
    try {
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ShellIconButton(
        icon: Icons.remove,
        tooltip: context.l10n.minimise,
        onPressed: windowManager.minimize,
      ),
      ShellIconButton(
        icon: _maximized ? Icons.filter_none : Icons.crop_square,
        iconSize: FanCadTokens.iconSmall,
        tooltip: _maximized ? context.l10n.restore : context.l10n.maximise,
        onPressed: _toggleMaximize,
      ),
      ShellIconButton(
        icon: Icons.close,
        tooltip: context.l10n.close_window,
        destructive: true,
        onPressed: windowManager.close,
      ),
    ],
  );
}
