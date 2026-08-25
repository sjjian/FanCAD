import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

/// Read-only commands that answer questions about the drawing.
///
/// These matter out of proportion to their size, because they are what the AI
/// layer uses instead of being handed the whole drawing. A model that can ask
/// "how many objects are on layer WALLS and where are they" does not need a
/// megabyte of geometry in its context window to answer a question about it.
class QueryCommands {
  const QueryCommands._();

  static List<CommandDescriptor> all() => [
    _summary(),
    _list(),
    _query(),
    _selection(),
    _viewport(),
    _id(),
    _distance(),
    _angle(),
    _area(),
    _layerList(),
  ];

  static const String _category = 'Inquiry';

  static CommandDescriptor _summary() => CommandDescriptor(
    id: 'query.summary',
    title: 'Drawing Summary',
    category: _category,
    aliases: const ['summary'],
    risk: CommandRisk.readOnly,
    description:
        'Returns a compact statistical summary of the drawing: extents, entity '
        'counts by type, and per-layer counts. Use this first to understand a '
        'drawing before querying its contents.',
    handler: (context) async {
      final document = context.document;
      final byKind = <String, int>{};
      final byLayer = <String, int>{};
      for (final entity in document.activeEntities) {
        byKind.update(entity.kind.name, (n) => n + 1, ifAbsent: () => 1);
        byLayer.update(entity.props.layer, (n) => n + 1, ifAbsent: () => 1);
      }
      final extents = document.extents;
      final data = {
        'entityCount': document.entityCount,
        'activeLayout': document.activeLayoutName,
        'currentLayer': document.currentLayer,
        'extents': extents.isEmpty
            ? null
            : {
                'min': [extents.minX, extents.minY],
                'max': [extents.maxX, extents.maxY],
              },
        'byKind': byKind,
        'byLayer': byLayer,
        'layers': [
          for (final layer in document.layers.values)
            {
              'name': layer.name,
              'visible': layer.isEffectivelyVisible,
              'locked': layer.locked,
              'count': byLayer[layer.name] ?? 0,
            },
        ],
        'blocks': [
          for (final block in document.blocks.values)
            if (!block.isLayoutBlock) block.name,
        ],
      };
      return CommandResult(
        status: CommandStatus.ok,
        message: _describeSummary(document, byKind, extents),
        data: data,
      );
    },
  );

  static String _describeSummary(
    CadDocument document,
    Map<String, int> byKind,
    Bounds2 extents,
  ) {
    final kinds = byKind.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = kinds
        .take(5)
        .map((entry) => '${entry.value} ${entry.key}')
        .join(', ');
    final size = extents.isEmpty
        ? 'empty'
        : '${extents.width.toStringAsFixed(1)} x '
              '${extents.height.toStringAsFixed(1)}';
    return '${document.entityCount} objects ($top) across '
        '${document.layers.length} layers, extents $size.';
  }

  static CommandDescriptor _list() => CommandDescriptor(
    id: 'query.list',
    title: 'List',
    category: _category,
    aliases: const ['li', 'list'],
    risk: CommandRisk.readOnly,
    description: 'Reports the full properties of the selected objects.',
    params: const [ParamSpec.selection('ids')],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'LIST  Select objects:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();
      final records = <Map<String, Object?>>[];
      for (final id in ids.take(500)) {
        final entity = context.document.entity(id);
        if (entity == null) continue;
        records.add(_describe(context.document, entity));
      }
      for (final record in records.take(20)) {
        context.input.write(_formatRecord(record));
      }
      if (records.length > 20) {
        context.input.write('... and ${records.length - 20} more.');
      }
      context.services.revealPanel('properties');
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Listed ${records.length} object(s).',
        data: {'entities': records},
      );
    },
  );

  static CommandDescriptor _query() => CommandDescriptor(
    id: 'query.entities',
    title: 'Query Entities',
    category: _category,
    risk: CommandRisk.readOnly,
    description:
        'Finds entities matching optional filters and returns their ids and '
        'properties. Use layer, kind and a bounding window to narrow a large '
        'drawing to the part you care about.',
    params: const [
      ParamSpec(
        name: 'layer',
        type: ParamType.layer,
        description: 'Restrict to one layer',
        required: false,
      ),
      ParamSpec(
        name: 'kind',
        type: ParamType.text,
        description: 'Restrict to one entity type, for example line or circle',
        required: false,
      ),
      ParamSpec(
        name: 'window',
        type: ParamType.json,
        description: 'Bounding box as [minX, minY, maxX, maxY]',
        required: false,
      ),
      ParamSpec(
        name: 'limit',
        type: ParamType.integer,
        description: 'Maximum number of results',
        required: false,
        defaultValue: 200,
      ),
    ],
    handler: (context) async {
      final layer = context.args.text('layer');
      final kind = context.args.text('kind')?.toLowerCase();
      final limit = context.args.integer('limit') ?? 200;
      final windowValues = context.args['window'];
      Bounds2? window;
      if (windowValues is List && windowValues.length >= 4) {
        final numbers = [
          for (final value in windowValues) (value as num).toDouble(),
        ];
        window = Bounds2(numbers[0], numbers[1], numbers[2], numbers[3]);
      }

      // The spatial index turns a windowed query from a full scan into a tree
      // descent, which is the difference between a usable AI tool and a timeout
      // on a large drawing.
      final candidates = window == null
          ? context.document.activeEntities
          : [
              for (final id in context.document.queryVisible(window))
                ?context.document.entity(id),
            ];

      final matches = <Map<String, Object?>>[];
      var total = 0;
      for (final entity in candidates) {
        if (layer != null && entity.props.layer != layer) continue;
        if (kind != null && entity.kind.name.toLowerCase() != kind) continue;
        total++;
        if (matches.length < limit) {
          matches.add(_describe(context.document, entity));
        }
      }
      return CommandResult(
        status: CommandStatus.ok,
        message: total <= limit
            ? '$total object(s) matched.'
            : '$total object(s) matched; the first $limit are returned.',
        data: {
          'total': total,
          'returned': matches.length,
          'entities': matches,
        },
      );
    },
  );

  static CommandDescriptor _selection() => CommandDescriptor(
    id: 'query.selection',
    title: 'Query Selection',
    category: _category,
    risk: CommandRisk.readOnly,
    description:
        'Returns the current selection as structured records (id, kind, '
        'layer, bounds, short geometry). Use this instead of guessing ids. '
        'An empty selection is a successful empty list, not a prompt.',
    handler: (context) async {
      final ids = context.selection.ids.toList();
      final records = <Map<String, Object?>>[];
      for (final id in ids.take(200)) {
        final entity = context.document.entity(id);
        if (entity == null) continue;
        records.add(_describe(context.document, entity));
      }
      return CommandResult(
        status: CommandStatus.ok,
        message: ids.isEmpty
            ? 'Nothing is selected.'
            : ids.length == 1
            ? '1 object selected.'
            : '${ids.length} objects selected.',
        data: {
          'count': ids.length,
          'returned': records.length,
          'entities': records,
        },
      );
    },
  );

  static CommandDescriptor _viewport() => CommandDescriptor(
    id: 'query.viewport',
    title: 'Query Viewport',
    category: _category,
    risk: CommandRisk.readOnly,
    description:
        'Returns the active camera: centre, scale and visible window as '
        '[minX, minY, maxX, maxY]. Pass that window to query.entities to '
        'list what the user is looking at.',
    handler: (context) async {
      final view = context.services.describeView();
      if (view.isEmpty) {
        return const CommandResult.failed('No view is open.');
      }
      final visible = view['visible'];
      final center = view['center'];
      final scale = view['scale'];
      final message = visible is List && visible.length >= 4
          ? 'Visible [${_num(visible[0])}, ${_num(visible[1])}, '
                '${_num(visible[2])}, ${_num(visible[3])}], '
                'scale ${_num(scale)}.'
          : center is List && center.length >= 2
          ? 'Viewport centre (${_num(center[0])}, ${_num(center[1])}), '
                'scale ${_num(scale)}; size is not known yet.'
          : 'Viewport reported.';
      return CommandResult(
        status: CommandStatus.ok,
        message: message,
        data: view,
      );
    },
  );

  static String _num(Object? value) {
    if (value is num) return value.toStringAsFixed(2);
    return '$value';
  }

  static CommandDescriptor _id() => CommandDescriptor(
    id: 'query.id',
    title: 'ID Point',
    category: _category,
    aliases: const ['id'],
    risk: CommandRisk.readOnly,
    description:
        'Reports the X and Y coordinates of a point. Use this when you need '
        'a location, not a distance between two locations.',
    params: const [ParamSpec.point('at', description: 'The point to identify')],
    handler: (context) async {
      final at = await context.resolvePoint('at', 'ID  Specify point:');
      context.input.write(
        '  X = ${at.x.toStringAsFixed(4)}  Y = ${at.y.toStringAsFixed(4)}',
      );
      return CommandResult(
        status: CommandStatus.ok,
        message:
            'X = ${at.x.toStringAsFixed(4)}, Y = ${at.y.toStringAsFixed(4)}',
        data: {'x': at.x, 'y': at.y},
      );
    },
  );

  static CommandDescriptor _distance() => CommandDescriptor(
    id: 'query.distance',
    title: 'Distance',
    category: _category,
    aliases: const ['di', 'dist'],
    risk: CommandRisk.readOnly,
    description: 'Measures the distance and angle between two points.',
    params: const [
      ParamSpec.point('from'),
      ParamSpec.point('to'),
    ],
    handler: (context) async {
      final from = await context.resolvePoint(
        'from',
        'DIST  Specify first point:',
      );
      context.input.setPreview((cursor) => [OverlayLine(from, cursor)]);
      final to = await context.resolvePoint(
        'to',
        'DIST  Specify second point:',
        basePoint: from,
      );
      context.input.setPreview(null);

      final delta = to - from;
      final degrees = delta.angle * 180 / math.pi;
      return CommandResult(
        status: CommandStatus.ok,
        message:
            'Distance = ${delta.length.toStringAsFixed(4)}, '
            'angle = ${degrees.toStringAsFixed(2)}°, '
            'dX = ${delta.x.toStringAsFixed(4)}, '
            'dY = ${delta.y.toStringAsFixed(4)}',
        data: {
          'distance': delta.length,
          'angle': degrees,
          'dx': delta.x,
          'dy': delta.y,
        },
      );
    },
  );

  static CommandDescriptor _angle() => CommandDescriptor(
    id: 'query.angle',
    title: 'Angle',
    category: _category,
    aliases: const ['ang', 'angle'],
    risk: CommandRisk.readOnly,
    description:
        'Measures the angle at a vertex between two rays. The first point is '
        'the vertex; the next two define the sides.',
    params: const [
      ParamSpec.point('vertex', description: 'Vertex of the angle'),
      ParamSpec.point('first', description: 'A point on the first ray'),
      ParamSpec.point('second', description: 'A point on the second ray'),
    ],
    handler: (context) async {
      final vertex = await context.resolvePoint(
        'vertex',
        'ANGLE  Specify vertex:',
      );
      context.input
        ..setMarkers([vertex])
        ..setPreview((cursor) => [OverlayLine(vertex, cursor)]);
      final first = await context.resolvePoint(
        'first',
        'ANGLE  Specify a point on the first ray:',
        basePoint: vertex,
      );
      context.input
        ..setMarkers([vertex, first])
        ..setPreview((cursor) {
          final radius = vertex.distanceTo(first);
          if (radius <= 0) return [OverlayLine(vertex, cursor)];
          final start = (first - vertex).angle;
          var sweep = (cursor - vertex).angle - start;
          while (sweep <= -math.pi) {
            sweep += math.pi * 2;
          }
          while (sweep > math.pi) {
            sweep -= math.pi * 2;
          }
          return [
            OverlayLine(vertex, first),
            OverlayLine(vertex, cursor),
            OverlayArc(
              center: vertex,
              radius: radius * 0.35,
              startAngle: sweep >= 0 ? start : start + sweep,
              sweep: sweep.abs(),
            ),
          ];
        });
      final second = await context.resolvePoint(
        'second',
        'ANGLE  Specify a point on the second ray:',
        basePoint: vertex,
      );
      context.input
        ..setPreview(null)
        ..setMarkers(const []);

      final firstDir = first - vertex;
      final secondDir = second - vertex;
      if (firstDir.lengthSquared < 1e-20 || secondDir.lengthSquared < 1e-20) {
        return const CommandResult.failed(
          'Each ray needs a point distinct from the vertex.',
        );
      }
      var sweep = secondDir.angle - firstDir.angle;
      while (sweep <= -math.pi) {
        sweep += math.pi * 2;
      }
      while (sweep > math.pi) {
        sweep -= math.pi * 2;
      }
      final signed = sweep * 180 / math.pi;
      final interior = sweep.abs() * 180 / math.pi;
      context.input.write(
        '  Angle = ${interior.toStringAsFixed(4)}°  '
        '(signed ${signed.toStringAsFixed(4)}°)',
      );
      return CommandResult(
        status: CommandStatus.ok,
        message:
            'Angle = ${interior.toStringAsFixed(4)}°, '
            'signed = ${signed.toStringAsFixed(2)}°',
        data: {
          'angle': interior,
          'signed': signed,
        },
      );
    },
  );

  static CommandDescriptor _area() => CommandDescriptor(
    id: 'query.area',
    title: 'Area',
    category: _category,
    aliases: const ['aa', 'area'],
    risk: CommandRisk.readOnly,
    description:
        'Reports the area and perimeter of the selected closed objects.',
    params: const [ParamSpec.selection('ids')],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'AREA  Select closed objects:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();
      var area = 0.0;
      var perimeter = 0.0;
      var counted = 0;
      for (final id in ids) {
        final entity = context.document.entity(id);
        if (entity == null) continue;
        final each = Construct.areaOf(entity).abs();
        if (each == 0) continue;
        area += each;
        perimeter += Construct.lengthOf(entity);
        counted++;
      }
      if (counted == 0) {
        return const CommandResult.failed(
          'None of the selected objects enclose an area.',
        );
      }
      return CommandResult(
        status: CommandStatus.ok,
        message:
            'Area = ${area.toStringAsFixed(4)}, '
            'perimeter = ${perimeter.toStringAsFixed(4)} '
            '($counted object(s)).',
        data: {'area': area, 'perimeter': perimeter, 'count': counted},
      );
    },
  );

  static CommandDescriptor _layerList() => CommandDescriptor(
    id: 'query.layers',
    title: 'List Layers',
    category: _category,
    risk: CommandRisk.readOnly,
    description: 'Returns every layer with its state and object count.',
    handler: (context) async {
      final counts = <String, int>{};
      for (final entity in context.document.entities) {
        counts.update(entity.props.layer, (n) => n + 1, ifAbsent: () => 1);
      }
      final layers = [
        for (final layer in context.document.layers.values)
          {
            'name': layer.name,
            'color': cadColorToJson(layer.color),
            'lineType': layer.lineType,
            'visible': layer.visible,
            'frozen': layer.frozen,
            'locked': layer.locked,
            'current': layer.name == context.document.currentLayer,
            'count': counts[layer.name] ?? 0,
          },
      ];
      return CommandResult(
        status: CommandStatus.ok,
        message: '${layers.length} layer(s).',
        data: {'layers': layers},
      );
    },
  );

  /// A JSON description of an entity, geometry included.
  ///
  /// Kept flat and short on purpose: this is what gets serialised into an AI
  /// context, so every redundant nested object costs tokens that could have
  /// been another entity.
  static Map<String, Object?> _describe(CadDocument document, CadEntity entity) {
    final box = document.boundsOfEntity(entity);
    final record = <String, Object?>{
      'id': entity.id,
      'kind': entity.kind.name,
      'layer': entity.props.layer,
      if (entity.props.color.kind != ColorKind.byLayer)
        'color': cadColorToJson(entity.props.color),
      if (box.isNotEmpty)
        'bounds': [box.minX, box.minY, box.maxX, box.maxY],
    };
    switch (entity) {
      case LineEntity(:final start, :final end, :final length):
        record
          ..['start'] = [start.x, start.y]
          ..['end'] = [end.x, end.y]
          ..['length'] = length;
      case CircleEntity(:final center, :final radius):
        record
          ..['center'] = [center.x, center.y]
          ..['radius'] = radius;
      case ArcEntity(:final center, :final radius):
        record
          ..['center'] = [center.x, center.y]
          ..['radius'] = radius
          ..['startAngle'] = entity.startAngle * 180 / math.pi
          ..['endAngle'] = entity.endAngle * 180 / math.pi;
      case PolylineEntity():
        record
          ..['vertexCount'] = entity.vertexCount
          ..['closed'] = entity.closed
          ..['length'] = Construct.lengthOf(entity);
        // Small polylines are described exactly; large ones would swamp the
        // response, and the bounding box already says where they are.
        if (entity.vertexCount <= 32) {
          record['points'] = [
            for (var i = 0; i < entity.vertexCount; i++)
              [entity.vertexAt(i).x, entity.vertexAt(i).y],
          ];
        }
      case TextEntity(:final content, :final position, :final height):
        record
          ..['text'] = content
          ..['position'] = [position.x, position.y]
          ..['height'] = height;
      case MTextEntity(:final content, :final position):
        record
          ..['text'] = content
          ..['position'] = [position.x, position.y];
      case InsertEntity(:final blockName, :final position):
        record
          ..['block'] = blockName
          ..['position'] = [position.x, position.y];
      case PointEntity(:final position):
        record['position'] = [position.x, position.y];
      case HatchEntity(:final patternName):
        record
          ..['pattern'] = patternName
          ..['area'] = Construct.areaOf(entity).abs();
      case DimensionEntity(:final measurement, :final displayText):
        record
          ..['measurement'] = measurement
          ..['text'] = displayText;
      default:
        break;
    }
    return record;
  }

  static String _formatRecord(Map<String, Object?> record) {
    final parts = <String>[];
    for (final entry in record.entries) {
      if (entry.key == 'id' || entry.key == 'kind') continue;
      final value = entry.value;
      if (value is List && value.length == 2 && value.first is num) {
        parts.add(
          '${entry.key}=(${(value[0] as num).toStringAsFixed(3)}, '
          '${(value[1] as num).toStringAsFixed(3)})',
        );
      } else if (value is num) {
        parts.add('${entry.key}=${value.toStringAsFixed(3)}');
      } else if (value is! List && value != null) {
        parts.add('${entry.key}=$value');
      }
    }
    return '${record['kind']} #${record['id']}  ${parts.join('  ')}';
  }
}
