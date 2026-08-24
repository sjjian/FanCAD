import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/l10n.dart';
import '../state/document_tab.dart';
import '../state/settings.dart';
import '../state/workspace.dart';
import '../theme/tokens.dart';
import 'shell_widgets.dart';

/// The custom title bar.
///
/// Replaces the OS chrome so the menus, the quick-access tools and the window
/// buttons share one 32-pixel row. On a CAD application that row is worth having:
/// vertical space is the scarcest thing on screen.
///
/// macOS keeps the native traffic lights on a hidden title bar, so the first
/// icon is inset and the Windows-style buttons stay off that platform.
class TitleBar extends StatelessWidget {
  const TitleBar({
    super.key,
    required this.workspace,
    required this.onTogglePalette,
    required this.onToggleAssistant,
    required this.onSetTheme,
    required this.onSetLanguage,
    this.assistantOpen = false,
  });

  final Workspace workspace;
  final VoidCallback onTogglePalette;
  final VoidCallback onToggleAssistant;
  final ValueChanged<Brightness> onSetTheme;
  final ValueChanged<String> onSetLanguage;
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

  /// Whether this platform draws its own minimise / maximise / close cluster.
  @visibleForTesting
  static bool usesCustomWindowButtons({
    required bool usesNativeTrafficLights,
  }) => !usesNativeTrafficLights;

  /// Window title. A single drawing is already named on the tab strip.
  @visibleForTesting
  static String chromeTitle({
    required int tabCount,
    String? activeTitle,
    bool dirty = false,
  }) {
    if (tabCount <= 1) return 'FanCAD';
    return '${dirty ? '● ' : ''}$activeTitle — FanCAD';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final tab = workspace.active;
    final title = chromeTitle(
      tabCount: workspace.tabs.length,
      activeTitle: tab?.title,
      dirty: tab?.isDirty ?? false,
    );
    final nativeLights = Platform.isMacOS;

    return Container(
      height: FanCadTokens.titleBarHeight,
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        border: Border(bottom: BorderSide(color: tokens.border)),
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
            icon: Icons.save_outlined,
            tooltip: tab == null
                ? '${l10n.save}  ${shellShortcut('S')}'
                : tab.isDirty
                ? '${l10n.save_unsaved_changes}  ${shellShortcut('S')}'
                : tab.filePath == null
                ? '${l10n.save_this_drawing}  ${shellShortcut('S')}'
                : l10n.saved_write_again(shellShortcut('S')),
            enabled: tab != null,
            isActive: tab?.isDirty ?? false,
            onPressed: () => workspace.run('file.save'),
          ),
          _FileMenu(workspace: workspace),
          const _Divider(),
          ShellIconButton(
            icon: Icons.undo,
            tooltip: _undoTooltip(l10n, tab),
            enabled: tab?.history.canUndo ?? false,
            onPressed: () => workspace.run('edit.undo'),
          ),
          ShellIconButton(
            icon: Icons.redo,
            tooltip: _redoTooltip(l10n, tab),
            enabled: tab?.history.canRedo ?? false,
            onPressed: () => workspace.run('edit.redo'),
          ),
          const _Divider(),
          // The drawing tools that earn a permanent home. Everything else is a
          // palette search away, which is the point of having a registry.
          for (final tool in _quickTools)
            ShellIconButton(
              icon: tool.icon,
              tooltip:
                  '${l10n.commandTitle(tool.commandId, tool.fallback)}  ${tool.alias}',
              enabled: tab != null,
              isActive: workspace.runningCommand == tool.commandId,
              onPressed: () => workspace.run(tool.commandId),
            ),
          Expanded(
            child: _DragArea(
              child: Center(
                child: Text(
                  title,
                  style: tokens.labelStyle.copyWith(color: tokens.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          ShellIconButton(
            icon: Icons.search,
            tooltip: '${l10n.command_palette}  ${shellShortcut('P', shift: true)}',
            onPressed: onTogglePalette,
          ),
          _AppearanceMenu(
            onSetTheme: onSetTheme,
            onSetLanguage: onSetLanguage,
          ),
          ShellIconButton(
            icon: Icons.auto_awesome_outlined,
            tooltip: assistantOpen
                ? l10n.hide_assistant
                : l10n.show_assistant,
            isActive: assistantOpen,
            onPressed: onToggleAssistant,
          ),
          if (usesCustomWindowButtons(
            usesNativeTrafficLights: nativeLights,
          )) ...[
            const _Divider(),
            const _WindowButtons(),
          ],
        ],
      ),
    );
  }

  /// Naming what will be undone turns a guess into a decision.
  static String _undoTooltip(AppLocalizations l10n, DocumentTab? tab) {
    final label = tab?.history.nextUndoLabel;
    return label == null
        ? l10n.nothing_to_undo
        : '${l10n.undo_named(label)}  ${shellShortcut('Z')}';
  }

  static String _redoTooltip(AppLocalizations l10n, DocumentTab? tab) {
    final label = tab?.history.nextRedoLabel;
    return label == null
        ? l10n.nothing_to_redo
        : '${l10n.redo_named(label)}  ${shellShortcut('Z', shift: true)}';
  }

  static const List<
    ({String commandId, IconData icon, String alias, String fallback})
  >
  _quickTools = [
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
}

/// Dark / Light is a choice, not a coin flip — a checked menu says which
/// appearance is current and that the setting is kept across launches.
class _AppearanceMenu extends StatelessWidget {
  const _AppearanceMenu({
    required this.onSetTheme,
    required this.onSetLanguage,
  });

  final ValueChanged<Brightness> onSetTheme;
  final ValueChanged<String> onSetLanguage;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final current = tokens.isDark ? Brightness.dark : Brightness.light;
    final language = Localizations.maybeLocaleOf(context)?.languageCode ??
        FanCadLanguage.english;
    return PopupMenuButton<String>(
      tooltip: tokens.isDark
          ? l10n.appearance_dark_tooltip
          : l10n.appearance_light_tooltip,
      padding: EdgeInsets.zero,
      offset: const Offset(0, FanCadTokens.titleBarHeight - 8),
      color: tokens.surfaceOverlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FanCadTokens.radius),
        side: BorderSide(color: tokens.borderStrong),
      ),
      onSelected: (value) {
        if (value.startsWith('theme:')) {
          onSetTheme(
            value == 'theme:light' ? Brightness.light : Brightness.dark,
          );
          return;
        }
        if (value.startsWith('language:')) {
          onSetLanguage(value.substring('language:'.length));
        }
      },
      itemBuilder: (context) => [
        _checked(
          tokens,
          'theme:dark',
          Icons.dark_mode_outlined,
          l10n.theme_dark,
          current == Brightness.dark,
        ),
        _checked(
          tokens,
          'theme:light',
          Icons.light_mode_outlined,
          l10n.theme_light,
          current == Brightness.light,
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          enabled: false,
          height: 28,
          child: Text(l10n.language, style: tokens.sectionTitleStyle),
        ),
        _checked(
          tokens,
          'language:en',
          Icons.translate_outlined,
          'English',
          language == FanCadLanguage.english,
        ),
        _checked(
          tokens,
          'language:zh',
          Icons.translate_outlined,
          '简体中文',
          language == FanCadLanguage.chinese,
        ),
      ],
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(
          current == Brightness.dark
              ? Icons.dark_mode_outlined
              : Icons.light_mode_outlined,
          size: FanCadTokens.iconMedium,
          color: tokens.textMuted,
        ),
      ),
    );
  }

  PopupMenuItem<String> _checked(
    FanCadTokens tokens,
    String value,
    IconData icon,
    String label,
    bool selected,
  ) {
    return PopupMenuItem<String>(
      value: value,
      height: 32,
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: selected
                ? Icon(Icons.check, size: FanCadTokens.iconSmall, color: tokens.accent)
                : null,
          ),
          const SizedBox(width: FanCadTokens.space2),
          Icon(icon, size: FanCadTokens.iconSmall, color: tokens.textMuted),
          const SizedBox(width: FanCadTokens.space2),
          Text(label, style: tokens.bodyStyle),
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
    final recent = workspace.settings.getStringList(SettingsKeys.recentFiles);
    return PopupMenuButton<String>(
      tooltip: l10n.more_file_actions,
      padding: EdgeInsets.zero,
      offset: const Offset(0, FanCadTokens.titleBarHeight - 8),
      color: tokens.surfaceOverlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FanCadTokens.radius),
        side: BorderSide(color: tokens.borderStrong),
      ),
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
        _item(tokens, 'file.new', l10n.new_drawing, shellShortcut('N')),
        _item(tokens, 'file.open', l10n.open_ellipsis, shellShortcut('O')),
        if (recent.isNotEmpty) ...[
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            enabled: false,
            height: 28,
            child: Text(l10n.recent, style: tokens.sectionTitleStyle),
          ),
          for (final path in recent.take(8)) _recentItem(context, tokens, path),
          if (recent.any((path) => !File(path).existsSync()))
            PopupMenuItem<String>(
              value: 'pruneRecent',
              height: 32,
              child: Text(l10n.remove_missing, style: tokens.bodyStyle),
            ),
          PopupMenuItem<String>(
            value: 'clearRecent',
            height: 32,
            child: Text(l10n.clear_recent, style: tokens.bodyStyle),
          ),
        ],
        const PopupMenuDivider(),
        _item(
          tokens,
          'file.save',
          l10n.save,
          shellShortcut('S'),
          enabled: tab != null,
        ),
        _item(
          tokens,
          'file.saveAs',
          l10n.save_as,
          shellShortcut('S', shift: true),
          enabled: tab != null,
        ),
        _item(
          tokens,
          'file.close',
          l10n.close_drawing,
          shellShortcut('W'),
          enabled: tab != null,
        ),
      ],
      child: SizedBox(
        width: 22,
        height: 28,
        child: Icon(Icons.expand_more, size: FanCadTokens.iconMedium, color: tokens.textMuted),
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

  PopupMenuItem<String> _item(
    FanCadTokens tokens,
    String value,
    String label,
    String shortcut, {
    bool enabled = true,
  }) {
    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      height: 32,
      child: Row(
        children: [
          Expanded(child: Text(label, style: tokens.bodyStyle)),
          const SizedBox(width: FanCadTokens.space4),
          Text(shortcut, style: tokens.labelStyle),
        ],
      ),
    );
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
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
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
          if (tabs.length > 1) _OpenDrawingsMenu(workspace: workspace),
          ShellIconButton(
            icon: Icons.add,
            tooltip: '${context.l10n.new_drawing}  ${shellShortcut('N')}',
            onPressed: () => workspace.run('file.new'),
          ),
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
    return PopupMenuButton<int>(
      tooltip: context.l10n.open_drawings(tabs.length),
      padding: EdgeInsets.zero,
      offset: const Offset(0, FanCadTokens.tabBarHeight - 6),
      color: tokens.surfaceOverlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FanCadTokens.radius),
        side: BorderSide(color: tokens.borderStrong),
      ),
      onSelected: workspace.activate,
      itemBuilder: (context) => [
        for (var i = 0; i < tabs.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 32,
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: i == workspace.activeIndex
                      ? Icon(Icons.check, size: FanCadTokens.iconSmall, color: tokens.accent)
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
                      : null,
                ),
                const SizedBox(width: FanCadTokens.space2),
                Expanded(
                  child: Text(
                    tabs[i].title,
                    style: tokens.bodyStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: SizedBox(
        width: 22,
        height: 28,
        child: Icon(Icons.arrow_drop_down, size: FanCadTokens.iconMedium, color: tokens.textMuted),
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTertiaryTapUp: (_) => widget.onClose(),
        onSecondaryTapDown: (details) {
          widget.onTap();
          _openMenu(details.globalPosition);
        },
        child: Container(
          padding: const EdgeInsets.only(
            left: FanCadTokens.space3,
            right: FanCadTokens.space1,
          ),
          decoration: BoxDecoration(
            color: widget.isActive
                ? tokens.selection
                : _hovered
                ? tokens.hover
                : Colors.transparent,
            border: Border(
              right: BorderSide(color: tokens.border),
              top: BorderSide(
                color: widget.isActive ? tokens.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
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
        ),
      ),
    );
  }

  Future<void> _openMenu(Offset globalPosition) async {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final workspace = widget.workspace;
    final tab = widget.tab;
    final others = workspace.tabs.length > 1;
    final path = tab.filePath;
    final chosen = await showMenu<String>(
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
        PopupMenuItem(
          value: 'close',
          height: 32,
          child: Text(l10n.close, style: tokens.bodyStyle),
        ),
        PopupMenuItem(
          value: 'closeOthers',
          enabled: others,
          height: 32,
          child: Text(l10n.close_others, style: tokens.bodyStyle),
        ),
        PopupMenuItem(
          value: 'closeAll',
          height: 32,
          child: Text(l10n.close_all, style: tokens.bodyStyle),
        ),
        if (path != null || tab.diagnostics.isNotEmpty) ...[
          const PopupMenuDivider(),
          if (path != null)
            PopupMenuItem(
              value: 'copyPath',
              height: 32,
              child: Text(l10n.copy_path, style: tokens.bodyStyle),
            ),
          if (path != null)
            PopupMenuItem(
              value: 'reveal',
              height: 32,
              child: Text(l10n.revealInFolder(), style: tokens.bodyStyle),
            ),
          if (tab.diagnostics.isNotEmpty)
            PopupMenuItem(
              value: 'warnings',
              height: 32,
              child: Text(
                l10n.import_warnings(tab.diagnostics.length),
                style: tokens.bodyStyle,
              ),
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
      widget.workspace.notify(l10n.could_not_reveal(path, '$error'), isError: true);
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
              widget.workspace.notify(
                l10n.copied_warnings(diagnostics.length),
              );
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
      const SizedBox(width: FanCadTokens.space1),
    ],
  );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: FanCadTokens.space2),
    child: Container(width: 1, height: 18, color: context.tokens.border),
  );
}
