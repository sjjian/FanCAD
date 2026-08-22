import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../state/document_tab.dart';
import '../state/workspace.dart';
import '../theme/tokens.dart';
import 'shell_widgets.dart';

/// The custom title bar.
///
/// Replaces the OS chrome so the menus, the quick-access tools and the window
/// buttons share one 36-pixel row. On a CAD application that row is worth having:
/// vertical space is the scarcest thing on screen.
class TitleBar extends StatelessWidget {
  const TitleBar({
    super.key,
    required this.workspace,
    required this.onTogglePalette,
    required this.onToggleSidebar,
    required this.onToggleTheme,
  });

  final Workspace workspace;
  final VoidCallback onTogglePalette;
  final VoidCallback onToggleSidebar;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tab = workspace.active;
    final title = tab == null
        ? 'FanCAD'
        : '${tab.isDirty ? '● ' : ''}${tab.title} — FanCAD';

    return Container(
      height: FanCadTokens.titleBarHeight,
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: FanCadTokens.space2),
          ShellIconButton(
            icon: Icons.menu,
            tooltip: 'Toggle sidebar  Ctrl B',
            onPressed: onToggleSidebar,
          ),
          const _Divider(),
          ShellIconButton(
            icon: Icons.insert_drive_file_outlined,
            tooltip: 'New drawing  Ctrl N',
            onPressed: () => workspace.run('file.new'),
          ),
          ShellIconButton(
            icon: Icons.folder_open_outlined,
            tooltip: 'Open  Ctrl O',
            onPressed: () => workspace.run('file.open'),
          ),
          ShellIconButton(
            icon: Icons.save_outlined,
            tooltip: 'Save  Ctrl S',
            enabled: tab != null,
            onPressed: () => workspace.run('file.save'),
          ),
          const _Divider(),
          ShellIconButton(
            icon: Icons.undo,
            tooltip: _undoTooltip(tab),
            enabled: tab?.history.canUndo ?? false,
            onPressed: () => workspace.run('edit.undo'),
          ),
          ShellIconButton(
            icon: Icons.redo,
            tooltip: _redoTooltip(tab),
            enabled: tab?.history.canRedo ?? false,
            onPressed: () => workspace.run('edit.redo'),
          ),
          const _Divider(),
          // The drawing tools that earn a permanent home. Everything else is a
          // palette search away, which is the point of having a registry.
          for (final tool in _quickTools)
            ShellIconButton(
              icon: tool.icon,
              tooltip: tool.tooltip,
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
            tooltip: 'Command palette  Ctrl Shift P',
            onPressed: onTogglePalette,
          ),
          ShellIconButton(
            icon: tokens.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            tooltip: 'Toggle theme',
            onPressed: onToggleTheme,
          ),
          const _Divider(),
          const _WindowButtons(),
        ],
      ),
    );
  }

  /// Naming what will be undone turns a guess into a decision.
  static String _undoTooltip(DocumentTab? tab) {
    final label = tab?.history.nextUndoLabel;
    return label == null ? 'Nothing to undo' : 'Undo $label  Ctrl Z';
  }

  static String _redoTooltip(DocumentTab? tab) {
    final label = tab?.history.nextRedoLabel;
    return label == null ? 'Nothing to redo' : 'Redo $label  Ctrl Shift Z';
  }

  static const List<({String commandId, IconData icon, String tooltip})>
  _quickTools = [
    (
      commandId: 'draw.line',
      icon: Icons.show_chart,
      tooltip: 'Line  L',
    ),
    (
      commandId: 'draw.polyline',
      icon: Icons.timeline,
      tooltip: 'Polyline  PL',
    ),
    (
      commandId: 'draw.rectangle',
      icon: Icons.crop_square,
      tooltip: 'Rectangle  REC',
    ),
    (
      commandId: 'draw.circle',
      icon: Icons.circle_outlined,
      tooltip: 'Circle  C',
    ),
    (
      commandId: 'draw.arc',
      icon: Icons.architecture,
      tooltip: 'Arc  A',
    ),
    (
      commandId: 'draw.text',
      icon: Icons.text_fields,
      tooltip: 'Text  T',
    ),
    (
      commandId: 'edit.move',
      icon: Icons.open_with,
      tooltip: 'Move  M',
    ),
    (
      commandId: 'edit.copy',
      icon: Icons.content_copy_outlined,
      tooltip: 'Copy  CO',
    ),
    (
      commandId: 'edit.offset',
      icon: Icons.line_style,
      tooltip: 'Offset  O',
    ),
    (
      commandId: 'edit.trim',
      icon: Icons.content_cut,
      tooltip: 'Trim  TR',
    ),
  ];
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
            icon: Icons.add,
            tooltip: 'New drawing  Ctrl N',
            onPressed: () => workspace.run('file.new'),
          ),
          const SizedBox(width: FanCadTokens.space1),
        ],
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  const _Tab({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

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
        child: Container(
          padding: const EdgeInsets.only(
            left: FanCadTokens.space3,
            right: FanCadTokens.space1,
          ),
          decoration: BoxDecoration(
            color: widget.isActive
                ? tokens.canvas
                : _hovered
                ? tokens.hover
                : Colors.transparent,
            border: Border(
              right: BorderSide(color: tokens.border),
              top: BorderSide(
                color: widget.isActive ? tokens.accent : Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
          child: Row(
            children: [
              if (tab.diagnostics.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: FanCadTokens.space1),
                  child: Tooltip(
                    message:
                        '${tab.diagnostics.length} import warning(s)\n'
                        '${tab.diagnostics.take(6).join('\n')}',
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 13,
                      color: tokens.warning,
                    ),
                  ),
                ),
              Text(
                tab.title,
                style: tokens.bodyStyle.copyWith(
                  color: widget.isActive ? tokens.text : tokens.textMuted,
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
                        iconSize: 12,
                        tooltip: 'Close  Ctrl W',
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

class _WindowButtons extends StatelessWidget {
  const _WindowButtons();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ShellIconButton(
        icon: Icons.remove,
        tooltip: 'Minimise',
        onPressed: windowManager.minimize,
      ),
      ShellIconButton(
        icon: Icons.crop_square,
        iconSize: 13,
        tooltip: 'Maximise',
        onPressed: () async {
          if (await windowManager.isMaximized()) {
            await windowManager.unmaximize();
          } else {
            await windowManager.maximize();
          }
        },
      ),
      ShellIconButton(
        icon: Icons.close,
        tooltip: 'Close',
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
