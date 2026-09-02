import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/material.dart';

import '../../services/workspace.dart';
import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import '../workbench/shell_widgets.dart';

/// Model and paper layouts in the left sidebar.
///
/// The document already stores layouts and `layout.set` already switches the
/// active block. Without this panel a paper tab is invisible: the user has a
/// sheet and viewports, but no way to open them from the shell.
class LayoutsPanel extends StatelessWidget {
  const LayoutsPanel({super.key, required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final tab = workspace.active;
    if (tab == null) {
      return Column(
        key: const Key('layouts-panel'),
        children: [
          PanelHeader(
            title: context.l10n.layouts,
            actions: const [_AddLayoutButton(enabled: false)],
          ),
          Expanded(
            child: ShellEmpty(message: context.l10n.layouts_empty_workspace),
          ),
        ],
      );
    }

    final layouts = [...tab.document.layouts]..sort(_compareLayouts);
    final active = tab.document.activeLayoutName;
    final maximized = tab.session.maximizedLayoutName;

    return Column(
      key: const Key('layouts-panel'),
      children: [
        PanelHeader(
          title: context.l10n.layouts,
          actions: [_AddLayoutButton(onTap: () => workspace.run('layout.new'))],
        ),
        Expanded(
          child: layouts.isEmpty
              ? ShellEmpty(message: context.l10n.layouts_empty_workspace)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    vertical: FanCadTokens.space1,
                  ),
                  itemCount: layouts.length,
                  itemBuilder: (context, index) {
                    final layout = layouts[index];
                    return _LayoutRow(
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
    );
  }

  static int _compareLayouts(Layout a, Layout b) {
    if (a.isModelSpace != b.isModelSpace) {
      return a.isModelSpace ? -1 : 1;
    }
    return a.tabOrder.compareTo(b.tabOrder);
  }
}

class _AddLayoutButton extends StatelessWidget {
  const _AddLayoutButton({this.onTap, this.enabled = true});

  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ShellIconButton(
      key: const Key('layout-new-tab'),
      icon: Icons.add,
      tooltip: context.l10n.new_paper_layout,
      iconSize: FanCadTokens.iconMedium,
      enabled: enabled,
      onPressed: onTap,
    );
  }
}

class _LayoutRow extends StatefulWidget {
  const _LayoutRow({
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
  State<_LayoutRow> createState() => _LayoutRowState();
}

class _LayoutRowState extends State<_LayoutRow> {
  bool _hovered = false;

  void _openMenu() {
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final origin = box.localToGlobal(Offset(box.size.width - 4, 0));
    showShellMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy,
        origin.dx + 1,
        origin.dy + 1,
      ),
      items: [
        if (widget.onRestore != null)
          shellMenuItem(
            context,
            value: 'restore',
            label: context.l10n.restore_viewport,
          ),
        if (widget.onRename != null)
          shellMenuItem(context, value: 'rename', label: context.l10n.rename),
        if (widget.onCopy != null)
          shellMenuItem(context, value: 'copy', label: context.l10n.duplicate),
        if (widget.onDelete != null)
          shellMenuItem(context, value: 'delete', label: context.l10n.delete),
        shellMenuItem(context, value: 'new', label: context.l10n.new_layout),
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
    final l10n = context.l10n;
    final layout = widget.layout;
    final paper = layout.isModelSpace
        ? l10n.model_space
        : [
            l10n.paper_size_mm(
              layout.paperWidth.toStringAsFixed(0),
              layout.paperHeight.toStringAsFixed(0),
            ),
            if (layout.viewports.isNotEmpty)
              layout.viewports.length == 1
                  ? l10n.viewport_one
                  : l10n.viewport_many(layout.viewports.length),
          ].join(' · ');
    return ShellTab(
      key: Key('layout-tab-${layout.name}'),
      style: ShellTabStyle.row,
      selected: widget.selected,
      onTap: widget.onSelect,
      onDoubleTap: widget.onRename,
      onSecondaryTap: _openMenu,
      onHoverChanged: (hovered) => setState(() => _hovered = hovered),
      tooltip: [
        paper,
        if (widget.isMaximized) l10n.viewport_maximised,
        if (!layout.isModelSpace) l10n.layout_right_click,
      ].join('\n'),
      child: Row(
        children: [
          Icon(
            layout.isModelSpace
                ? Icons.grid_on_outlined
                : Icons.description_outlined,
            size: FanCadTokens.iconSmall,
            color: widget.selected ? tokens.accent : tokens.textMuted,
          ),
          const SizedBox(width: FanCadTokens.space2),
          Expanded(
            child: Text(
              layout.name,
              overflow: TextOverflow.ellipsis,
              style: tokens.labelStyle.copyWith(
                color: widget.selected ? tokens.text : tokens.textMuted,
                fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
              ),
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
              tooltip: l10n.delete_layout,
              destructive: true,
              onPressed: widget.onDelete,
            ),
        ],
      ),
    );
  }
}
