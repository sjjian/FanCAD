import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/material.dart';

import '../state/workspace.dart';
import '../theme/tokens.dart';
import 'shell_widgets.dart';

/// Model / paper chips in the status bar.
///
/// The document already stores layouts and `layout.set` already switches the
/// active block. Without this strip a paper tab is invisible: the user has a
/// sheet and viewports, but no way to open them from the shell. Sitting in
/// the status bar keeps a dedicated 32px row from eating the canvas.
class LayoutTabStrip extends StatelessWidget {
  const LayoutTabStrip({super.key, required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tab = workspace.active;
    if (tab == null) return const SizedBox.shrink();
    final layouts = [...tab.document.layouts]..sort(_compareLayouts);
    if (layouts.isEmpty) return const SizedBox.shrink();
    final active = tab.document.activeLayoutName;
    final maximized = tab.session.maximizedLayoutName;

    return SizedBox(
      height: FanCadTokens.statusBarHeight,
      child: Row(
        children: [
          Container(
            width: 1,
            height: 12,
            color: tokens.borderStrong,
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: FanCadTokens.space1,
              ),
              itemCount: layouts.length + 1,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: FanCadTokens.space1),
              itemBuilder: (context, index) {
                if (index == layouts.length) {
                  return _AddLayoutChip(
                    onTap: () => workspace.run('layout.new'),
                  );
                }
                final layout = layouts[index];
                return _LayoutChip(
                  layout: layout,
                  selected: layout.name == active,
                  isMaximized: maximized == layout.name,
                  onSelect: () {
                    if (maximized == layout.name) {
                      workspace.run('layout.vpmin');
                      return;
                    }
                    if (layout.name == active) return;
                    workspace.run(
                      'layout.set',
                      args: {'name': layout.name},
                    );
                  },
                  onRestore: maximized == layout.name
                      ? () => workspace.run('layout.vpmin')
                      : null,
                  onRename: layout.isModelSpace
                      ? null
                      : () => workspace.run(
                          'layout.rename',
                          args: {'name': layout.name},
                        ),
                  onCopy: layout.isModelSpace
                      ? null
                      : () => workspace.run(
                          'layout.copy',
                          args: {'name': layout.name},
                        ),
                  onDelete: layout.isModelSpace
                      ? null
                      : () => workspace.run(
                          'layout.delete',
                          args: {'name': layout.name},
                        ),
                  onNew: () => workspace.run('layout.new'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static int _compareLayouts(Layout a, Layout b) {
    if (a.isModelSpace != b.isModelSpace) {
      return a.isModelSpace ? -1 : 1;
    }
    return a.tabOrder.compareTo(b.tabOrder);
  }
}

class _LayoutChip extends StatefulWidget {
  const _LayoutChip({
    required this.layout,
    required this.selected,
    required this.isMaximized,
    required this.onSelect,
    required this.onNew,
    this.onRestore,
    this.onRename,
    this.onCopy,
    this.onDelete,
  });

  final Layout layout;
  final bool selected;
  final bool isMaximized;
  final VoidCallback onSelect;
  final VoidCallback onNew;
  final VoidCallback? onRestore;
  final VoidCallback? onRename;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;

  @override
  State<_LayoutChip> createState() => _LayoutChipState();
}

class _LayoutChipState extends State<_LayoutChip> {
  bool _hovered = false;

  void _openMenu() {
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final origin = box.localToGlobal(Offset(0, box.size.height));
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy,
        origin.dx + 1,
        origin.dy + 1,
      ),
      items: [
        if (widget.onRestore != null)
          const PopupMenuItem(value: 'restore', child: Text('Restore viewport')),
        if (widget.onRename != null)
          const PopupMenuItem(value: 'rename', child: Text('Rename')),
        if (widget.onCopy != null)
          const PopupMenuItem(value: 'copy', child: Text('Duplicate')),
        if (widget.onDelete != null)
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        const PopupMenuItem(value: 'new', child: Text('New layout')),
      ],
    ).then((action) {
      if (!mounted || action == null) return;
      switch (action) {
        case 'restore':
          widget.onRestore?.call();
        case 'rename':
          widget.onRename?.call();
        case 'copy':
          widget.onCopy?.call();
        case 'delete':
          widget.onDelete?.call();
        case 'new':
          widget.onNew();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final layout = widget.layout;
    final paper = layout.isModelSpace
        ? 'Model space'
        : '${layout.paperWidth.toStringAsFixed(0)} × '
              '${layout.paperHeight.toStringAsFixed(0)} mm'
              '${layout.viewports.isEmpty ? '' : ' · ${layout.viewports.length} viewport${layout.viewports.length == 1 ? '' : 's'}'}';
    return Tooltip(
      message: [
        paper,
        if (widget.isMaximized) 'Viewport maximised — click to restore',
        if (!layout.isModelSpace) 'Right-click for rename, duplicate or delete',
      ].join('\n'),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onSelect,
          onDoubleTap: widget.onRename,
          onSecondaryTap: _openMenu,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(
              left: FanCadTokens.space2,
              right: FanCadTokens.space1,
            ),
            decoration: BoxDecoration(
              color: widget.selected
                  ? tokens.selection
                  : _hovered
                  ? tokens.hover
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: widget.selected ? tokens.accent : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  layout.isModelSpace
                      ? Icons.grid_on_outlined
                      : Icons.description_outlined,
                  size: FanCadTokens.iconSmall,
                  color: widget.selected ? tokens.accent : tokens.textMuted,
                ),
                const SizedBox(width: FanCadTokens.space1),
                Text(
                  layout.name,
                  style: tokens.labelStyle.copyWith(
                    color: widget.selected ? tokens.text : tokens.textMuted,
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                if (widget.isMaximized) ...[
                  const SizedBox(width: FanCadTokens.space1),
                  Icon(
                    Icons.fullscreen,
                    size: FanCadTokens.iconSmall,
                    color: tokens.accent,
                  ),
                ],
                if (widget.onDelete != null && (_hovered || widget.selected))
                  ShellIconButton(
                    icon: Icons.close,
                    size: 18,
                    iconSize: FanCadTokens.iconSmall,
                    tooltip: 'Delete layout',
                    destructive: true,
                    onPressed: widget.onDelete,
                  )
                else
                  const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddLayoutChip extends StatefulWidget {
  const _AddLayoutChip({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_AddLayoutChip> createState() => _AddLayoutChipState();
}

class _AddLayoutChipState extends State<_AddLayoutChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Tooltip(
      message: 'New paper layout',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: FanCadTokens.space2,
            ),
            color: _hovered ? tokens.hover : Colors.transparent,
            child: Icon(
              Icons.add,
              size: FanCadTokens.iconMedium,
              color: _hovered ? tokens.text : tokens.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
