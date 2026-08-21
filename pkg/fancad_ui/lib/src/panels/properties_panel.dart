import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';
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
              ? _placeholder(context, 'Nothing is selected.')
              : ListView(
                  padding: const EdgeInsets.only(bottom: FanCadTokens.space4),
                  children: [
                    PanelSection(
                      title: entities.length == 1
                          ? _titleFor(entities.first)
                          : '${entities.length} objects selected',
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

  static String _titleFor(CadEntity entity) =>
      '${entity.kind.name} #${entity.id}';

  List<Widget> _generalRows(
    BuildContext context,
    DocumentTab tab,
    List<CadEntity> entities,
  ) {
    final layer = _shared(entities, (entity) => entity.props.layer);
    final color = _shared(
      entities,
      (entity) => cadColorToJson(entity.props.color)?.toString() ?? 'ByLayer',
    );
    final lineType = _shared(entities, (entity) => entity.props.lineType);
    return [
      PropertyRow(
        label: 'Layer',
        isEditable: true,
        value: Text(layer ?? '*Varies*'),
        onTap: () => workspace.run('edit.changeLayer'),
      ),
      PropertyRow(
        label: 'Colour',
        isEditable: true,
        value: Text(color ?? '*Varies*'),
        onTap: () => workspace.run('edit.changeColor'),
      ),
      PropertyRow(label: 'Line type', value: Text(lineType ?? '*Varies*')),
    ];
  }

  List<Widget> _geometryRows(BuildContext context, CadEntity entity) {
    switch (entity) {
      case LineEntity(:final start, :final end, :final length):
        final delta = end - start;
        return [
          PropertyRow(label: 'Start', value: Text(_point(start))),
          PropertyRow(label: 'End', value: Text(_point(end))),
          PropertyRow(label: 'Length', value: Text(_number(length))),
          PropertyRow(
            label: 'Angle',
            value: Text('${_number(delta.angle * 180 / math.pi)}°'),
          ),
        ];
      case CircleEntity(:final center, :final radius):
        return [
          PropertyRow(label: 'Centre', value: Text(_point(center))),
          PropertyRow(label: 'Radius', value: Text(_number(radius))),
          PropertyRow(label: 'Diameter', value: Text(_number(radius * 2))),
          PropertyRow(
            label: 'Circumference',
            value: Text(_number(2 * math.pi * radius)),
          ),
        ];
      case ArcEntity(:final center, :final radius):
        return [
          PropertyRow(label: 'Centre', value: Text(_point(center))),
          PropertyRow(label: 'Radius', value: Text(_number(radius))),
          PropertyRow(
            label: 'Start angle',
            value: Text('${_number(entity.startAngle * 180 / math.pi)}°'),
          ),
          PropertyRow(
            label: 'End angle',
            value: Text('${_number(entity.endAngle * 180 / math.pi)}°'),
          ),
          PropertyRow(
            label: 'Total angle',
            value: Text('${_number(entity.sweep * 180 / math.pi)}°'),
          ),
        ];
      case PolylineEntity():
        return [
          PropertyRow(
            label: 'Vertices',
            value: Text('${entity.vertexCount}'),
          ),
          PropertyRow(
            label: 'Closed',
            value: Text(entity.closed ? 'Yes' : 'No'),
          ),
          PropertyRow(
            label: 'Length',
            value: Text(_number(Construct.lengthOf(entity))),
          ),
        ];
      case TextEntity(:final content, :final position, :final height):
        return [
          PropertyRow(label: 'Contents', value: Text(content)),
          PropertyRow(label: 'Position', value: Text(_point(position))),
          PropertyRow(label: 'Height', value: Text(_number(height))),
          PropertyRow(
            label: 'Rotation',
            value: Text('${_number(entity.rotation * 180 / math.pi)}°'),
          ),
          PropertyRow(label: 'Style', value: Text(entity.styleName)),
        ];
      case MTextEntity(:final content, :final position):
        return [
          PropertyRow(label: 'Contents', value: Text(content)),
          PropertyRow(label: 'Position', value: Text(_point(position))),
          PropertyRow(
            label: 'Column width',
            value: Text(_number(entity.rectangleWidth)),
          ),
        ];
      case InsertEntity(:final blockName, :final position):
        return [
          PropertyRow(label: 'Block', value: Text(blockName)),
          PropertyRow(label: 'Position', value: Text(_point(position))),
          PropertyRow(
            label: 'Scale',
            value: Text(
              '${_number(entity.scale.x)}, ${_number(entity.scale.y)}',
            ),
          ),
          PropertyRow(
            label: 'Rotation',
            value: Text('${_number(entity.rotation * 180 / math.pi)}°'),
          ),
        ];
      case PointEntity(:final position):
        return [PropertyRow(label: 'Position', value: Text(_point(position)))];
      case HatchEntity(:final patternName, :final solid):
        return [
          PropertyRow(label: 'Pattern', value: Text(patternName)),
          PropertyRow(label: 'Solid fill', value: Text(solid ? 'Yes' : 'No')),
          PropertyRow(
            label: 'Boundaries',
            value: Text('${entity.loops.length}'),
          ),
        ];
      case DimensionEntity(:final measurement, :final displayText):
        return [
          PropertyRow(label: 'Measurement', value: Text(_number(measurement))),
          PropertyRow(label: 'Text', value: Text(displayText)),
          PropertyRow(label: 'Style', value: Text(entity.styleName)),
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
      PropertyRow(label: 'Total length', value: Text(_number(length))),
      if (area > 0)
        PropertyRow(label: 'Total area', value: Text(_number(area))),
      if (box.isNotEmpty) ...[
        PropertyRow(label: 'Min', value: Text(_point(box.min))),
        PropertyRow(label: 'Max', value: Text(_point(box.max))),
        PropertyRow(
          label: 'Size',
          value: Text('${_number(box.width)} × ${_number(box.height)}'),
        ),
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
