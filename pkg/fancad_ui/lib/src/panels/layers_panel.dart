import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/material.dart';

import '../state/workspace.dart';
import '../theme/tokens.dart';
import '../workbench/shell_widgets.dart';

/// The layer manager.
///
/// Every mutation here goes through a command rather than touching the document,
/// which is why toggling a layer off is undoable and why the same toggle is
/// available to a plugin and to the AI. A panel that wrote directly to the model
/// would be the one place the "single write path" rule leaked.
class LayersPanel extends StatefulWidget {
  const LayersPanel({super.key, required this.workspace});

  final Workspace workspace;

  @override
  State<LayersPanel> createState() => _LayersPanelState();
}

class _LayersPanelState extends State<LayersPanel> {
  String _filter = '';
  final TextEditingController _filterController = TextEditingController();

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Workspace get _workspace => widget.workspace;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tab = _workspace.active;
    if (tab == null) {
      // The header stays even with nothing to list, so a closed workspace looks
      // empty rather than broken.
      return const Column(
        children: [
          PanelHeader(title: 'Layers'),
          Expanded(child: _Empty(message: 'Open a drawing to see its layers.')),
        ],
      );
    }

    final counts = <String, int>{};
    for (final entity in tab.document.entities) {
      counts.update(entity.props.layer, (n) => n + 1, ifAbsent: () => 1);
    }
    final layers = tab.document.layers.values.toList()
      ..sort((a, b) => _compareLayerNames(a.name, b.name));
    final visible = _filter.isEmpty
        ? layers
        : [
            for (final layer in layers)
              if (layer.name.toLowerCase().contains(_filter)) layer,
          ];
    final hiddenCount = layers.where((layer) => !layer.visible).length;
    final lockedCount = layers.where((layer) => layer.locked).length;
    final palette = tokens.isDark ? AciPalette.dark : AciPalette.light;

    return Column(
      children: [
        PanelHeader(
          title: 'Layers',
          actions: [
            ShellIconButton(
              icon: Icons.add,
              tooltip: 'New layer (made current)',
              iconSize: FanCadTokens.iconMedium,
              onPressed: () => _workspace.run(
                'layer.new',
                args: {'name': _uniqueLayerName(tab.document)},
              ),
            ),
            ShellIconButton(
              icon: Icons.visibility_outlined,
              tooltip: hiddenCount == 0
                  ? 'All layers are on'
                  : 'Show $hiddenCount hidden layer${hiddenCount == 1 ? '' : 's'}',
              iconSize: FanCadTokens.iconMedium,
              enabled: hiddenCount > 0,
              onPressed: () => _workspace.run('layer.showAll'),
            ),
          ],
        ),
        Container(
          height: FanCadTokens.statusBarHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: FanCadTokens.space3,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: ShellTextField(
            controller: _filterController,
            hintText: 'Filter layers',
            style: tokens.bodyStyle,
            prefix: Padding(
              padding: const EdgeInsets.only(right: FanCadTokens.space2),
              child: Icon(
                Icons.search,
                size: FanCadTokens.iconSmall,
                color: tokens.textFaint,
              ),
            ),
            onChanged: (value) =>
                setState(() => _filter = value.trim().toLowerCase()),
            suffix: _filter.isEmpty
                ? null
                : ShellIconButton(
                    icon: Icons.close,
                    size: 18,
                    iconSize: FanCadTokens.iconSmall,
                    tooltip: 'Clear filter',
                    onPressed: () {
                      _filterController.clear();
                      setState(() => _filter = '');
                    },
                  ),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? _Empty(
                  message: _filter.isEmpty
                      ? 'This drawing has no layers.'
                      : 'No layers match “${_filterController.text.trim()}”.',
                )
              : ListView.builder(
                  itemCount: visible.length,
                  itemExtent: FanCadTokens.rowHeight,
                  itemBuilder: (context, index) {
                    final layer = visible[index];
                    return _LayerRow(
                      layer: layer,
                      color: palette.colorOf(layer.color),
                      count: counts[layer.name] ?? 0,
                      isCurrent: layer.name == tab.document.currentLayer,
                      onSetCurrent: () => _workspace.run(
                        'layer.setCurrent',
                        args: {'name': layer.name},
                      ),
                      onToggleVisible: () => _workspace.run(
                        'layer.toggleVisible',
                        args: {'name': layer.name},
                      ),
                      onToggleLock: () => _workspace.run(
                        'layer.toggleLock',
                        args: {'name': layer.name},
                      ),
                      onIsolate: () => _workspace.run(
                        'layer.isolate',
                        args: {'name': layer.name},
                      ),
                      onSelect: () => _workspace.run(
                        'select.byLayer',
                        args: {'layer': layer.name},
                      ),
                      onDelete: layer.name == '0'
                          ? null
                          : () => _workspace.run(
                              'layer.delete',
                              args: {'name': layer.name},
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
            _layerSummary(
              total: layers.length,
              shown: visible.length,
              hidden: hiddenCount,
              locked: lockedCount,
              current: tab.document.currentLayer,
              filtered: _filter.isNotEmpty,
            ),
            style: tokens.labelStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Sorts numerically where names are numeric, which is what makes a drawing
  /// with layers 1, 2 and 10 list in that order instead of 1, 10, 2.
  static int _compareLayerNames(String a, String b) {
    final numberA = int.tryParse(a);
    final numberB = int.tryParse(b);
    if (numberA != null && numberB != null) return numberA.compareTo(numberB);
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  static String _layerSummary({
    required int total,
    required int shown,
    required int hidden,
    required int locked,
    required String current,
    required bool filtered,
  }) {
    final parts = <String>[
      filtered ? '$shown of $total layers' : '$total layer${total == 1 ? '' : 's'}',
      if (hidden > 0) '$hidden hidden',
      if (locked > 0) '$locked locked',
      'current "$current"',
    ];
    return parts.join(' · ');
  }

  static String _uniqueLayerName(CadDocument document) {
    var index = 1;
    while (document.layer('Layer$index') != null) {
      index++;
    }
    return 'Layer$index';
  }
}

class _LayerRow extends StatefulWidget {
  const _LayerRow({
    required this.layer,
    required this.color,
    required this.count,
    required this.isCurrent,
    required this.onSetCurrent,
    required this.onToggleVisible,
    required this.onToggleLock,
    required this.onIsolate,
    required this.onSelect,
    required this.onDelete,
  });

  final LayerDef layer;
  final Color color;
  final int count;
  final bool isCurrent;
  final VoidCallback onSetCurrent;
  final VoidCallback onToggleVisible;
  final VoidCallback onToggleLock;
  final VoidCallback onIsolate;
  final VoidCallback onSelect;
  final VoidCallback? onDelete;

  @override
  State<_LayerRow> createState() => _LayerRowState();
}

class _LayerRowState extends State<_LayerRow> {
  void _openMenu() {
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final origin = box.localToGlobal(Offset(box.size.width - 4, 0));
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy,
        origin.dx + 1,
        origin.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: 'current',
          enabled: !widget.isCurrent,
          child: Text(
            widget.isCurrent ? 'Already current' : 'Set as current',
          ),
        ),
        const PopupMenuItem(
          value: 'isolate',
          child: Text('Isolate layer'),
        ),
        PopupMenuItem(
          value: 'select',
          enabled: widget.count > 0,
          child: Text(
            widget.count == 0
                ? 'No objects on this layer'
                : 'Select ${widget.count} object${widget.count == 1 ? '' : 's'}',
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          enabled: widget.onDelete != null,
          child: Text(
            widget.onDelete == null
                ? 'Layer 0 cannot be deleted'
                : 'Delete layer',
          ),
        ),
      ],
    ).then((action) {
      if (!mounted || action == null) return;
      switch (action) {
        case 'current':
          widget.onSetCurrent();
        case 'isolate':
          widget.onIsolate();
        case 'select':
          widget.onSelect();
        case 'delete':
          widget.onDelete?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final layer = widget.layer;
    final dimmed = !layer.isEffectivelyVisible;

    return Tooltip(
      message: widget.isCurrent
          ? 'Current layer — double-click to isolate, right-click for more'
          : 'Click to make current — double-click to isolate',
      waitDuration: const Duration(milliseconds: 700),
      child: ShellRow(
        isSelected: widget.isCurrent,
        onTap: widget.onSetCurrent,
        onDoubleTap: widget.onIsolate,
        onSecondaryTap: _openMenu,
        padding: const EdgeInsets.only(left: FanCadTokens.space2, right: 2),
        child: Row(
          children: [
            ShellIconButton(
              icon: layer.visible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              tooltip: layer.visible ? 'Turn layer off' : 'Turn layer on',
              size: 20,
              iconSize: FanCadTokens.iconSmall,
              isActive: layer.visible,
              onPressed: widget.onToggleVisible,
            ),
            ShellIconButton(
              icon: layer.locked ? Icons.lock_outline : Icons.lock_open,
              tooltip: layer.locked ? 'Unlock layer' : 'Lock layer',
              size: 20,
              iconSize: FanCadTokens.iconSmall,
              isActive: layer.locked,
              onPressed: widget.onToggleLock,
            ),
            const SizedBox(width: FanCadTokens.space1),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: dimmed ? 0.35 : 1),
                border: Border.all(
                  color: widget.isCurrent ? tokens.accent : tokens.border,
                  width: widget.isCurrent ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: FanCadTokens.space2),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      layer.name,
                      style: tokens.bodyStyle.copyWith(
                        color: dimmed ? tokens.textFaint : tokens.text,
                        fontWeight: widget.isCurrent
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (layer.frozen) ...[
                    const SizedBox(width: FanCadTokens.space1),
                    Icon(
                      Icons.ac_unit,
                      size: FanCadTokens.iconSmall,
                      color: tokens.textFaint,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: 28,
              child: Text(
                '${widget.count}',
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

class _Empty extends StatelessWidget {
  const _Empty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(FanCadTokens.space4),
      child: Text(
        message,
        style: context.tokens.labelStyle,
        textAlign: TextAlign.center,
      ),
    ),
  );
}
