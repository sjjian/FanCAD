import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

/// One undo entry for a batch of adds, erases, transforms and property edits.
///
/// Scripts and `fancad.commands.execute` use this instead of a second drawing
/// API. The operation list is the same shape `document.beginEdit()` builds.
class EditApplyCommand extends FanCadCommand {
  const EditApplyCommand();

  @override
  String get id => 'edit.apply';
  @override
  String get title => 'Apply Edit';
  @override
  String get category => _category;
  @override
  CommandRisk get risk => CommandRisk.edit;

  /// Erasing is destructive here for the same reason `edit.erase` is.
  @override
  CommandRisk riskFor(Map<String, Object?> args) {
    if (args['replace'] == true) return CommandRisk.destructive;
    final operations = args['operations'];
    if (operations is List &&
        operations.any((item) => item is Map && item['op'] == 'erase')) {
      return CommandRisk.destructive;
    }
    return risk;
  }

  @override
  String get description =>
      'Applies a list of add, erase, transform and property operations as '
      'one undo entry. Each add is {op, kind, geometry, props}. Use this '
      'when several objects must undo together.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'operations',
      type: ParamType.json,
      description:
          'Array of operations: add, erase, transform, or props. '
          'An add names kind line, polyline, circle, arc, point or text.',
    ),
    ParamSpec(
      name: 'label',
      type: ParamType.text,
      description: 'Undo label',
      required: false,
    ),
    ParamSpec(
      name: 'replace',
      type: ParamType.boolean,
      description: 'Erase every entity before applying the operations',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final raw = context.args['operations'];
    if (raw is! List) {
      return const CommandResult.failed(
        'edit.apply needs operations, an array of edits.',
      );
    }
    final label = context.args.text('label');
    final undoLabel = label == null || label.isEmpty ? 'Edit' : label;
    final created = <int>[];
    final blocked = <String>{};
    CommittedTransaction? committed;
    try {
      committed = context.edit(undoLabel, (transaction) {
        if (context.args.boolean('replace') == true) {
          for (final entity in context.document.entities.toList()) {
            transaction.erase(entity.id);
          }
        }
        for (final item in raw) {
          if (item is! Map) continue;
          final operation = Map<String, Object?>.from(item);
          switch (operation['op']) {
            case 'add':
              created.add(
                transaction.add(_buildEntity(context.document, operation)),
              );
            case 'erase':
              for (final id in _idsOf(operation['ids'])) {
                if (_isLocked(context.document, id)) {
                  blocked.add('$id');
                  continue;
                }
                transaction.erase(id);
              }
            case 'transform':
              final matrix = _transformMatrix(operation);
              for (final id in _idsOf(operation['ids'])) {
                final entity = context.document.entity(id);
                if (entity == null) continue;
                if (_isLocked(context.document, id)) {
                  blocked.add('$id');
                  continue;
                }
                transaction.modify(entity.transformed(matrix));
              }
            case 'props':
              final props = operation['props'];
              if (props is! Map) break;
              for (final id in _idsOf(operation['ids'])) {
                final entity = context.document.entity(id);
                if (entity == null) continue;
                if (_isLocked(context.document, id)) {
                  blocked.add('$id');
                  continue;
                }
                transaction.modify(
                  entity.withProps(
                    _mergeProps(entity.props, Map<String, Object?>.from(props)),
                  ),
                );
              }
            default:
              throw _EditFailure('unknown operation "${operation['op']}"');
          }
        }
      });
    } on _EditFailure catch (error) {
      return CommandResult.failed(error.message);
    }
    return CommandResult.ok(
      message: created.isEmpty
          ? 'Applied $undoLabel.'
          : 'Applied $undoLabel, ${created.length} object(s).',
      data: {
        'applied': committed != null,
        'created': created,
        if (blocked.isNotEmpty) 'blockedByLockedLayer': blocked.toList(),
        if (committed != null) 'label': committed.label,
      },
    );
  }
}

class _EditFailure implements Exception {
  _EditFailure(this.message);
  final String message;
}

bool _isLocked(CadDocument document, int id) {
  final entity = document.entity(id);
  if (entity == null) return false;
  return document.layers[entity.props.layer]?.locked ?? false;
}

EntityProps _mergeProps(EntityProps base, Map<String, Object?> patch) {
  var next = base;
  final layer = patch['layer'];
  if (layer is String) next = next.copyWith(layer: layer);
  if (patch.containsKey('color')) {
    next = next.copyWith(color: cadColorFromJson(patch['color']));
  }
  final lineType = patch['lineType'];
  if (lineType is String) next = next.copyWith(lineType: lineType);
  final lineWeight = (patch['lineWeight'] as num?)?.toInt();
  if (lineWeight != null) next = next.copyWith(lineWeight: lineWeight);
  final lineTypeScale = (patch['lineTypeScale'] as num?)?.toDouble();
  if (lineTypeScale != null) {
    next = next.copyWith(lineTypeScale: lineTypeScale);
  }
  final visible = patch['visible'];
  if (visible is bool) next = next.copyWith(visible: visible);
  return next;
}

List<int> _idsOf(Object? raw) => [
  if (raw is num) raw.toInt(),
  if (raw is List)
    for (final value in raw)
      if (value is num) value.toInt(),
];

CadEntity _buildEntity(CadDocument document, Map<String, Object?> operation) {
  final props = _entityProps(document, operation['props']);
  final kind = '${operation['kind']}';
  switch (kind) {
    case 'line':
      return LineEntity(
        id: 0,
        props: props,
        start: _point(operation, 'start'),
        end: _point(operation, 'end'),
      );
    case 'polyline':
      final raw = operation['points'];
      if (raw is! List || raw.length < 2) {
        throw _EditFailure('a polyline needs at least two points');
      }
      return PolylineEntity.fromPoints(
        id: 0,
        props: props,
        points: [
          for (final value in raw)
            CommandArgs.parsePoint(value) ??
                (throw _EditFailure('a polyline point must be [x, y]')),
        ],
        closed: operation['closed'] == true,
      );
    case 'circle':
      return CircleEntity(
        id: 0,
        props: props,
        center: _point(operation, 'center'),
        radius: _positive(operation, 'radius'),
      );
    case 'arc':
      return ArcEntity(
        id: 0,
        props: props,
        center: _point(operation, 'center'),
        radius: _positive(operation, 'radius'),
        startAngle: _double(operation, 'startAngle') ?? 0,
        endAngle: _double(operation, 'endAngle') ?? 0,
      );
    case 'point':
      return PointEntity(
        id: 0,
        props: props,
        position: _point(operation, 'position'),
      );
    case 'text':
      return TextEntity(
        id: 0,
        props: props,
        position: _point(operation, 'position'),
        content: '${operation['text'] ?? ''}',
        height: _double(operation, 'height') ?? 2.5,
        rotation: _double(operation, 'rotation') ?? 0,
      );
    default:
      throw _EditFailure('cannot create entities of kind "$kind"');
  }
}

EntityProps _entityProps(CadDocument document, Object? raw) {
  final props = raw is Map
      ? Map<String, Object?>.from(raw)
      : const <String, Object?>{};
  final layer = props['layer'];
  // An unknown layer name falls back to the current layer rather than
  // failing: a caller should not have to synchronise its layer table with the
  // drawing before it can draw a line.
  return EntityProps(
    layer: layer is String && document.layers.containsKey(layer)
        ? layer
        : document.currentLayer,
    color: cadColorFromJson(props['color']),
    lineType: props['lineType'] is String
        ? props['lineType'] as String
        : 'ByLayer',
    lineWeight: (props['lineWeight'] as num?)?.toInt() ?? LineWeight.byLayer,
  );
}

Vec2 _point(Map<String, Object?> operation, String key) {
  final value = CommandArgs.parsePoint(operation[key]);
  if (value == null) {
    throw _EditFailure('"$key" must be a point like [x, y]');
  }
  return value;
}

double _positive(Map<String, Object?> operation, String key) {
  final value = _double(operation, key);
  if (value == null || value <= 0) {
    throw _EditFailure('"$key" must be greater than zero');
  }
  return value;
}

double? _double(Map<String, Object?> operation, String key) {
  final value = operation[key];
  return value is num ? value.toDouble() : null;
}

Mat3 _transformMatrix(Map<String, Object?> operation) {
  var matrix = const Mat3.identity();
  final translate = CommandArgs.parsePoint(operation['translate']);
  if (translate != null) {
    matrix = Mat3.translation(translate.x, translate.y).multiplied(matrix);
  }
  final rotate = operation['rotate'];
  if (rotate is num) {
    matrix = Mat3.rotation(rotate.toDouble()).multiplied(matrix);
  } else if (rotate is Map) {
    final angle = (rotate['angle'] as num?)?.toDouble();
    if (angle == null) {
      throw _EditFailure('rotate.angle must be a number in radians');
    }
    final origin =
        CommandArgs.parsePoint(rotate['origin']) ?? const Vec2.zero();
    matrix = Mat3.rotationAbout(angle, origin).multiplied(matrix);
  }
  final scale = operation['scale'];
  if (scale is num) {
    matrix = Mat3.scaling(
      scale.toDouble(),
      scale.toDouble(),
    ).multiplied(matrix);
  } else if (scale is Map) {
    final factor = (scale['factor'] as num?)?.toDouble();
    final sx = factor ?? (scale['sx'] as num?)?.toDouble();
    final sy = factor ?? (scale['sy'] as num?)?.toDouble() ?? sx;
    if (sx == null || sy == null) {
      throw _EditFailure('scale needs factor or sx and sy');
    }
    final origin = CommandArgs.parsePoint(scale['origin']);
    final scaling = origin == null
        ? Mat3.scaling(sx, sy)
        : Mat3.scalingAbout(sx, sy, origin);
    matrix = scaling.multiplied(matrix);
  }
  final mirror = operation['mirror'];
  if (mirror is Map) {
    final start = CommandArgs.parsePoint(mirror['start']);
    final end = CommandArgs.parsePoint(mirror['end']);
    if (start == null || end == null) {
      throw _EditFailure('mirror needs start and end points');
    }
    matrix = Mat3.mirror(start, end - start).multiplied(matrix);
  }
  if (translate == null && rotate == null && scale == null && mirror == null) {
    throw _EditFailure('transform needs translate, rotate, scale or mirror');
  }
  return matrix;
}
