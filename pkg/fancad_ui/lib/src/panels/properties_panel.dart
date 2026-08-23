import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/material.dart';

import '../state/document_tab.dart';
import '../state/workspace.dart';
import '../theme/tokens.dart';
import '../workbench/shell_widgets.dart';

/// The properties panel.
///
/// Shows the intersection of the selection: a field that differs across the
/// selected objects reads `*Varies*` rather than showing the first value, which
/// is the difference between a panel you can trust and one that silently
/// misreports what you have selected.
class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({super.key, required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final tab = workspace.active;
    if (tab == null) {
      return Column(
        children: [
          const PanelHeader(title: 'Properties'),
          Expanded(
            child: _placeholder(
              context,
              'Open a drawing to inspect its objects.',
            ),
          ),
        ],
      );
    }
    final ids = tab.selection.ids.toList();
    final entities = <CadEntity>[
      for (final id in ids) ?tab.document.entity(id),
    ];

    return Column(
      children: [
        PanelHeader(
          title: 'Properties',
          actions: [
            if (entities.isNotEmpty) ...[
              ShellIconButton(
                icon: Icons.center_focus_strong,
                tooltip: 'Zoom to selection',
                iconSize: 15,
                onPressed: () => workspace.run('view.zoomSelected'),
              ),
              ShellIconButton(
                icon: Icons.deselect,
                tooltip: 'Clear selection',
                iconSize: 15,
                onPressed: () => workspace.run('select.none'),
              ),
            ],
            ShellIconButton(
              icon: Icons.info_outline,
              tooltip: 'List the selection in the command history',
              iconSize: 15,
              enabled: entities.isNotEmpty,
              onPressed: () => workspace.run('query.list'),
            ),
          ],
        ),
        Expanded(
          child: entities.isEmpty
              ? _EmptySelection(
                  objectCount: tab.document.entityCount,
                  onSelectAll: tab.document.entityCount == 0
                      ? null
                      : () => workspace.run('select.all'),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: FanCadTokens.space4),
                  children: [
                    PanelSection(
                      title: _selectionTitle(entities),
                      children: _generalRows(context, tab, entities),
                    ),
                    if (entities.length == 1)
                      PanelSection(
                        title: 'Geometry',
                        children: _geometryRows(context, entities.first),
                      ),
                    PanelSection(
                      title: 'Measurements',
                      children: _measurementRows(context, tab, entities),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  static String _titleFor(CadEntity entity) {
    final kind = entity.kind.name;
    final pretty = kind.isEmpty
        ? kind
        : '${kind[0].toUpperCase()}${kind.substring(1)}';
    return '$pretty #${entity.id}';
  }

  static String _selectionTitle(List<CadEntity> entities) {
    if (entities.length == 1) return _titleFor(entities.first);
    final counts = <String, int>{};
    for (final entity in entities) {
      counts.update(entity.kind.name, (n) => n + 1, ifAbsent: () => 1);
    }
    final parts = [
      for (final entry in counts.entries)
        '${entry.value} ${_plural(entry.key, entry.value)}',
    ];
    return '${entities.length} objects · ${parts.join(', ')}';
  }

  static String _plural(String kind, int count) {
    if (count == 1) return kind;
    if (kind.endsWith('s') || kind.endsWith('x')) return kind;
    return '${kind}s';
  }

  void _copied(String text) => workspace.notify('Copied $text');

  List<Widget> _generalRows(
    BuildContext context,
    DocumentTab tab,
    List<CadEntity> entities,
  ) {
    final tokens = context.tokens;
    final layer = _shared(entities, (entity) => entity.props.layer);
    final colorLabel = _shared(
      entities,
      (entity) => cadColorToJson(entity.props.color)?.toString() ?? 'ByLayer',
    );
    final lineType = _shared(entities, (entity) => entity.props.lineType);
    final lineWeight = _shared(entities, (entity) => entity.props.lineWeight);
    final swatch = _colorSwatch(tab, entities, tokens);
    return [
      PropertyRow(
        label: 'Layer',
        isEditable: true,
        copyText: layer,
        onCopied: _copied,
        value: Text(layer ?? '*Varies*'),
        onTap: () => workspace.run('edit.changeLayer'),
      ),
      PropertyRow(
        label: 'Colour',
        isEditable: true,
        copyText: colorLabel,
        onCopied: _copied,
        value: Row(
          children: [
            if (swatch != null) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: swatch,
                  border: Border.all(color: tokens.border),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: FanCadTokens.space2),
            ],
            Text(colorLabel ?? '*Varies*'),
          ],
        ),
        onTap: () => workspace.run('edit.changeColor'),
      ),
      PropertyRow(
        label: 'Line type',
        isEditable: true,
        copyText: lineType,
        onCopied: _copied,
        value: Text(lineType ?? '*Varies*'),
        onTap: () => workspace.run('edit.changeLinetype'),
      ),
      PropertyRow(
        label: 'Lineweight',
        isEditable: true,
        copyText: lineWeight == null ? null : _lineWeight(lineWeight),
        onCopied: _copied,
        value: Text(
          lineWeight == null ? '*Varies*' : _lineWeight(lineWeight),
        ),
        onTap: () => workspace.run('edit.changeLineweight'),
      ),
    ];
  }

  PropertyRow _read(String label, String text) => PropertyRow(
    label: label,
    value: Text(text),
    copyText: text,
    onCopied: _copied,
  );

  List<Widget> _geometryRows(BuildContext context, CadEntity entity) {
    switch (entity) {
      case LineEntity(:final start, :final end, :final length):
        final delta = end - start;
        return [
          _read('Start', _point(start)),
          _read('End', _point(end)),
          _read('Length', _number(length)),
          _read('Angle', '${_number(delta.angle * 180 / math.pi)}°'),
        ];
      case CircleEntity(:final center, :final radius):
        return [
          _read('Centre', _point(center)),
          _read('Radius', _number(radius)),
          _read('Diameter', _number(radius * 2)),
          _read('Circumference', _number(2 * math.pi * radius)),
        ];
      case ArcEntity(:final center, :final radius):
        return [
          _read('Centre', _point(center)),
          _read('Radius', _number(radius)),
          _read('Start angle', '${_number(entity.startAngle * 180 / math.pi)}°'),
          _read('End angle', '${_number(entity.endAngle * 180 / math.pi)}°'),
          _read('Total angle', '${_number(entity.sweep * 180 / math.pi)}°'),
        ];
      case PolylineEntity():
        return [
          _read('Vertices', '${entity.vertexCount}'),
          _read('Closed', entity.closed ? 'Yes' : 'No'),
          _read('Length', _number(Construct.lengthOf(entity))),
        ];
      case TextEntity(:final content, :final position, :final height):
        return [
          _read('Contents', content),
          _read('Position', _point(position)),
          _read('Height', _number(height)),
          _read('Rotation', '${_number(entity.rotation * 180 / math.pi)}°'),
          _read('Style', entity.styleName),
        ];
      case MTextEntity(:final content, :final position):
        return [
          _read('Contents', content),
          _read('Position', _point(position)),
          _read('Column width', _number(entity.rectangleWidth)),
        ];
      case InsertEntity(:final blockName, :final position):
        return [
          _read('Block', blockName),
          _read('Position', _point(position)),
          _read(
            'Scale',
            '${_number(entity.scale.x)}, ${_number(entity.scale.y)}',
          ),
          _read('Rotation', '${_number(entity.rotation * 180 / math.pi)}°'),
        ];
      case PointEntity(:final position):
        return [_read('Position', _point(position))];
      case HatchEntity(:final patternName, :final solid):
        return [
          _read('Pattern', patternName),
          _read('Solid fill', solid ? 'Yes' : 'No'),
          _read('Boundaries', '${entity.loops.length}'),
        ];
      case DimensionEntity(:final measurement, :final displayText):
        return [
          _read('Measurement', _number(measurement)),
          _read('Text', displayText),
          _read('Style', entity.styleName),
        ];
      default:
        return const [];
    }
  }

  List<Widget> _measurementRows(
    BuildContext context,
    DocumentTab tab,
    List<CadEntity> entities,
  ) {
    var length = 0.0;
    var area = 0.0;
    var box = const Bounds2.empty();
    for (final entity in entities) {
      length += Construct.lengthOf(entity);
      area += Construct.areaOf(entity).abs();
      box = box.union(tab.document.boundsOfEntity(entity));
    }
    return [
      _read('Total length', _number(length)),
      if (area > 0) _read('Total area', _number(area)),
      if (box.isNotEmpty) ...[
        _read('Min', _point(box.min)),
        _read('Max', _point(box.max)),
        _read('Size', '${_number(box.width)} × ${_number(box.height)}'),
      ],
    ];
  }

  /// The value shared by every entity, or null when they differ.
  static T? _shared<T>(
    List<CadEntity> entities,
    T Function(CadEntity entity) read,
  ) {
    if (entities.isEmpty) return null;
    final first = read(entities.first);
    for (final entity in entities.skip(1)) {
      if (read(entity) != first) return null;
    }
    return first;
  }

  static String _point(Vec2 point) =>
      '${_number(point.x)}, ${_number(point.y)}';

  static String _number(double value) {
    if (!value.isFinite) return '—';
    // Four places is enough for millimetre drawings without turning every row
    // into a wall of trailing zeros.
    final text = value.toStringAsFixed(4);
    return text.contains('.')
        ? text.replaceFirst(RegExp(r'\.?0+$'), '')
        : text;
  }

  static Color? _colorSwatch(
    DocumentTab tab,
    List<CadEntity> entities,
    FanCadTokens tokens,
  ) {
    final resolved = _shared(entities, (entity) {
      final color = entity.props.color;
      if (color.kind != ColorKind.byLayer) return color;
      return tab.document.layer(entity.props.layer)?.color ?? color;
    });
    if (resolved == null) return null;
    final palette = tokens.isDark ? AciPalette.dark : AciPalette.light;
    return palette.colorOf(resolved);
  }

  static String _lineWeight(int weight) {
    if (weight == LineWeight.byLayer) return 'ByLayer';
    if (weight == LineWeight.byBlock) return 'ByBlock';
    if (weight == LineWeight.byDefault) return 'Default';
    if (weight == LineWeight.zero) return 'Hairline';
    final mm = LineWeight.toMillimetres(weight);
    final text = mm == mm.roundToDouble() ? mm.toStringAsFixed(0) : '$mm';
    return '$text mm';
  }

  static Widget _placeholder(BuildContext context, String message) => Center(
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

class _EmptySelection extends StatelessWidget {
  const _EmptySelection({required this.objectCount, this.onSelectAll});

  final int objectCount;
  final VoidCallback? onSelectAll;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FanCadTokens.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              objectCount == 0
                  ? 'This drawing is empty.'
                  : 'Click an object on the canvas to inspect it.',
              style: tokens.bodyStyle,
              textAlign: TextAlign.center,
            ),
            if (onSelectAll != null) ...[
              const SizedBox(height: FanCadTokens.space3),
              Text(
                '$objectCount object${objectCount == 1 ? '' : 's'} in this drawing.',
                style: tokens.labelStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: FanCadTokens.space2),
              ShellRow(
                onTap: onSelectAll,
                height: 28,
                padding: const EdgeInsets.symmetric(
                  horizontal: FanCadTokens.space2,
                ),
                child: Text(
                  'Select all',
                  style: tokens.bodyStyle.copyWith(color: tokens.accent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
