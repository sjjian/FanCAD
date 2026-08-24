import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
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
          PanelHeader(title: context.l10n.properties),
          Expanded(
            child: _placeholder(
              context,
              context.l10n.properties_empty_workspace,
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
          title: context.l10n.properties,
          actions: [
            if (entities.isNotEmpty) ...[
              ShellIconButton(
                icon: Icons.center_focus_strong,
                tooltip: context.l10n.zoom_to_selection,
                iconSize: FanCadTokens.iconMedium,
                onPressed: () => workspace.run('view.zoomSelected'),
              ),
              ShellIconButton(
                icon: Icons.deselect,
                tooltip: context.l10n.clear_selection,
                iconSize: FanCadTokens.iconMedium,
                onPressed: () => workspace.run('select.none'),
              ),
            ],
            ShellIconButton(
              icon: Icons.info_outline,
              tooltip: context.l10n.list_selection,
              iconSize: FanCadTokens.iconMedium,
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
                        title: context.l10n.geometry,
                        children: _geometryRows(context, entities.first),
                      ),
                    PanelSection(
                      title: context.l10n.measurements,
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

  void _copied(BuildContext context, String text) =>
      workspace.notify(context.l10n.copied_text(text));

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
    final l10n = context.l10n;
    final swatch = _colorSwatch(tab, entities, tokens);
    return [
      PropertyRow(
        label: l10n.layer,
        isEditable: true,
        copyText: layer,
        onCopied: (text) => _copied(context, text),
        value: Text(layer ?? '*Varies*'),
        onTap: () => workspace.run('edit.changeLayer'),
      ),
      PropertyRow(
        label: l10n.colour,
        isEditable: true,
        copyText: colorLabel,
        onCopied: (text) => _copied(context, text),
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
        label: l10n.line_type,
        isEditable: true,
        copyText: lineType,
        onCopied: (text) => _copied(context, text),
        value: Text(lineType ?? '*Varies*'),
        onTap: () => workspace.run('edit.changeLinetype'),
      ),
      PropertyRow(
        label: l10n.lineweight,
        isEditable: true,
        copyText: lineWeight == null ? null : _lineWeight(l10n, lineWeight),
        onCopied: (text) => _copied(context, text),
        value: Text(
          lineWeight == null ? '*Varies*' : _lineWeight(l10n, lineWeight),
        ),
        onTap: () => workspace.run('edit.changeLineweight'),
      ),
    ];
  }

  PropertyRow _read(BuildContext context, String label, String text) =>
      PropertyRow(
        label: label,
        value: Text(text),
        copyText: text,
        onCopied: (value) => _copied(context, value),
      );

  List<Widget> _geometryRows(BuildContext context, CadEntity entity) {
    final l10n = context.l10n;
    switch (entity) {
      case LineEntity(:final start, :final end, :final length):
        final delta = end - start;
        return [
          _read(context, l10n.start, _point(start)),
          _read(context, l10n.end, _point(end)),
          _read(context, l10n.length, _number(length)),
          _read(context, l10n.angle, '${_number(delta.angle * 180 / math.pi)}°'),
        ];
      case CircleEntity(:final center, :final radius):
        return [
          _read(context, l10n.centre, _point(center)),
          _read(context, l10n.radius, _number(radius)),
          _read(context, l10n.diameter, _number(radius * 2)),
          _read(context, l10n.circumference, _number(2 * math.pi * radius)),
        ];
      case ArcEntity(:final center, :final radius):
        return [
          _read(context, l10n.centre, _point(center)),
          _read(context, l10n.radius, _number(radius)),
          _read(context, l10n.start_angle, '${_number(entity.startAngle * 180 / math.pi)}°'),
          _read(context, l10n.end_angle, '${_number(entity.endAngle * 180 / math.pi)}°'),
          _read(context, l10n.total_angle, '${_number(entity.sweep * 180 / math.pi)}°'),
        ];
      case PolylineEntity():
        return [
          _read(context, l10n.vertices, '${entity.vertexCount}'),
          _read(context, l10n.closed, entity.closed ? l10n.yes : l10n.no),
          _read(context, l10n.length, _number(Construct.lengthOf(entity))),
        ];
      case TextEntity(:final content, :final position, :final height):
        return [
          _read(context, l10n.contents, content),
          _read(context, l10n.position, _point(position)),
          _read(context, l10n.height, _number(height)),
          _read(context, l10n.rotation, '${_number(entity.rotation * 180 / math.pi)}°'),
          _read(context, l10n.style, entity.styleName),
        ];
      case MTextEntity(:final content, :final position):
        return [
          _read(context, l10n.contents, content),
          _read(context, l10n.position, _point(position)),
          _read(context, l10n.column_width, _number(entity.rectangleWidth)),
        ];
      case InsertEntity(:final blockName, :final position):
        return [
          _read(context, l10n.block, blockName),
          _read(context, l10n.position, _point(position)),
          _read(
            context,
            l10n.scale,
            '${_number(entity.scale.x)}, ${_number(entity.scale.y)}',
          ),
          _read(context, l10n.rotation, '${_number(entity.rotation * 180 / math.pi)}°'),
        ];
      case PointEntity(:final position):
        return [_read(context, l10n.position, _point(position))];
      case HatchEntity(:final patternName, :final solid):
        return [
          _read(context, l10n.pattern, patternName),
          _read(context, l10n.solid_fill, solid ? l10n.yes : l10n.no),
          _read(context, l10n.boundaries, '${entity.loops.length}'),
        ];
      case DimensionEntity(:final measurement, :final displayText):
        return [
          _read(context, l10n.measurement, _number(measurement)),
          _read(context, l10n.text, displayText),
          _read(context, l10n.style, entity.styleName),
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
    final l10n = context.l10n;
    return [
      _read(context, l10n.total_length, _number(length)),
      if (area > 0) _read(context, l10n.total_area, _number(area)),
      if (box.isNotEmpty) ...[
        _read(context, l10n.min, _point(box.min)),
        _read(context, l10n.max, _point(box.max)),
        _read(context, l10n.size, '${_number(box.width)} × ${_number(box.height)}'),
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

  static String _lineWeight(AppLocalizations l10n, int weight) {
    if (weight == LineWeight.byLayer) return l10n.by_layer;
    if (weight == LineWeight.byBlock) return l10n.by_block;
    if (weight == LineWeight.byDefault) return l10n.default_value;
    if (weight == LineWeight.zero) return l10n.hairline;
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
                  ? context.l10n.drawing_empty_inspect
                  : context.l10n.click_object_inspect,
              style: tokens.bodyStyle,
              textAlign: TextAlign.center,
            ),
            if (onSelectAll != null) ...[
              const SizedBox(height: FanCadTokens.space3),
              Text(
                objectCount == 1
                    ? context.l10n.objects_in_drawing_one
                    : context.l10n.objects_in_drawing_many(objectCount),
                style: tokens.labelStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: FanCadTokens.space2),
              ShellRow(
                onTap: onSelectAll,
                height: FanCadTokens.rowHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: FanCadTokens.space2,
                ),
                child: Text(
                  context.l10n.select_all,
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
