import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../services/workspace.dart';
import '../widgets/tokens.dart';
import '../widgets/widgets.dart';

/// Named block definitions for the drawing open in front.
///
/// A row opens that definition on the canvas. Insert, select and rename go
/// through the same commands as the command line, so a click here is undoable
/// in the same way as typing the command.
class BlocksPanel extends ConsumerStatefulWidget {
  const BlocksPanel({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<BlocksPanel> createState() => _BlocksPanelState();
}

class _BlocksPanelState extends ConsumerState<BlocksPanel> {
  final TextEditingController _filterController = TextEditingController();

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Workspace get _workspace => widget.workspace;

  @override
  Widget build(BuildContext context) {
    final activeId = ref.watch(
      workspaceNotifierProvider.select((s) => s.active?.id),
    );
    final tab = _workspace.active;
    if (tab == null || tab.isOpeningShell) {
      return Column(
        key: const Key('blocks-panel'),
        children: [
          PanelHeader(title: context.l10n.blocks),
          Expanded(
            child: FanCadEmpty(message: context.l10n.blocks_empty_workspace),
          ),
        ],
      );
    }

    if (activeId != null) {
      ref.watch(
        documentTabNotifierProvider(activeId).select((s) => s.contentEpoch),
      );
    }
    return _blocksBody(context, tab);
  }

  Widget _blocksBody(BuildContext context, DocumentTab tab) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final document = tab.document;
    final blocks = document.insertableBlocks.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final counts = <String, int>{};
    for (final entity in document.entitiesOf(document.currentBlockName)) {
      if (entity is! InsertEntity) continue;
      final key = entity.blockName.toUpperCase();
      counts.update(key, (n) => n + 1, ifAbsent: () => 1);
    }
    final referenced = <String>{};
    for (final entity in document.entities) {
      if (entity is InsertEntity) {
        referenced.add(entity.blockName.toUpperCase());
      }
    }
    final unused = blocks
        .where(
          (block) =>
              !block.isXref && !referenced.contains(block.name.toUpperCase()),
        )
        .length;
    final xrefs = blocks.where((block) => block.isXref).length;
    final editing = document.editedBlockName?.toUpperCase();

    return Column(
      key: const Key('blocks-panel'),
      children: [
        PanelHeader(
          title: l10n.blocks,
          actions: [
            FanCadIconButton(
              key: const Key('block-purge'),
              icon: Icons.delete_outline,
              tooltip: unused == 0
                  ? l10n.block_purge_none
                  : l10n.block_purge_unused,
              iconSize: FanCadTokens.iconMedium,
              enabled: unused > 0,
              onPressed: () => _workspace.run('block.purge'),
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
            controller: _filterController,
            hintText: l10n.filter_blocks,
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
              listenable: _filterController,
              builder: (context, _) => _filterController.text.isEmpty
                  ? const SizedBox.shrink()
                  : FanCadIconButton(
                      icon: Icons.close,
                      size: 18,
                      iconSize: FanCadTokens.iconSmall,
                      tooltip: l10n.clear_filter,
                      onPressed: _filterController.clear,
                    ),
            ),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: _filterController,
            builder: (context, _) {
              final filter = _filterController.text.trim().toLowerCase();
              final visible = filter.isEmpty
                  ? blocks
                  : [
                      for (final block in blocks)
                        if (block.name.toLowerCase().contains(filter)) block,
                    ];
              return Column(
                children: [
                  Expanded(
                    child: visible.isEmpty
                        ? FanCadEmpty(
                            message: filter.isEmpty
                                ? l10n.no_blocks
                                : l10n.no_blocks_match(
                                    _filterController.text.trim(),
                                  ),
                          )
                        : ListView.builder(
                            itemCount: visible.length,
                            itemExtent: FanCadTokens.rowHeight,
                            itemBuilder: (context, index) {
                              final block = visible[index];
                              final count =
                                  counts[block.name.toUpperCase()] ?? 0;
                              final selected =
                                  editing == block.name.toUpperCase();
                              return _BlockRow(
                                block: block,
                                count: count,
                                selected: selected,
                                onEdit: () {
                                  if (selected) return;
                                  _workspace.run(
                                    'block.edit',
                                    args: {'name': block.name},
                                  );
                                },
                                onInsert: () => _insert(block.name),
                                onSelect: count == 0
                                    ? null
                                    : () => _workspace.run(
                                        'select.byBlock',
                                        args: {'name': block.name},
                                      ),
                                onRename: block.isXref
                                    ? null
                                    : () => _workspace.run(
                                        'block.rename',
                                        args: {'name': block.name},
                                      ),
                              );
                            },
                          ),
                  ),
                  Container(
                    height: FanCadTokens.statusBarHeight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: FanCadTokens.space3,
                    ),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: tokens.border)),
                    ),
                    child: Text(
                      _summary(
                        l10n,
                        total: blocks.length,
                        shown: visible.length,
                        unused: unused,
                        xrefs: xrefs,
                        filtered: filter.isNotEmpty,
                      ),
                      style: tokens.labelStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _insert(String name) async {
    if (_workspace.active?.document.isEditingBlock ?? false) {
      final closed = await _workspace.run('block.close');
      if (closed.status != CommandStatus.ok) return;
    }
    await _workspace.run('edit.insert', args: {'name': name});
  }

  static String _summary(
    AppLocalizations l10n, {
    required int total,
    required int shown,
    required int unused,
    required int xrefs,
    required bool filtered,
  }) {
    final parts = <String>[
      filtered ? l10n.blocks_shown_of(shown, total) : _count(l10n, total),
      if (unused == 1) l10n.blocks_unused_one,
      if (unused > 1) l10n.blocks_unused_many(unused),
      if (xrefs == 1) l10n.blocks_xref_one,
      if (xrefs > 1) l10n.blocks_xref_many(xrefs),
    ];
    return parts.join(' · ');
  }

  static String _count(AppLocalizations l10n, int total) =>
      total == 1 ? l10n.blocks_count_one : l10n.blocks_count_many(total);
}

class _BlockRow extends StatelessWidget {
  const _BlockRow({
    required this.block,
    required this.count,
    required this.selected,
    required this.onEdit,
    required this.onInsert,
    required this.onSelect,
    required this.onRename,
  });

  final BlockRecord block;
  final int count;
  final bool selected;
  final VoidCallback onEdit;
  final VoidCallback onInsert;
  final VoidCallback? onSelect;
  final VoidCallback? onRename;

  void _openMenu(BuildContext context) {
    final l10n = context.l10n;
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final origin = box.localToGlobal(Offset(box.size.width - 4, 0));
    showFanCadMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy,
        origin.dx + 1,
        origin.dy + 1,
      ),
      items: [
        fanCadMenuItem(context, value: 'insert', label: l10n.block_insert),
        fanCadMenuItem(
          context,
          value: 'select',
          enabled: onSelect != null,
          label: onSelect == null
              ? l10n.block_no_references
              : count == 1
              ? l10n.block_select_references_one
              : l10n.block_select_references_many(count),
        ),
        fanCadMenuItem(
          context,
          value: 'rename',
          enabled: onRename != null,
          label: l10n.block_menu_rename,
        ),
      ],
    ).then((action) {
      switch (action) {
        case 'insert':
          onInsert();
        case 'select':
          onSelect?.call();
        case 'rename':
          onRename?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    return Tooltip(
      message: selected
          ? l10n.editing_block_row_hint
          : l10n.edit_block_row_hint,
      waitDuration: const Duration(milliseconds: 700),
      child: FanCadRow(
        key: Key('block-row-${block.name}'),
        isSelected: selected,
        onTap: onEdit,
        onSecondaryTap: () => _openMenu(context),
        padding: const EdgeInsets.only(
          left: FanCadTokens.space3,
          right: FanCadTokens.space2,
        ),
        child: Row(
          children: [
            Icon(
              block.isXref ? Icons.link : Icons.widgets_outlined,
              key: block.isXref ? Key('block-xref-${block.name}') : null,
              size: FanCadTokens.iconSmall,
              color: selected ? tokens.accent : tokens.textFaint,
              semanticLabel: block.isXref ? l10n.block_xref : null,
            ),
            const SizedBox(width: FanCadTokens.space2),
            Expanded(
              child: Text(
                block.name,
                style: tokens.bodyStyle.copyWith(
                  color: tokens.text,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            FanCadIconButton(
              key: Key('block-insert-${block.name}'),
              icon: Icons.add_box_outlined,
              tooltip: l10n.block_insert,
              size: 20,
              iconSize: FanCadTokens.iconSmall,
              onPressed: onInsert,
            ),
            SizedBox(
              width: 28,
              child: Text(
                '$count',
                style: tokens.labelStyle,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
