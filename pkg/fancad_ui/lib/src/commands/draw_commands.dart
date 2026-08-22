import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

/// The drawing commands.
///
/// Every one of these is written as a straight-line script against
/// [CommandInput]. That is the whole trick: the same twenty lines are the
/// interactive LINE command, the scriptable `draw.line` plugin API, and the
/// `draw_line` tool the language model calls, with no branch anywhere for which
/// caller it is serving.
class DrawCommands {
  const DrawCommands._();

  static List<CommandDescriptor> all() => [
    _line(),
    _polyline(),
    _spline(),
    _rectangle(),
    _circle(),
    _circleDiameter(),
    _circle3p(),
    _circleTtr(),
    _donut(),
    _arc(),
    _polygon(),
    _ellipse(),
    _xline(),
    _ray(),
    _point(),
    _divide(),
    _measure(),
    _text(),
    _mtext(),
    _leader(),
    _hatch(),
    _dimLinear(),
    _dimAligned(),
    _dimContinue(),
    _dimBaseline(),
    _dimRadius(),
    _dimDiameter(),
    _centerMark(),
    _centerLine(),
    _dimAngular(),
    _dimStyle(),
  ];

  static const String _category = 'Draw';

  static const ParamSpec _dimStyleParam = ParamSpec(
    name: 'style',
    type: ParamType.text,
    description: 'Dimension style. Defaults to the current DIMSTYLE.',
    required: false,
  );

  static String _dimStyleName(CommandContext context) {
    final name = context.args.text('style')?.trim() ?? '';
    return name.isEmpty ? context.document.currentDimStyle : name;
  }

  static CommandDescriptor _line() => CommandDescriptor(
    id: 'draw.line',
    title: 'Line',
    category: _category,
    aliases: const ['l', 'line'],
    icon: 'line',
    description:
        'Draws one or more connected straight line segments. Supply start and '
        'end to draw a single segment non-interactively.',
    params: const [
      ParamSpec.point('start', description: 'Start of the first segment'),
      ParamSpec.point('end', description: 'End of the first segment'),
    ],
    handler: (context) async {
      final layer = context.document.currentLayer;
      final points = <Vec2>[];

      // The first point has no rubber band to draw, so the preview only
      // becomes interesting from the second prompt onwards.
      final first = await context.input.pointOrNull(
        'LINE  Specify first point:',
      );
      if (first == null) return const CommandResult.cancelled();
      points.add(first);

      final created = <CadEntity>[];
      while (true) {
        context.input
          ..setMarkers(List.of(points))
          ..setPreview(
            (cursor) => [
              if (points.length > 1) OverlayPolyline(List.of(points)),
              OverlayLine(points.last, cursor),
            ],
          );
        final next = await context.input.pointOrNull(
          'LINE  Specify next point (Escape to finish):',
        );
        if (next == null) break;
        if (next.distanceTo(points.last) > 1e-12) {
          created.add(
            LineEntity(
              id: 0,
              props: EntityProps(layer: layer),
              start: points.last,
              end: next,
            ),
          );
        }
        points.add(next);
        // A non-interactive caller supplied exactly two points and has no way
        // to answer a third prompt, so one segment is the whole command.
        if (!context.input.isInteractive) break;
      }
      context.input
        ..setPreview(null)
        ..setMarkers(const []);

      if (created.isEmpty) return const CommandResult.cancelled();
      return _commit(context, 'Line', created);
    },
  );

  static CommandDescriptor _polyline() => CommandDescriptor(
    id: 'draw.polyline',
    title: 'Polyline',
    category: _category,
    aliases: const ['pl', 'pline', 'polyline'],
    icon: 'polyline',
    description:
        'Draws a connected sequence of segments as one polyline entity. Pass a '
        'points array to create it non-interactively.',
    params: const [
      ParamSpec(
        name: 'points',
        type: ParamType.json,
        description: 'Array of [x, y] vertices',
        required: false,
      ),
      ParamSpec(
        name: 'closed',
        type: ParamType.boolean,
        description: 'Whether to close the polyline back to its first vertex',
        required: false,
        defaultValue: false,
      ),
    ],
    handler: (context) async {
      final layer = context.document.currentLayer;
      final supplied = _pointList(context.args['points']);
      if (supplied.length >= 2) {
        return _commit(context, 'Polyline', [
          PolylineEntity.fromPoints(
            id: 0,
            props: EntityProps(layer: layer),
            points: supplied,
            closed: context.args.boolean('closed') ?? false,
          ),
        ]);
      }

      final points = <Vec2>[];
      while (true) {
        context.input
          ..setMarkers(List.of(points))
          ..setPreview(
            points.isEmpty
                ? null
                : (cursor) => [
                    OverlayPolyline(List.of(points)),
                    OverlayLine(points.last, cursor),
                    if (points.length >= 2)
                      OverlayLine(points.first, cursor, dashed: true),
                  ],
          );
        final next = await context.input.pointOrNull(
          points.isEmpty
              ? 'PLINE  Specify start point:'
              : 'PLINE  Specify next point (Escape to finish):',
        );
        if (next == null) break;
        points.add(next);
      }
      context.input
        ..setPreview(null)
        ..setMarkers(const []);

      if (points.length < 2) return const CommandResult.cancelled();
      return _commit(context, 'Polyline', [
        PolylineEntity.fromPoints(
          id: 0,
          props: EntityProps(layer: layer),
          points: points,
        ),
      ]);
    },
  );

  static CommandDescriptor _spline() => CommandDescriptor(
    id: 'draw.spline',
    title: 'Spline',
    category: _category,
    aliases: const ['spl', 'spline'],
    description:
        'Draws a clamped B-spline. Control-point mode pulls the curve toward '
        'the clicks and only guarantees the ends. Fit mode interpolates every '
        'point. Pass a points array to create it non-interactively.',
    params: const [
      ParamSpec(
        name: 'method',
        type: ParamType.text,
        description: 'Control or Fit',
        required: false,
      ),
      ParamSpec(
        name: 'points',
        type: ParamType.json,
        description: 'Array of [x, y] points',
        required: false,
      ),
    ],
    handler: (context) async {
      final layer = context.document.currentLayer;
      final supplied = _pointList(context.args['points']);
      final useFit = _splineUsesFit(context.args.text('method'));
      if (supplied.length >= 2) {
        final spline = useFit
            ? Construct.splineFromFit(
                supplied,
                props: EntityProps(layer: layer),
              )
            : Construct.splineFromControls(
                supplied,
                props: EntityProps(layer: layer),
              );
        if (spline == null) {
          return CommandResult.failed(
            useFit
                ? 'Need at least two fit points that can be interpolated.'
                : 'Need at least two control points.',
          );
        }
        return _commit(context, 'Spline', [spline]);
      }

      final method = context.args.text('method') ??
          await context.input.keyword(
            'SPLINE  Enter method [Control/Fit]:',
            const ['Control', 'Fit'],
            defaultOption: 'Control',
          );
      final fit = _splineUsesFit(method);
      final kind = fit ? 'fit' : 'control';
      final points = <Vec2>[];
      while (true) {
        context.input
          ..setMarkers(List.of(points))
          ..setPreview(
            points.isEmpty
                ? null
                : (cursor) => _splineOverlay([...points, cursor], fit: fit),
          );
        final next = await context.input.pointOrNull(
          points.isEmpty
              ? 'SPLINE  Specify first $kind point:'
              : 'SPLINE  Specify next $kind point (Escape to finish):',
        );
        if (next == null) break;
        points.add(next);
      }
      context.input
        ..setPreview(null)
        ..setMarkers(const []);

      if (points.length < 2) return const CommandResult.cancelled();
      final spline = fit
          ? Construct.splineFromFit(
              points,
              props: EntityProps(layer: layer),
            )
          : Construct.splineFromControls(
              points,
              props: EntityProps(layer: layer),
            );
      if (spline == null) {
        return CommandResult.failed(
          fit
              ? 'Need at least two fit points that can be interpolated.'
              : 'Need at least two control points.',
        );
      }
      return _commit(context, 'Spline', [spline]);
    },
  );

  static bool _splineUsesFit(String? method) =>
      (method ?? '').trim().toLowerCase() == 'fit';

  static List<OverlayShape> _splineOverlay(
    List<Vec2> points, {
    bool fit = false,
  }) {
    final spline = fit
        ? Construct.splineFromFit(points)
        : Construct.splineFromControls(points);
    if (spline == null) return [OverlayPolyline(List.of(points))];
    final sampled = Flatten.bspline(
      controlPoints: spline.controlPoints,
      knots: spline.knots,
      degree: spline.degree,
      tolerance: 0.2,
    );
    return [
      OverlayPolyline(List.of(points), dashed: true),
      OverlayPolyline([
        for (var i = 0; i + 1 < sampled.length; i += 2)
          Vec2(sampled[i], sampled[i + 1]),
      ]),
    ];
  }

  static CommandDescriptor _rectangle() => CommandDescriptor(
    id: 'draw.rectangle',
    title: 'Rectangle',
    category: _category,
    aliases: const ['rec', 'rectang', 'rectangle'],
    icon: 'rectangle',
    description: 'Draws an axis-aligned rectangle as a closed polyline.',
    params: const [
      ParamSpec.point('corner1', description: 'First corner'),
      ParamSpec.point('corner2', description: 'Opposite corner'),
    ],
    handler: (context) async {
      final first = await context.resolvePoint(
        'corner1',
        'RECTANG  Specify first corner:',
      );
      context.input.setPreview((cursor) => [OverlayRect(first, cursor)]);
      final second = await context.resolvePoint(
        'corner2',
        'RECTANG  Specify opposite corner:',
        basePoint: first,
      );
      context.input.setPreview(null);

      final rectangle = Construct.rectangle(
        first,
        second,
        props: EntityProps(layer: context.document.currentLayer),
      );
      if (rectangle == null) {
        return const CommandResult.failed('The rectangle has no area.');
      }
      return _commit(context, 'Rectangle', [rectangle]);
    },
  );

  static CommandDescriptor _circle() => CommandDescriptor(
    id: 'draw.circle',
    title: 'Circle',
    category: _category,
    aliases: const ['c', 'circle'],
    icon: 'circle',
    description: 'Draws a circle from a centre point and a radius.',
    params: const [
      ParamSpec.point('center', description: 'Centre of the circle'),
      ParamSpec(
        name: 'radius',
        type: ParamType.distance,
        description: 'Radius in drawing units',
      ),
    ],
    handler: (context) async {
      final center = await context.resolvePoint(
        'center',
        'CIRCLE  Specify center point:',
      );
      context.input
        ..setMarkers([center])
        ..setPreview(
          (cursor) => [
            OverlayArc(center: center, radius: center.distanceTo(cursor)),
            OverlayLine(center, cursor),
          ],
        );
      final radius = context.args.number('radius') ??
          await context.input.distance(
            'CIRCLE  Specify radius:',
            basePoint: center,
          );
      context.input
        ..setPreview(null)
        ..setMarkers(const []);

      if (radius <= 0) {
        return const CommandResult.failed('The radius must be positive.');
      }
      return _commit(context, 'Circle', [
        CircleEntity(
          id: 0,
          props: EntityProps(layer: context.document.currentLayer),
          center: center,
          radius: radius,
        ),
      ]);
    },
  );

  static CommandDescriptor _circleDiameter() => CommandDescriptor(
    id: 'draw.circle2p',
    title: 'Circle (2 Points)',
    category: _category,
    description: 'Draws a circle whose diameter is the segment between two '
        'points.',
    params: const [
      ParamSpec.point('first', description: 'One end of the diameter'),
      ParamSpec.point('second', description: 'The other end of the diameter'),
    ],
    handler: (context) async {
      final first = await context.resolvePoint(
        'first',
        'CIRCLE  Specify first end of diameter:',
      );
      context.input
        ..setMarkers([first])
        ..setPreview(
          (cursor) => [
            OverlayArc(
              center: first.lerp(cursor, 0.5),
              radius: first.distanceTo(cursor) / 2,
            ),
            OverlayLine(first, cursor),
          ],
        );
      final second = await context.resolvePoint(
        'second',
        'CIRCLE  Specify second end of diameter:',
        basePoint: first,
      );
      context.input
        ..setPreview(null)
        ..setMarkers(const []);

      final radius = first.distanceTo(second) / 2;
      if (radius <= 0) {
        return const CommandResult.failed('The two points coincide.');
      }
      return _commit(context, 'Circle', [
        CircleEntity(
          id: 0,
          props: EntityProps(layer: context.document.currentLayer),
          center: first.lerp(second, 0.5),
          radius: radius,
        ),
      ]);
    },
  );

  static CommandDescriptor _circle3p() => CommandDescriptor(
    id: 'draw.circle3p',
    title: 'Circle (3 Points)',
    category: _category,
    aliases: const ['c3p'],
    description:
        'Draws the unique circle that passes through three specified points.',
    params: const [
      ParamSpec.point('first', description: 'First point on the circle'),
      ParamSpec.point('second', description: 'Second point on the circle'),
      ParamSpec.point('third', description: 'Third point on the circle'),
    ],
    handler: (context) async {
      final first = await context.resolvePoint(
        'first',
        'CIRCLE  Specify first point on circle:',
      );
      context.input
        ..setMarkers([first])
        ..setPreview((cursor) => [OverlayLine(first, cursor)]);
      final second = await context.resolvePoint(
        'second',
        'CIRCLE  Specify second point on circle:',
        basePoint: first,
      );

      context.input
        ..setMarkers([first, second])
        ..setPreview((cursor) {
          final circle = Construct.circleThrough(first, second, cursor);
          if (circle == null) return [OverlayLine(first, second)];
          return [
            OverlayArc(center: circle.center, radius: circle.radius),
            OverlayLine(first, second, dashed: true),
          ];
        });
      final third = await context.resolvePoint(
        'third',
        'CIRCLE  Specify third point on circle:',
        basePoint: second,
      );
      context.input
        ..setPreview(null)
        ..setMarkers(const []);

      final circle = Construct.circleThrough(
        first,
        second,
        third,
        props: EntityProps(layer: context.document.currentLayer),
      );
      if (circle == null) {
        return const CommandResult.failed(
          'The three points are collinear, so they do not define a circle.',
        );
      }
      return _commit(context, 'Circle', [circle]);
    },
  );

  static CommandDescriptor _circleTtr() => CommandDescriptor(
    id: 'draw.circleTtr',
    title: 'Circle (Tan Tan Radius)',
    category: _category,
    aliases: const ['ttr', 'circlettr'],
    description:
        'Draws a circle of a given radius tangent to two lines, circles '
        'or arcs. The pick on each object chooses the side (and, for a '
        'circle, external versus internal tangent).',
    params: const [
      ParamSpec(
        name: 'first',
        type: ParamType.entity,
        description: 'First tangent object',
      ),
      ParamSpec(
        name: 'second',
        type: ParamType.entity,
        description: 'Second tangent object',
      ),
      ParamSpec(
        name: 'radius',
        type: ParamType.distance,
        description: 'Radius of the new circle',
        min: 1e-9,
      ),
      ParamSpec(
        name: 'pick1',
        type: ParamType.point,
        required: false,
        description: 'Point that marks the side of the first object',
      ),
      ParamSpec(
        name: 'pick2',
        type: ParamType.point,
        required: false,
        description: 'Point that marks the side of the second object',
      ),
    ],
    handler: (context) async {
      final firstId = context.args.integer('first');
      final secondId = context.args.integer('second');
      final int id1;
      final int id2;
      if (firstId != null && secondId != null) {
        id1 = firstId;
        id2 = secondId;
      } else {
        context.selection.clear();
        final firstPick = await context.input.selection(
          'CIRCLE  Select first tangent object:',
          useExistingSelection: false,
          single: true,
        );
        if (firstPick.isEmpty) return const CommandResult.cancelled();
        id1 = firstPick.first;
        final secondPick = await context.input.selection(
          'CIRCLE  Select second tangent object:',
          useExistingSelection: false,
          single: true,
        );
        if (secondPick.isEmpty) return const CommandResult.cancelled();
        id2 = secondPick.first;
      }

      final first = context.document.entity(id1);
      final second = context.document.entity(id2);
      if (first == null || second == null) {
        return const CommandResult.failed('A tangent object no longer exists.');
      }

      final pick1 = context.args.point('pick1') ?? _tangentPick(first);
      final pick2 = context.args.point('pick2') ?? _tangentPick(second);

      final radius = context.args.number('radius') ??
          await context.input.distance('CIRCLE  Specify radius:');
      if (radius <= 0) {
        return const CommandResult.failed('The radius must be positive.');
      }

      final circle = Construct.circleTangentRadius(
        first,
        second,
        radius,
        pick1,
        pick2,
        props: EntityProps(layer: context.document.currentLayer),
      );
      if (circle == null) {
        return const CommandResult.failed(
          'No circle of that radius is tangent to both objects on the '
          'picked sides.',
        );
      }
      return _commit(context, 'Circle', [circle]);
    },
  );

  static Vec2 _tangentPick(CadEntity entity) => switch (entity) {
    LineEntity(:final midpoint) => midpoint,
    CircleEntity(:final center) => center,
    ArcEntity(:final midPoint) => midPoint,
    _ => entity.computeBounds().center,
  };

  static CommandDescriptor _donut() => CommandDescriptor(
    id: 'draw.donut',
    title: 'Donut',
    category: _category,
    aliases: const ['do', 'donut'],
    description:
        'Draws a filled ring from an inside and outside diameter. A zero '
        'inside diameter is a filled disk. The result is a closed wide '
        'polyline, which is how DWG stores a donut.',
    params: const [
      ParamSpec(
        name: 'inside',
        type: ParamType.distance,
        description: 'Inside diameter; 0 for a filled disk',
        min: 0,
      ),
      ParamSpec(
        name: 'outside',
        type: ParamType.distance,
        description: 'Outside diameter',
        min: 0,
      ),
      ParamSpec.point('center', description: 'Centre of the donut'),
    ],
    handler: (context) async {
      final inside = context.args.number('inside') ??
          await context.input.number(
            'DONUT  Specify inside diameter:',
            defaultValue: 0,
          );
      final outside = context.args.number('outside') ??
          await context.input.number('DONUT  Specify outside diameter:');
      if (inside < 0 || outside < 0) {
        return const CommandResult.failed('Diameters cannot be negative.');
      }
      final innerR = math.min(inside, outside) / 2;
      final outerR = math.max(inside, outside) / 2;
      if (outerR <= 0) {
        return const CommandResult.failed(
          'The outside diameter must be positive.',
        );
      }

      final props = EntityProps(layer: context.document.currentLayer);
      final created = <CadEntity>[];

      Future<void> place(Vec2 center) async {
        final donut = Construct.donut(
          center: center,
          innerRadius: innerR,
          outerRadius: outerR,
          props: props,
        );
        if (donut != null) created.add(donut);
      }

      final supplied = context.args.point('center');
      if (supplied != null) {
        await place(supplied);
      } else {
        while (true) {
          context.input.setPreview((cursor) {
            return [
              OverlayArc(center: cursor, radius: outerR),
              if (innerR > 0) OverlayArc(center: cursor, radius: innerR),
            ];
          });
          final next = await context.input.pointOrNull(
            'DONUT  Specify center of donut:',
          );
          if (next == null) break;
          await place(next);
          if (!context.input.isInteractive) break;
        }
        context.input.setPreview(null);
      }

      if (created.isEmpty) return const CommandResult.cancelled();
      return _commit(context, 'Donut', created);
    },
  );

  static CommandDescriptor _arc() => CommandDescriptor(
    id: 'draw.arc',
    title: 'Arc',
    category: _category,
    aliases: const ['a', 'arc'],
    icon: 'arc',
    description:
        'Draws a circular arc through three points: start, a point on the arc, '
        'and end.',
    params: const [
      ParamSpec.point('start', description: 'Start of the arc'),
      ParamSpec.point('via', description: 'A point the arc passes through'),
      ParamSpec.point('end', description: 'End of the arc'),
    ],
    handler: (context) async {
      final props = EntityProps(layer: context.document.currentLayer);
      final start = await context.resolvePoint(
        'start',
        'ARC  Specify start point:',
      );
      context.input
        ..setMarkers([start])
        ..setPreview((cursor) => [OverlayLine(start, cursor)]);
      final via = await context.resolvePoint(
        'via',
        'ARC  Specify a second point on the arc:',
        basePoint: start,
      );

      context.input
        ..setMarkers([start, via])
        ..setPreview((cursor) {
          final arc = Construct.arcThrough(start, via, cursor);
          if (arc == null) return [OverlayLine(start, cursor)];
          return [
            OverlayArc(
              center: arc.center,
              radius: arc.radius,
              startAngle: arc.startAngle,
              sweep: arc.sweep,
            ),
          ];
        });
      final end = await context.resolvePoint(
        'end',
        'ARC  Specify end point:',
        basePoint: via,
      );
      context.input
        ..setPreview(null)
        ..setMarkers(const []);

      final arc = Construct.arcThrough(start, via, end, props: props);
      if (arc == null) {
        // Three collinear points describe a straight line. Producing the line
        // is more useful than refusing, and it is what the user drew.
        return _commit(context, 'Line', [
          LineEntity(id: 0, props: props, start: start, end: end),
        ], message: 'The three points were collinear, so a line was drawn.');
      }
      return _commit(context, 'Arc', [arc]);
    },
  );

  static CommandDescriptor _polygon() => CommandDescriptor(
    id: 'draw.polygon',
    title: 'Polygon',
    category: _category,
    aliases: const ['pol', 'polygon'],
    description: 'Draws a regular polygon inscribed in a circle.',
    params: const [
      ParamSpec(
        name: 'sides',
        type: ParamType.integer,
        description: 'Number of sides, at least 3',
        min: 3,
        max: 1024,
      ),
      ParamSpec.point('center', description: 'Centre of the polygon'),
      ParamSpec(
        name: 'radius',
        type: ParamType.distance,
        description: 'Distance from the centre to each vertex',
      ),
    ],
    handler: (context) async {
      final sides = context.args.integer('sides') ??
          await context.input.integer(
            'POLYGON  Enter number of sides:',
            defaultValue: 6,
          );
      if (sides < 3) {
        return const CommandResult.failed('A polygon needs at least 3 sides.');
      }
      final center = await context.resolvePoint(
        'center',
        'POLYGON  Specify center:',
      );
      context.input
        ..setMarkers([center])
        ..setPreview((cursor) {
          final radius = center.distanceTo(cursor);
          final polygon = Construct.polygon(
            center: center,
            radius: radius,
            sides: sides,
            startAngle: (cursor - center).angle,
          );
          return [
            OverlayPolyline(
              [
                for (var i = 0; i < polygon.vertexCount; i++)
                  polygon.vertexAt(i),
              ],
              closed: true,
            ),
            OverlayArc(center: center, radius: radius),
          ];
        });
      final radius = context.args.number('radius') ??
          await context.input.distance(
            'POLYGON  Specify radius:',
            basePoint: center,
          );
      context.input
        ..setPreview(null)
        ..setMarkers(const []);

      if (radius <= 0) {
        return const CommandResult.failed('The radius must be positive.');
      }
      return _commit(context, 'Polygon', [
        Construct.polygon(
          center: center,
          radius: radius,
          sides: sides,
          props: EntityProps(layer: context.document.currentLayer),
        ),
      ]);
    },
  );

  static CommandDescriptor _ellipse() => CommandDescriptor(
    id: 'draw.ellipse',
    title: 'Ellipse',
    category: _category,
    aliases: const ['el', 'ellipse'],
    description:
        'Draws an ellipse from a centre, one axis endpoint, and the distance '
        'to the other axis.',
    params: const [
      ParamSpec.point('center', description: 'Centre of the ellipse'),
      ParamSpec.point('axisEnd', description: 'End of the first axis'),
      ParamSpec(
        name: 'otherRadius',
        type: ParamType.distance,
        description: 'Distance from the centre to the other axis',
      ),
    ],
    handler: (context) async {
      final center = await context.resolvePoint(
        'center',
        'ELLIPSE  Specify center:',
      );
      context.input
        ..setMarkers([center])
        ..setPreview((cursor) => [OverlayLine(center, cursor)]);
      final axisEnd = await context.resolvePoint(
        'axisEnd',
        'ELLIPSE  Specify endpoint of axis:',
        basePoint: center,
      );

      context.input
        ..setMarkers([center, axisEnd])
        ..setPreview((cursor) {
          final ellipse = Construct.ellipse(
            center: center,
            axisEnd: axisEnd,
            otherRadius: center.distanceTo(cursor),
          );
          if (ellipse == null) return [OverlayLine(center, axisEnd)];
          return _ellipseOverlay(ellipse);
        });
      final otherRadius = context.args.number('otherRadius') ??
          await context.input.distance(
            'ELLIPSE  Specify distance to other axis:',
            basePoint: center,
          );
      context.input
        ..setPreview(null)
        ..setMarkers(const []);

      final ellipse = Construct.ellipse(
        center: center,
        axisEnd: axisEnd,
        otherRadius: otherRadius,
        props: EntityProps(layer: context.document.currentLayer),
      );
      if (ellipse == null) {
        return const CommandResult.failed(
          'The ellipse needs a positive axis length.',
        );
      }
      return _commit(context, 'Ellipse', [ellipse]);
    },
  );

  static List<OverlayShape> _ellipseOverlay(EllipseEntity ellipse) {
    final majorLength = ellipse.majorAxis.length;
    final points = Flatten.ellipse(
      center: ellipse.center,
      major: ellipse.majorAxis,
      ratio: ellipse.ratio,
      startParam: 0,
      endParam: math.pi * 2,
      tolerance: math.max(majorLength * 0.02, 0.05),
    );
    return [
      OverlayPolyline(
        [
          for (var i = 0; i + 1 < points.length; i += 2)
            Vec2(points[i], points[i + 1]),
        ],
        closed: true,
      ),
      OverlayLine(
        ellipse.center,
        ellipse.center + ellipse.majorAxis,
        dashed: true,
      ),
    ];
  }

  static CommandDescriptor _xline() => CommandDescriptor(
    id: 'draw.xline',
    title: 'Construction Line',
    category: _category,
    aliases: const ['xl', 'xline'],
    description:
        'Draws an infinite construction line through a point in a given '
        'direction. The second point only sets the angle; both sides extend '
        'without end.',
    params: const [
      ParamSpec.point('origin', description: 'A point on the line'),
      ParamSpec.point('through', description: 'A second point that sets the direction'),
    ],
    handler: (context) async {
      final origin = await context.resolvePoint(
        'origin',
        'XLINE  Specify a point:',
      );
      context.input
        ..setMarkers([origin])
        ..setPreview(
          (cursor) => [
            OverlayTrackingLine(origin, (cursor - origin).angle),
          ],
        );
      final through = await context.resolvePoint(
        'through',
        'XLINE  Specify through point:',
        basePoint: origin,
      );
      context.input
        ..setPreview(null)
        ..setMarkers(const []);

      final direction = through - origin;
      if (direction.lengthSquared < 1e-20) {
        return const CommandResult.failed(
          'The two points coincide, so the line has no direction.',
        );
      }
      return _commit(context, 'Xline', [
        XLineEntity(
          id: 0,
          props: EntityProps(layer: context.document.currentLayer),
          origin: origin,
          direction: direction,
        ),
      ]);
    },
  );

  static CommandDescriptor _ray() => CommandDescriptor(
    id: 'draw.ray',
    title: 'Ray',
    category: _category,
    aliases: const ['ray'],
    description:
        'Draws a semi-infinite ray from a start point through a second point. '
        'Unlike XLINE, it has a beginning.',
    params: const [
      ParamSpec.point('origin', description: 'Start of the ray'),
      ParamSpec.point('through', description: 'A point the ray passes through'),
    ],
    handler: (context) async {
      final origin = await context.resolvePoint(
        'origin',
        'RAY  Specify start point:',
      );
      context.input
        ..setMarkers([origin])
        ..setPreview((cursor) => [OverlayLine(origin, cursor, dashed: false)]);
      final through = await context.resolvePoint(
        'through',
        'RAY  Specify through point:',
        basePoint: origin,
      );
      context.input
        ..setPreview(null)
        ..setMarkers(const []);

      final direction = through - origin;
      if (direction.lengthSquared < 1e-20) {
        return const CommandResult.failed(
          'The two points coincide, so the ray has no direction.',
        );
      }
      return _commit(context, 'Ray', [
        RayEntity(
          id: 0,
          props: EntityProps(layer: context.document.currentLayer),
          origin: origin,
          direction: direction,
        ),
      ]);
    },
  );

  static CommandDescriptor _point() => CommandDescriptor(
    id: 'draw.point',
    title: 'Point',
    category: _category,
    aliases: const ['po', 'point'],
    description: 'Places a point marker.',
    params: const [ParamSpec.point('at', description: 'Where to place it')],
    handler: (context) async {
      final at = await context.resolvePoint('at', 'POINT  Specify a location:');
      return _commit(context, 'Point', [
        PointEntity(
          id: 0,
          props: EntityProps(layer: context.document.currentLayer),
          position: at,
        ),
      ]);
    },
  );

  static CommandDescriptor _divide() => CommandDescriptor(
    id: 'draw.divide',
    title: 'Divide',
    category: _category,
    aliases: const ['div', 'divide'],
    description:
        'Places point markers that split a line, polyline, arc or circle '
        'into equal segments. Open objects leave the endpoints unmarked; '
        'a circle or closed polyline places a marker at every interval. '
        'A bulge is followed as its arc, not the chord.',
    params: const [
      ParamSpec(
        name: 'target',
        type: ParamType.entity,
        description: 'The object to divide',
        required: false,
      ),
      ParamSpec(
        name: 'segments',
        type: ParamType.integer,
        description: 'Number of equal segments, at least 2',
        min: 2,
      ),
    ],
    handler: (context) async {
      final supplied = context.args.integer('target');
      final int targetId;
      if (supplied != null) {
        targetId = supplied;
      } else {
        context.selection.clear();
        final picked = await context.input.selection(
          'DIVIDE  Select object to divide:',
          useExistingSelection: false,
          single: true,
        );
        if (picked.isEmpty) return const CommandResult.cancelled();
        targetId = picked.first;
      }

      final target = context.document.entity(targetId);
      if (target is! LineEntity &&
          target is! PolylineEntity &&
          target is! ArcEntity &&
          target is! CircleEntity) {
        return const CommandResult.failed(
          'Divide supports lines, polylines, arcs and circles.',
        );
      }

      final segments = context.args.integer('segments') ??
          await context.input.integer(
            'DIVIDE  Enter the number of segments:',
            defaultValue: 2,
          );
      if (segments < 2) {
        return const CommandResult.failed(
          'A division needs at least two segments.',
        );
      }

      final points = switch (target) {
        LineEntity() => Construct.divideLine(target, segments),
        PolylineEntity() => Construct.dividePolyline(target, segments),
        ArcEntity() => Construct.divideArc(target, segments),
        CircleEntity() => Construct.divideCircle(target, segments),
        _ => const <Vec2>[],
      };
      if (points.isEmpty) {
        return const CommandResult.failed('Nothing to place.');
      }
      final layer = context.document.currentLayer;
      return _commit(context, 'Divide', [
        for (final at in points)
          PointEntity(
            id: 0,
            props: EntityProps(layer: layer),
            position: at,
          ),
      ]);
    },
  );

  static CommandDescriptor _measure() => CommandDescriptor(
    id: 'draw.measure',
    title: 'Measure',
    category: _category,
    aliases: const ['me', 'measure'],
    description:
        'Places point markers at a fixed spacing along a line, polyline, '
        'arc or circle. Open objects start from the nearer end; a circle '
        'starts at the pick. Endpoints are not marked. A bulge is followed '
        'as its arc, not the chord.',
    params: const [
      ParamSpec(
        name: 'target',
        type: ParamType.entity,
        description: 'The object to measure',
        required: false,
      ),
      ParamSpec(
        name: 'spacing',
        type: ParamType.distance,
        description: 'Distance between markers',
        min: 1e-9,
      ),
      ParamSpec(
        name: 'pick',
        type: ParamType.point,
        description: 'A point nearer the end to start from',
        required: false,
      ),
    ],
    handler: (context) async {
      final supplied = context.args.integer('target');
      final int targetId;
      if (supplied != null) {
        targetId = supplied;
      } else {
        context.selection.clear();
        final picked = await context.input.selection(
          'MEASURE  Select object to measure:',
          useExistingSelection: false,
          single: true,
        );
        if (picked.isEmpty) return const CommandResult.cancelled();
        targetId = picked.first;
      }

      final target = context.document.entity(targetId);
      if (target is! LineEntity &&
          target is! PolylineEntity &&
          target is! ArcEntity &&
          target is! CircleEntity) {
        return const CommandResult.failed(
          'Measure supports lines, polylines, arcs and circles.',
        );
      }

      final pick = context.args.point('pick') ??
          switch (target) {
            LineEntity(:final start) => start,
            PolylineEntity() => target.vertexAt(0),
            ArcEntity(:final startPoint) => startPoint,
            CircleEntity(:final center) => center,
            _ => const Vec2(0, 0),
          };
      final spacing = context.args.number('spacing') ??
          await context.input.number('MEASURE  Specify segment length:');
      if (spacing <= 0) {
        return const CommandResult.failed('The spacing must be positive.');
      }

      final points = switch (target) {
        LineEntity() => Construct.measureLine(target, spacing, pick),
        PolylineEntity() => Construct.measurePolyline(target, spacing, pick),
        ArcEntity() => Construct.measureArc(target, spacing, pick),
        CircleEntity() => Construct.measureCircle(target, spacing, pick),
        _ => const <Vec2>[],
      };
      if (points.isEmpty) {
        return const CommandResult.failed(
          'The object is shorter than the spacing, so nothing was placed.',
        );
      }
      final layer = context.document.currentLayer;
      return _commit(context, 'Measure', [
        for (final at in points)
          PointEntity(
            id: 0,
            props: EntityProps(layer: layer),
            position: at,
          ),
      ]);
    },
  );

  static CommandDescriptor _text() => CommandDescriptor(
    id: 'draw.text',
    title: 'Text',
    category: _category,
    aliases: const ['t', 'text', 'dtext'],
    icon: 'text',
    description: 'Places a single line of text.',
    params: const [
      ParamSpec(
        name: 'content',
        type: ParamType.text,
        description: 'The text to place',
      ),
      ParamSpec.point('at', description: 'Insertion point'),
      ParamSpec(
        name: 'height',
        type: ParamType.distance,
        description: 'Cap height in drawing units',
        required: false,
        defaultValue: 2.5,
      ),
      ParamSpec(
        name: 'rotation',
        type: ParamType.angle,
        description: 'Rotation in degrees',
        required: false,
        defaultValue: 0,
      ),
    ],
    handler: (context) async {
      final content = await context.resolveText(
        'content',
        'TEXT  Enter the text:',
      );
      if (content.isEmpty) {
        return const CommandResult.cancelled('No text was entered.');
      }
      final height = context.args.number('height') ??
          await context.input.number(
            'TEXT  Specify height:',
            defaultValue: 2.5,
          );
      final rotationDegrees = context.args.number('rotation') ?? 0;
      final rotation = rotationDegrees * math.pi / 180;

      context.input.setPreview((cursor) {
        final box = TextGeometry(
          text: content,
          origin: cursor,
          height: height,
          rotation: rotation,
          styleName: 'Standard',
        ).estimatedBounds();
        return box.isEmpty ? const [] : [OverlayRect(box.min, box.max)];
      });
      final at = await context.resolvePoint(
        'at',
        'TEXT  Specify insertion point:',
      );
      context.input.setPreview(null);

      return _commit(context, 'Text', [
        TextEntity(
          id: 0,
          props: EntityProps(layer: context.document.currentLayer),
          position: at,
          content: content,
          height: height,
          rotation: rotation,
        ),
      ]);
    },
  );

  static CommandDescriptor _mtext() => CommandDescriptor(
    id: 'draw.mtext',
    title: 'MText',
    category: _category,
    aliases: const ['mt', 'mtext'],
    icon: 'text',
    description:
        'Places multiline text. Newlines become \\P. Width 0 does not wrap. '
        'Justify is TL…BR or attachment 1–9 (1 is top-left).',
    params: const [
      ParamSpec(
        name: 'content',
        type: ParamType.text,
        description: 'The text to place. Use \\P or a newline for a break.',
      ),
      ParamSpec.point('at', description: 'Attachment point'),
      ParamSpec(
        name: 'height',
        type: ParamType.distance,
        description: 'Cap height in drawing units',
        required: false,
        defaultValue: 2.5,
      ),
      ParamSpec(
        name: 'width',
        type: ParamType.distance,
        description: 'Wrapping width. 0 means no wrap.',
        required: false,
        defaultValue: 0,
      ),
      ParamSpec(
        name: 'rotation',
        type: ParamType.angle,
        description: 'Rotation in degrees',
        required: false,
        defaultValue: 0,
      ),
      ParamSpec(
        name: 'justify',
        type: ParamType.text,
        description: 'TL, TC, TR, ML, MC, MR, BL, BC, BR',
        required: false,
      ),
      ParamSpec(
        name: 'attachment',
        type: ParamType.integer,
        description: 'Attachment point 1–9',
        required: false,
      ),
    ],
    handler: (context) async {
      final raw = await context.resolveText(
        'content',
        'MTEXT  Enter the text:',
      );
      if (raw.isEmpty) {
        return const CommandResult.cancelled('No text was entered.');
      }
      final content = raw
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .replaceAll('\n', r'\P');
      final height = context.args.number('height') ??
          await context.input.number(
            'MTEXT  Specify height:',
            defaultValue: 2.5,
          );
      if (height <= 0) {
        return const CommandResult.failed('Text height must be positive.');
      }
      final width = context.args.number('width') ?? 0;
      if (width < 0) {
        return const CommandResult.failed('Text width cannot be negative.');
      }
      final rotationDegrees = context.args.number('rotation') ?? 0;
      final rotation = rotationDegrees * math.pi / 180;
      final attachment = _mtextAttachment(context);
      if (attachment == null) {
        return const CommandResult.failed(
          'Justify must be TL…BR or attachment 1–9.',
        );
      }

      context.input.setPreview((cursor) {
        final box = TextGeometry(
          text: stripMTextFormatting(content),
          origin: cursor,
          height: height,
          rotation: rotation,
          styleName: 'Standard',
          rectangleWidth: width,
          isMultiline: true,
        ).estimatedBounds();
        return box.isEmpty ? const [] : [OverlayRect(box.min, box.max)];
      });
      final at = await context.resolvePoint(
        'at',
        'MTEXT  Specify attachment point:',
      );
      context.input.setPreview(null);

      return _commit(context, 'MText', [
        MTextEntity(
          id: 0,
          props: EntityProps(layer: context.document.currentLayer),
          position: at,
          content: content,
          height: height,
          rotation: rotation,
          rectangleWidth: width,
          attachment: attachment,
        ),
      ]);
    },
  );

  static int? _mtextAttachment(CommandContext context) {
    final code = context.args.integer('attachment');
    if (code != null) {
      if (code < 1 || code > 9) return null;
      return code;
    }
    final justify = context.args.text('justify')?.trim() ?? '';
    if (justify.isEmpty) return 1;
    final next = Construct.parseTextJustify(
      justify,
      currentH: TextHAlign.left,
      currentV: TextVAlign.top,
    );
    if (next == null) return null;
    final h = switch (next.h) {
      TextHAlign.right => 2,
      TextHAlign.center || TextHAlign.middle || TextHAlign.fit => 1,
      _ => 0,
    };
    final v = switch (next.v) {
      TextVAlign.top => 0,
      TextVAlign.middle => 1,
      _ => 2,
    };
    return 1 + v * 3 + h;
  }

  static CommandDescriptor _leader() => CommandDescriptor(
    id: 'draw.leader',
    title: 'Leader',
    category: _category,
    aliases: const ['le', 'leader', 'qleader'],
    icon: 'leader',
    description:
        'Draws a leader from an arrow tip through one or more vertices. '
        'Optional annotation text sits on a horizontal landing at the last '
        'point, the same way AutoCAD LEADER places a callout.',
    params: const [
      ParamSpec(
        name: 'points',
        type: ParamType.json,
        description: 'Array of [x, y] vertices, first is the arrow tip',
        required: false,
      ),
      ParamSpec(
        name: 'text',
        type: ParamType.text,
        description:
            'Annotation placed at the landing; empty is the leader only',
        required: false,
      ),
      ParamSpec(
        name: 'height',
        type: ParamType.distance,
        description: 'Annotation height in drawing units',
        required: false,
        defaultValue: 2.5,
      ),
      ParamSpec(
        name: 'arrow',
        type: ParamType.boolean,
        description: 'Whether the first vertex draws an arrowhead',
        required: false,
        defaultValue: true,
      ),
    ],
    handler: (context) async {
      final layer = context.document.currentLayer;
      var points = _pointList(context.args['points']);
      if (points.length < 2) {
        points = [];
        while (true) {
          context.input
            ..setMarkers(List.of(points))
            ..setPreview(
              points.isEmpty
                  ? null
                  : (cursor) => [
                      OverlayPolyline(List.of(points)),
                      OverlayLine(points.last, cursor),
                    ],
            );
          final next = await context.input.pointOrNull(
            points.isEmpty
                ? 'LEADER  Specify first leader point:'
                : 'LEADER  Specify next point (Escape to finish):',
          );
          if (next == null) break;
          if (points.isEmpty || next.distanceTo(points.last) > 1e-12) {
            points.add(next);
          }
          if (!context.input.isInteractive && points.length >= 2) break;
        }
        context.input
          ..setPreview(null)
          ..setMarkers(const []);
      }

      if (points.length < 2) {
        return const CommandResult.failed(
          'A leader needs at least two points.',
        );
      }

      final annotation = context.args.text('text') ??
          (context.input.isInteractive
              ? await context.input.text(
                  'LEADER  Enter annotation text <none>:',
                  defaultValue: '',
                )
              : '');
      final height = context.args.number('height') ?? 2.5;
      final created = Construct.leader(
        points,
        props: EntityProps(layer: layer),
        annotation: annotation,
        textHeight: height,
        hasArrowHead: context.args.boolean('arrow') ?? true,
      );
      if (created == null) {
        return const CommandResult.failed(
          'A leader needs at least two distinct points.',
        );
      }
      return _commit(context, 'Leader', created);
    },
  );

  static CommandDescriptor _hatch() => CommandDescriptor(
    id: 'draw.hatch',
    title: 'Hatch',
    category: _category,
    aliases: const ['h', 'hatch'],
    description:
        'Fills the area enclosed by selected closed polylines or circles.',
    params: const [
      ParamSpec.selection('ids', description: 'Closed boundaries to fill'),
      ParamSpec(
        name: 'pattern',
        type: ParamType.text,
        description: 'Pattern name, or SOLID for a solid fill',
        required: false,
        defaultValue: 'SOLID',
      ),
      ParamSpec(
        name: 'scale',
        type: ParamType.distance,
        description: 'Pattern scale',
        required: false,
        defaultValue: 1,
      ),
      ParamSpec(
        name: 'angle',
        type: ParamType.angle,
        description: 'Pattern rotation in degrees',
        required: false,
        defaultValue: 0,
      ),
    ],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'HATCH  Select closed boundaries:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();

      final pattern = context.args.text('pattern') ?? 'SOLID';
      final scale = context.args.number('scale') ?? 1;
      if (scale <= 0) {
        return const CommandResult.failed('Hatch scale must be positive.');
      }
      final angle = (context.args.number('angle') ?? 0) * math.pi / 180;
      final loops = <HatchLoop>[];
      for (final id in ids) {
        final entity = context.document.entity(id);
        if (entity == null) continue;
        // Only genuinely closed geometry can bound a fill; hatching an open
        // polyline silently produces nonsense, so it is refused per entity.
        final sink = PolylineSink();
        entity.emit(
          context.document.emitContext(tolerance: 0.05),
          sink,
        );
        for (var i = 0; i < sink.polylines.length; i++) {
          if (!sink.closedFlags[i]) continue;
          if (sink.polylines[i].length < 6) continue;
          loops.add(HatchLoop(vertices: sink.polylines[i]));
        }
      }
      if (loops.isEmpty) {
        return const CommandResult.failed(
          'None of the selected objects form a closed boundary.',
        );
      }
      return _commit(context, 'Hatch', [
        HatchEntity(
          id: 0,
          props: EntityProps(layer: context.document.currentLayer),
          loops: loops,
          patternName: pattern.toUpperCase(),
          solid: pattern.toUpperCase() == 'SOLID',
          patternScale: scale,
          patternAngle: angle,
        ),
      ]);
    },
  );

  static CommandDescriptor _dimLinear() => CommandDescriptor(
    id: 'draw.dimLinear',
    title: 'Linear Dimension',
    category: _category,
    aliases: const ['dli', 'dimlinear', 'dim'],
    icon: 'dimension',
    description:
        'Places a horizontal or vertical dimension. The dimension-line pick '
        'chooses the axis: above or below the origins measures width; left '
        'or right measures height. A line can stand in for the two origins.',
    params: const [
      ParamSpec(
        name: 'target',
        type: ParamType.entity,
        description: 'Line whose endpoints become the two origins',
        required: false,
      ),
      ParamSpec(
        name: 'first',
        type: ParamType.point,
        description: 'First extension-line origin',
        required: false,
      ),
      ParamSpec(
        name: 'second',
        type: ParamType.point,
        description: 'Second extension-line origin',
        required: false,
      ),
      ParamSpec.point(
        'dimLine',
        description: 'A point on the dimension line',
      ),
      _dimStyleParam,
    ],
    handler: (context) async {
      final origins = await _resolveDimOrigins(
        context,
        command: 'DIMLINEAR',
        needs: 'a line',
      );
      if (origins.error != null) {
        return CommandResult.failed(origins.error!);
      }
      final first = origins.first;
      final second = origins.second;
      context.input.setPreview(
        (cursor) => _dimLinearOverlay(first, second, cursor),
      );
      final dimLine = await context.resolvePoint(
        'dimLine',
        'DIMLINEAR  Specify dimension line location:',
        basePoint: first.lerp(second, 0.5),
      );
      context.input.setPreview(null);
      final entity = Construct.linearDimension(
        first,
        second,
        dimLine,
        props: EntityProps(layer: context.document.currentLayer),
        styleName: _dimStyleName(context),
      );
      if (entity == null) {
        return const CommandResult.failed(
          'The measurement is zero. Place the dimension line so it shows a '
          'horizontal or vertical length.',
        );
      }
      return _commit(context, 'Linear Dimension', [entity]);
    },
  );

  static List<OverlayShape> _dimLinearOverlay(
    Vec2 first,
    Vec2 second,
    Vec2 cursor,
  ) {
    final mid = first.lerp(second, 0.5);
    final horizontal = (cursor - mid).y.abs() >= (cursor - mid).x.abs();
    final a = horizontal ? Vec2(first.x, cursor.y) : Vec2(cursor.x, first.y);
    final b = horizontal ? Vec2(second.x, cursor.y) : Vec2(cursor.x, second.y);
    return [
      OverlayLine(first, a),
      OverlayLine(second, b),
      OverlayLine(a, b),
    ];
  }

  static CommandDescriptor _dimAligned() => CommandDescriptor(
    id: 'draw.dimAligned',
    title: 'Aligned Dimension',
    category: _category,
    aliases: const ['dal', 'dimaligned'],
    icon: 'dimension',
    description:
        'Places a dimension parallel to the two origins. The text is the '
        'true distance, not the horizontal or vertical component. A line '
        'can stand in for the two origins.',
    params: const [
      ParamSpec(
        name: 'target',
        type: ParamType.entity,
        description: 'Line whose endpoints become the two origins',
        required: false,
      ),
      ParamSpec(
        name: 'first',
        type: ParamType.point,
        description: 'First extension-line origin',
        required: false,
      ),
      ParamSpec(
        name: 'second',
        type: ParamType.point,
        description: 'Second extension-line origin',
        required: false,
      ),
      ParamSpec.point(
        'dimLine',
        description: 'A point on the dimension line',
      ),
      _dimStyleParam,
    ],
    handler: (context) async {
      final origins = await _resolveDimOrigins(
        context,
        command: 'DIMALIGNED',
        needs: 'a line',
      );
      if (origins.error != null) {
        return CommandResult.failed(origins.error!);
      }
      final first = origins.first;
      final second = origins.second;
      context.input.setPreview(
        (cursor) => _dimAlignedOverlay(first, second, cursor),
      );
      final dimLine = await context.resolvePoint(
        'dimLine',
        'DIMALIGNED  Specify dimension line location:',
        basePoint: first.lerp(second, 0.5),
      );
      context.input.setPreview(null);
      final entity = Construct.alignedDimension(
        first,
        second,
        dimLine,
        props: EntityProps(layer: context.document.currentLayer),
        styleName: _dimStyleName(context),
      );
      if (entity == null) {
        return const CommandResult.failed(
          'The two origins are the same point.',
        );
      }
      return _commit(context, 'Aligned Dimension', [entity]);
    },
  );

  static List<OverlayShape> _dimAlignedOverlay(
    Vec2 first,
    Vec2 second,
    Vec2 cursor,
  ) {
    final length = first.distanceTo(second);
    if (length < 1e-9) return const [];
    final unit = (second - first) / length;
    final normal = unit.perpendicular;
    var offset = (cursor - first).dot(normal);
    if (offset.abs() < 1e-6) offset = length * 0.15;
    final a = first + normal * offset;
    final b = second + normal * offset;
    return [
      OverlayLine(first, a),
      OverlayLine(second, b),
      OverlayLine(a, b),
    ];
  }

  /// Two extension-line origins: a line's endpoints, or two picked points.
  static Future<({Vec2 first, Vec2 second, String? error})> _resolveDimOrigins(
    CommandContext context, {
    required String command,
    required String needs,
  }) async {
    final targetId = context.args.integer('target');
    if (targetId != null) {
      final target = context.document.entity(targetId);
      if (target is! LineEntity) {
        return (
          first: const Vec2.zero(),
          second: const Vec2.zero(),
          error: '$command from an object needs $needs.',
        );
      }
      return (first: target.start, second: target.end, error: null);
    }
    final first = await context.resolvePoint(
      'first',
      '$command  Specify first extension line origin:',
    );
    final second = await context.resolvePoint(
      'second',
      '$command  Specify second extension line origin:',
      basePoint: first,
    );
    return (first: first, second: second, error: null);
  }

  static CommandDescriptor _dimRadius() => CommandDescriptor(
    id: 'draw.dimRadius',
    title: 'Radius Dimension',
    category: _category,
    aliases: const ['dimradius', 'dimrad'],
    icon: 'dimension',
    description:
        'Places a radius dimension on a circle or arc. The second pick is '
        'the arrow tip; the text is the radius, prefixed with R.',
    params: const [
      ParamSpec(
        name: 'target',
        type: ParamType.entity,
        description: 'Circle or arc to dimension',
        required: false,
      ),
      ParamSpec.point(
        'dimLine',
        description: 'Arrow tip and text location',
      ),
      _dimStyleParam,
    ],
    handler: (context) async {
      final supplied = context.args.integer('target');
      final int targetId;
      if (supplied != null) {
        targetId = supplied;
      } else {
        context.selection.clear();
        final picked = await context.input.selection(
          'DIMRADIUS  Select arc or circle:',
          useExistingSelection: false,
          single: true,
        );
        if (picked.isEmpty) return const CommandResult.cancelled();
        targetId = picked.first;
      }
      final target = context.document.entity(targetId);
      if (target == null ||
          (target is! CircleEntity && target is! ArcEntity)) {
        return const CommandResult.failed(
          'Radius dimension needs a circle or an arc.',
        );
      }
      final center = target is CircleEntity
          ? target.center
          : (target as ArcEntity).center;
      context.input.setPreview((cursor) => [OverlayLine(center, cursor)]);
      final dimLine = await context.resolvePoint(
        'dimLine',
        'DIMRADIUS  Specify dimension line location:',
        basePoint: center,
      );
      context.input.setPreview(null);
      final entity = Construct.radiusDimension(
        target,
        dimLine,
        props: EntityProps(layer: context.document.currentLayer),
        styleName: _dimStyleName(context),
      );
      if (entity == null) {
        return const CommandResult.failed(
          'The circle or arc has no radius to measure.',
        );
      }
      return _commit(context, 'Radius Dimension', [entity]);
    },
  );

  static CommandDescriptor _dimDiameter() => CommandDescriptor(
    id: 'draw.dimDiameter',
    title: 'Diameter Dimension',
    category: _category,
    aliases: const ['dimdiameter', 'dimdia'],
    icon: 'dimension',
    description:
        'Places a diameter dimension on a circle or arc. The second pick is '
        'the arrow tip; the text is the diameter, prefixed with Ø.',
    params: const [
      ParamSpec(
        name: 'target',
        type: ParamType.entity,
        description: 'Circle or arc to dimension',
        required: false,
      ),
      ParamSpec.point(
        'dimLine',
        description: 'Arrow tip and text location',
      ),
      _dimStyleParam,
    ],
    handler: (context) async {
      final supplied = context.args.integer('target');
      final int targetId;
      if (supplied != null) {
        targetId = supplied;
      } else {
        context.selection.clear();
        final picked = await context.input.selection(
          'DIMDIAMETER  Select arc or circle:',
          useExistingSelection: false,
          single: true,
        );
        if (picked.isEmpty) return const CommandResult.cancelled();
        targetId = picked.first;
      }
      final target = context.document.entity(targetId);
      if (target == null ||
          (target is! CircleEntity && target is! ArcEntity)) {
        return const CommandResult.failed(
          'Diameter dimension needs a circle or an arc.',
        );
      }
      final center = target is CircleEntity
          ? target.center
          : (target as ArcEntity).center;
      context.input.setPreview((cursor) {
        final dir = cursor - center;
        if (dir.length < 1e-9) return const <OverlayShape>[];
        final far = center - dir.normalized() * dir.length;
        return [OverlayLine(far, cursor)];
      });
      final dimLine = await context.resolvePoint(
        'dimLine',
        'DIMDIAMETER  Specify dimension line location:',
        basePoint: center,
      );
      context.input.setPreview(null);
      final entity = Construct.diameterDimension(
        target,
        dimLine,
        props: EntityProps(layer: context.document.currentLayer),
        styleName: _dimStyleName(context),
      );
      if (entity == null) {
        return const CommandResult.failed(
          'The circle or arc has no diameter to measure.',
        );
      }
      return _commit(context, 'Diameter Dimension', [entity]);
    },
  );

  static CommandDescriptor _centerMark() => CommandDescriptor(
    id: 'draw.centerMark',
    title: 'Center Mark',
    category: _category,
    aliases: const ['dimcenter', 'centermark'],
    icon: 'dimension',
    description:
        'Draws a centre mark on selected circles or arcs. A short cross '
        'sits on the centre; optional extensions continue past the '
        'circumference, the usual shop-drawing DIMCENTER.',
    params: const [
      ParamSpec.selection('ids', description: 'Circles or arcs to mark'),
      ParamSpec(
        name: 'size',
        type: ParamType.distance,
        description: 'Half-length of the centre cross',
        required: false,
        defaultValue: 2.5,
      ),
      ParamSpec(
        name: 'extend',
        type: ParamType.boolean,
        description: 'Draw extension lines past the circumference',
        required: false,
        defaultValue: true,
      ),
    ],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'DIMCENTER  Select circles or arcs:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();
      final size = context.args.number('size') ?? 2.5;
      final extend = context.args.boolean('extend') ?? true;
      final created = <CadEntity>[];
      for (final id in ids) {
        final entity = context.document.entity(id);
        if (entity == null) continue;
        final marks = Construct.centerMark(
          entity,
          props: EntityProps(layer: context.document.currentLayer),
          size: size,
          extend: extend,
        );
        if (marks != null) created.addAll(marks);
      }
      if (created.isEmpty) {
        return const CommandResult.failed(
          'Center mark needs a circle or an arc.',
        );
      }
      return _commit(context, 'Center Mark', created);
    },
  );

  static CommandDescriptor _centerLine() => CommandDescriptor(
    id: 'draw.centerLine',
    title: 'Centerline',
    category: _category,
    aliases: const ['centerline', 'cline'],
    icon: 'dimension',
    description:
        'Draws a centreline between two parallel lines, or through the '
        'centres of two circles or arcs. The line spans both objects and '
        'extends a little past each end.',
    params: const [
      ParamSpec(
        name: 'first',
        type: ParamType.entity,
        description: 'First line, circle or arc',
        required: false,
      ),
      ParamSpec(
        name: 'second',
        type: ParamType.entity,
        description: 'Second line, circle or arc',
        required: false,
      ),
      ParamSpec(
        name: 'extension',
        type: ParamType.distance,
        description: 'How far the centreline overshoots each end',
        required: false,
        defaultValue: 2.5,
      ),
    ],
    handler: (context) async {
      final pair = await _resolveCenterLinePair(context);
      if (pair == null) {
        return const CommandResult.cancelled();
      }
      final (first, second) = pair;
      final line = Construct.centerLine(
        first,
        second,
        props: EntityProps(layer: context.document.currentLayer),
        extension: context.args.number('extension') ?? 2.5,
      );
      if (line == null) {
        return const CommandResult.failed(
          'Centerline needs two parallel lines, or two circles or arcs '
          'with different centres.',
        );
      }
      return _commit(context, 'Centerline', [line]);
    },
  );

  static Future<(CadEntity, CadEntity)?> _resolveCenterLinePair(
    CommandContext context,
  ) async {
    var firstId = context.args.integer('first');
    var secondId = context.args.integer('second');
    if (firstId == null || secondId == null) {
      final ids = context.args.ids('ids') ?? context.selection.ids.toList();
      if (ids.length >= 2) {
        firstId ??= ids[0];
        secondId ??= ids[1];
      }
    }
    if (firstId == null) {
      context.selection.clear();
      final picked = await context.input.selection(
        'CENTERLINE  Select first line, circle or arc:',
        useExistingSelection: false,
        single: true,
      );
      if (picked.isEmpty) return null;
      firstId = picked.first;
    }
    if (secondId == null) {
      context.selection.clear();
      final picked = await context.input.selection(
        'CENTERLINE  Select second line, circle or arc:',
        useExistingSelection: false,
        single: true,
      );
      if (picked.isEmpty) return null;
      secondId = picked.first;
    }
    if (firstId == secondId) return null;
    final first = context.document.entity(firstId);
    final second = context.document.entity(secondId);
    if (first == null || second == null) return null;
    return (first, second);
  }

  static CommandDescriptor _dimAngular() => CommandDescriptor(
    id: 'draw.dimAngular',
    title: 'Angular Dimension',
    category: _category,
    aliases: const ['dimangular', 'dimang'],
    icon: 'dimension',
    description:
        'Places an angular dimension. Pick an arc and its centre is the '
        'vertex; pick two lines and their intersection is the vertex; the '
        'last pick sits on the dimension arc and chooses which sector is '
        'labelled. Three points still work when a vertex is supplied.',
    params: const [
      ParamSpec(
        name: 'arc',
        type: ParamType.entity,
        description: 'Arc whose sweep is dimensioned',
        required: false,
      ),
      ParamSpec(
        name: 'firstLine',
        type: ParamType.entity,
        description: 'First line of the angle',
        required: false,
      ),
      ParamSpec(
        name: 'secondLine',
        type: ParamType.entity,
        description: 'Second line of the angle',
        required: false,
      ),
      ParamSpec(
        name: 'vertex',
        type: ParamType.point,
        description: 'Vertex of the angle',
        required: false,
      ),
      ParamSpec(
        name: 'first',
        type: ParamType.point,
        description: 'A point on the first ray',
        required: false,
      ),
      ParamSpec(
        name: 'second',
        type: ParamType.point,
        description: 'A point on the second ray',
        required: false,
      ),
      ParamSpec.point(
        'dimLine',
        description: 'A point on the dimension arc',
      ),
      _dimStyleParam,
    ],
    handler: (context) async {
      if (context.args.point('vertex') == null &&
          context.args.point('first') == null) {
        return _dimAngularFromObjects(context);
      }
      final vertex = await context.resolvePoint(
        'vertex',
        'DIMANGULAR  Specify vertex:',
      );
      context.input
        ..setMarkers([vertex])
        ..setPreview((cursor) => [OverlayLine(vertex, cursor)]);
      final first = await context.resolvePoint(
        'first',
        'DIMANGULAR  Specify a point on the first ray:',
        basePoint: vertex,
      );
      context.input
        ..setMarkers([vertex, first])
        ..setPreview((cursor) => [
          OverlayLine(vertex, first),
          OverlayLine(vertex, cursor),
        ]);
      final second = await context.resolvePoint(
        'second',
        'DIMANGULAR  Specify a point on the second ray:',
        basePoint: vertex,
      );
      context.input
        ..setMarkers([vertex, first, second])
        ..setPreview((cursor) => _dimAngularOverlay(vertex, first, second, cursor));
      final dimLine = await context.resolvePoint(
        'dimLine',
        'DIMANGULAR  Specify dimension arc location:',
        basePoint: vertex,
      );
      context.input
        ..setPreview(null)
        ..setMarkers(const []);
      final entity = Construct.angularDimension(
        vertex,
        first,
        second,
        dimLine,
        props: EntityProps(layer: context.document.currentLayer),
        styleName: _dimStyleName(context),
      );
      if (entity == null) {
        return const CommandResult.failed(
          'The three points do not form an angle.',
        );
      }
      return _commit(context, 'Angular Dimension', [entity]);
    },
  );

  static List<OverlayShape> _dimAngularOverlay(
    Vec2 vertex,
    Vec2 first,
    Vec2 second,
    Vec2 cursor,
  ) {
    final dim = Construct.angularDimension(vertex, first, second, cursor);
    if (dim == null) {
      return [
        OverlayLine(vertex, first),
        OverlayLine(vertex, second),
      ];
    }
    final start = (dim.definitionPoints[1] - vertex).angle;
    final sweep = dim.measurement * math.pi / 180;
    final radius = vertex.distanceTo(cursor);
    return [
      OverlayLine(vertex, first),
      OverlayLine(vertex, second),
      if (radius > 1e-9)
        OverlayArc(
          center: vertex,
          radius: radius,
          startAngle: start,
          sweep: sweep,
        ),
    ];
  }

  static Future<CommandResult> _dimAngularFromObjects(
    CommandContext context,
  ) async {
    final arcId = context.args.integer('arc');
    if (arcId != null) {
      return _dimAngularFromArc(context, arcId);
    }
    final firstId = context.args.integer('firstLine');
    final secondId = context.args.integer('secondLine');
    final int id1;
    final int? id2;
    if (firstId != null && secondId != null) {
      id1 = firstId;
      id2 = secondId;
    } else {
      context.selection.clear();
      final firstPick = await context.input.selection(
        'DIMANGULAR  Select arc or first line:',
        useExistingSelection: false,
        single: true,
      );
      if (firstPick.isEmpty) return const CommandResult.cancelled();
      id1 = firstPick.first;
      final firstEntity = context.document.entity(id1);
      if (firstEntity is ArcEntity) {
        return _dimAngularFromArc(context, id1);
      }
      final secondPick = await context.input.selection(
        'DIMANGULAR  Select second line:',
        useExistingSelection: false,
        single: true,
      );
      if (secondPick.isEmpty) return const CommandResult.cancelled();
      id2 = secondPick.first;
    }
    if (id2 == null) {
      return const CommandResult.failed('Select two lines or one arc.');
    }
    final first = context.document.entity(id1);
    final second = context.document.entity(id2);
    if (first is! LineEntity || second is! LineEntity) {
      return const CommandResult.failed(
        'Angular dimension from two objects needs two lines.',
      );
    }
    if (id1 == id2) {
      return const CommandResult.failed('Select two different lines.');
    }
    final vertex = Intersect.lineLine(
      first.start,
      first.end,
      second.start,
      second.end,
    );
    if (vertex == null) {
      return const CommandResult.failed('The two lines are parallel.');
    }
    context.input
      ..setMarkers([vertex])
      ..setPreview(
        (cursor) => _dimAngularFromLinesOverlay(first, second, cursor),
      );
    final dimLine = await context.resolvePoint(
      'dimLine',
      'DIMANGULAR  Specify dimension arc location:',
      basePoint: vertex,
    );
    context.input
      ..setPreview(null)
      ..setMarkers(const []);
    final entity = Construct.angularDimensionFromLines(
      first,
      second,
      dimLine,
      props: EntityProps(layer: context.document.currentLayer),
      styleName: _dimStyleName(context),
    );
    if (entity == null) {
      return const CommandResult.failed(
        'The two lines do not form an angle at that location.',
      );
    }
    return _commit(context, 'Angular Dimension', [entity]);
  }

  static Future<CommandResult> _dimAngularFromArc(
    CommandContext context,
    int arcId,
  ) async {
    final target = context.document.entity(arcId);
    if (target is! ArcEntity) {
      return const CommandResult.failed(
        'Angular dimension from one object needs an arc.',
      );
    }
    context.input
      ..setMarkers([target.center, target.startPoint, target.endPoint])
      ..setPreview(
        (cursor) => _dimAngularOverlay(
          target.center,
          target.startPoint,
          target.endPoint,
          cursor,
        ),
      );
    final dimLine = await context.resolvePoint(
      'dimLine',
      'DIMANGULAR  Specify dimension arc location:',
      basePoint: target.center,
    );
    context.input
      ..setPreview(null)
      ..setMarkers(const []);
    final entity = Construct.angularDimensionFromArc(
      target,
      dimLine,
      props: EntityProps(layer: context.document.currentLayer),
      styleName: _dimStyleName(context),
    );
    if (entity == null) {
      return const CommandResult.failed(
        'The arc does not form an angle that can be labelled.',
      );
    }
    return _commit(context, 'Angular Dimension', [entity]);
  }

  static CommandDescriptor _dimContinue() => CommandDescriptor(
    id: 'draw.dimContinue',
    title: 'Continue Dimension',
    category: _category,
    aliases: const ['dco', 'dimcontinue'],
    icon: 'dimension',
    description:
        'Places the next linear or aligned dimension from the previous '
        'second origin, on the same dimension line. Chain several next '
        'points to walk a row of features.',
    params: const [
      ParamSpec(
        name: 'base',
        type: ParamType.entity,
        description: 'Linear or aligned dimension to continue',
        required: false,
      ),
      ParamSpec(
        name: 'next',
        type: ParamType.point,
        description: 'Next extension-line origin',
        required: false,
      ),
      ParamSpec(
        name: 'points',
        type: ParamType.json,
        description: 'Array of next [x, y] origins to chain',
        required: false,
      ),
    ],
    handler: (context) async {
      final base = await _resolveContinuedDimension(context);
      if (base == null) {
        return const CommandResult.failed(
          'DIMCONTINUE needs a linear or aligned dimension.',
        );
      }

      final supplied = [
        ..._pointList(context.args['points']),
        if (context.args.point('next') case final next?) next,
      ];
      final layer = EntityProps(layer: context.document.currentLayer);
      if (supplied.isNotEmpty) {
        final created = <CadEntity>[];
        var current = base;
        for (final origin in supplied) {
          final next = Construct.continueDimension(
            current,
            origin,
            props: layer,
          );
          if (next == null) {
            if (created.isEmpty) {
              return const CommandResult.failed(
                'The next origin does not continue that dimension.',
              );
            }
            break;
          }
          created.add(next);
          current = next;
        }
        return _commit(context, 'Continue Dimension', created);
      }

      final created = <CadEntity>[];
      var current = base;
      while (true) {
        context.input
          ..setMarkers([current.definitionPoints[1]])
          ..setPreview((cursor) => _dimContinueOverlay(current, cursor));
        final origin = await context.input.pointOrNull(
          'DIMCONTINUE  Specify next extension line origin:',
        );
        if (origin == null) break;
        final next = Construct.continueDimension(
          current,
          origin,
          props: layer,
        );
        if (next == null) {
          if (created.isEmpty) {
            context.input
              ..setPreview(null)
              ..setMarkers(const []);
            return const CommandResult.failed(
              'The next origin does not continue that dimension.',
            );
          }
          break;
        }
        created.add(next);
        current = next;
        if (!context.input.isInteractive) break;
      }
      context.input
        ..setPreview(null)
        ..setMarkers(const []);
      if (created.isEmpty) return const CommandResult.cancelled();
      return _commit(context, 'Continue Dimension', created);
    },
  );

  static CommandDescriptor _dimBaseline() => CommandDescriptor(
    id: 'draw.dimBaseline',
    title: 'Baseline Dimension',
    category: _category,
    aliases: const ['dba', 'dimbaseline'],
    icon: 'dimension',
    description:
        'Places the next linear or aligned dimension from the same first '
        'origin, on a dimension line stepped outward. Chain several next '
        'points to stack overall lengths.',
    params: const [
      ParamSpec(
        name: 'base',
        type: ParamType.entity,
        description: 'Linear or aligned dimension to stack from',
        required: false,
      ),
      ParamSpec(
        name: 'next',
        type: ParamType.point,
        description: 'Next extension-line origin',
        required: false,
      ),
      ParamSpec(
        name: 'points',
        type: ParamType.json,
        description: 'Array of next [x, y] origins to chain',
        required: false,
      ),
      ParamSpec(
        name: 'spacing',
        type: ParamType.distance,
        description: 'Offset between successive dimension lines',
        required: false,
        defaultValue: 8,
      ),
    ],
    handler: (context) async {
      final base = await _resolveContinuedDimension(context);
      if (base == null) {
        return const CommandResult.failed(
          'DIMBASELINE needs a linear or aligned dimension.',
        );
      }

      final spacing = context.args.number('spacing') ?? 8;
      if (spacing <= 1e-9) {
        return const CommandResult.failed(
          'Baseline spacing must be greater than zero.',
        );
      }
      final supplied = [
        ..._pointList(context.args['points']),
        if (context.args.point('next') case final next?) next,
      ];
      final layer = EntityProps(layer: context.document.currentLayer);
      if (supplied.isNotEmpty) {
        final created = <CadEntity>[];
        var current = base;
        for (final origin in supplied) {
          final next = Construct.baselineDimension(
            current,
            origin,
            props: layer,
            spacing: spacing,
          );
          if (next == null) {
            if (created.isEmpty) {
              return const CommandResult.failed(
                'The next origin does not stack on that dimension.',
              );
            }
            break;
          }
          created.add(next);
          current = next;
        }
        return _commit(context, 'Baseline Dimension', created);
      }

      final created = <CadEntity>[];
      var current = base;
      while (true) {
        context.input
          ..setMarkers([current.definitionPoints[0]])
          ..setPreview(
            (cursor) => _dimBaselineOverlay(current, cursor, spacing),
          );
        final origin = await context.input.pointOrNull(
          'DIMBASELINE  Specify a second extension line origin:',
        );
        if (origin == null) break;
        final next = Construct.baselineDimension(
          current,
          origin,
          props: layer,
          spacing: spacing,
        );
        if (next == null) {
          if (created.isEmpty) {
            context.input
              ..setPreview(null)
              ..setMarkers(const []);
            return const CommandResult.failed(
              'The next origin does not stack on that dimension.',
            );
          }
          break;
        }
        created.add(next);
        current = next;
        if (!context.input.isInteractive) break;
      }
      context.input
        ..setPreview(null)
        ..setMarkers(const []);
      if (created.isEmpty) return const CommandResult.cancelled();
      return _commit(context, 'Baseline Dimension', created);
    },
  );

  static Future<DimensionEntity?> _resolveContinuedDimension(
    CommandContext context,
  ) async {
    final supplied = context.args.integer('base');
    if (supplied != null) {
      return _continuableDimension(context.document.entity(supplied));
    }
    for (final id in context.selection.ids) {
      final dim = _continuableDimension(context.document.entity(id));
      if (dim != null) return dim;
    }
    if (context.input.isInteractive) {
      context.selection.clear();
      final picked = await context.input.selection(
        'DIMCONTINUE  Select a linear or aligned dimension:',
        useExistingSelection: false,
        single: true,
      );
      if (picked.isEmpty) return null;
      return _continuableDimension(context.document.entity(picked.first));
    }
    DimensionEntity? last;
    for (final entity in context.document.entities) {
      final dim = _continuableDimension(entity);
      if (dim != null) last = dim;
    }
    return last;
  }

  static DimensionEntity? _continuableDimension(CadEntity? entity) {
    if (entity is! DimensionEntity) return null;
    final type = entity.dimensionType & 0x0F;
    if (type > 1 || entity.definitionPoints.length < 2) return null;
    return entity;
  }

  static List<OverlayShape> _dimContinueOverlay(
    DimensionEntity base,
    Vec2 cursor,
  ) {
    final next = Construct.continueDimension(base, cursor);
    if (next == null || next.definitionPoints.length < 2) return const [];
    final first = next.definitionPoints[0];
    final second = next.definitionPoints[1];
    final dimLine = next.definitionPoints.length > 2
        ? next.definitionPoints[2]
        : next.textPosition;
    return (base.dimensionType & 0x0F) == 1
        ? _dimAlignedOverlay(first, second, dimLine)
        : _dimLinearOverlay(first, second, dimLine);
  }

  static List<OverlayShape> _dimBaselineOverlay(
    DimensionEntity base,
    Vec2 cursor,
    double spacing,
  ) {
    final next = Construct.baselineDimension(base, cursor, spacing: spacing);
    if (next == null || next.definitionPoints.length < 2) return const [];
    final first = next.definitionPoints[0];
    final second = next.definitionPoints[1];
    final dimLine = next.definitionPoints.length > 2
        ? next.definitionPoints[2]
        : next.textPosition;
    return (base.dimensionType & 0x0F) == 1
        ? _dimAlignedOverlay(first, second, dimLine)
        : _dimLinearOverlay(first, second, dimLine);
  }

  static List<OverlayShape> _dimAngularFromLinesOverlay(
    LineEntity first,
    LineEntity second,
    Vec2 cursor,
  ) {
    final dim = Construct.angularDimensionFromLines(first, second, cursor);
    if (dim == null) return const [];
    final vertex = dim.definitionPoints[0];
    final start = (dim.definitionPoints[1] - vertex).angle;
    final sweep = dim.measurement * math.pi / 180;
    final radius = vertex.distanceTo(cursor);
    return [
      if (radius > 1e-9)
        OverlayArc(
          center: vertex,
          radius: radius,
          startAngle: start,
          sweep: sweep,
        ),
    ];
  }

  static CommandDescriptor _dimStyle() => CommandDescriptor(
    id: 'annot.dimstyle',
    title: 'Dimension Style',
    category: _category,
    aliases: const ['dimstyle', '-dimstyle', 'ddim'],
    description:
        'Creates or edits a dimension style. Regenerated dimensions read '
        'text height, arrow size, extension offsets, scale and decimal '
        'places from the named style. Omit the name to list styles or to '
        'edit the current one.',
    params: const [
      ParamSpec(
        name: 'name',
        type: ParamType.text,
        description: 'Style to create or edit. Omit to list or edit current.',
        required: false,
      ),
      ParamSpec(
        name: 'textHeight',
        type: ParamType.distance,
        description: 'DIMTXT, text height in drawing units',
        required: false,
      ),
      ParamSpec(
        name: 'arrowSize',
        type: ParamType.distance,
        description: 'DIMASZ, arrowhead size',
        required: false,
      ),
      ParamSpec(
        name: 'decimalPlaces',
        type: ParamType.integer,
        description: 'DIMDEC, 0–8',
        required: false,
      ),
      ParamSpec(
        name: 'scale',
        type: ParamType.distance,
        description: 'DIMSCALE, overall scale',
        required: false,
      ),
      ParamSpec(
        name: 'extensionOffset',
        type: ParamType.distance,
        description: 'DIMEXO, gap from the origin to the extension line',
        required: false,
      ),
      ParamSpec(
        name: 'extensionExtend',
        type: ParamType.distance,
        description: 'DIMEXE, extension past the dimension line',
        required: false,
      ),
      ParamSpec(
        name: 'textGap',
        type: ParamType.distance,
        description: 'DIMGAP, stored for later text placement',
        required: false,
      ),
      ParamSpec(
        name: 'textStyle',
        type: ParamType.text,
        description: 'DIMTXSTY, text style name',
        required: false,
      ),
      ParamSpec(
        name: 'current',
        type: ParamType.boolean,
        description: 'Make this the current dimension style',
        required: false,
      ),
    ],
    handler: (context) async {
      final name = context.args.text('name')?.trim() ?? '';
      final makeCurrent = context.args.boolean('current') ?? false;
      final hasEdits = context.args.number('textHeight') != null ||
          context.args.number('arrowSize') != null ||
          context.args.integer('decimalPlaces') != null ||
          context.args.number('scale') != null ||
          context.args.number('extensionOffset') != null ||
          context.args.number('extensionExtend') != null ||
          context.args.number('textGap') != null ||
          (context.args.text('textStyle')?.trim().isNotEmpty ?? false);
      if (name.isEmpty && !hasEdits && !makeCurrent) {
        return _listDimStyles(context);
      }

      final target = name.isEmpty ? context.document.currentDimStyle : name;
      if (target.isEmpty) {
        return const CommandResult.failed('A dimension style needs a name.');
      }
      final existing = context.document.namedDimStyle(target);
      if (!hasEdits) {
        if (existing == null) {
          return CommandResult.failed('No dimension style named $target.');
        }
        if (!makeCurrent || context.document.currentDimStyle == existing.name) {
          return CommandResult.ok(
            message: 'Current dimension style is ${existing.name}.',
            data: _dimStyleData(existing, current: existing.name),
          );
        }
        final committed = context.edit('Current DimStyle', (transaction) {
          transaction.setCurrentDimStyle(existing.name);
        });
        if (committed == null) {
          return const CommandResult.failed(
            'The current dimension style was not changed.',
          );
        }
        return CommandResult(
          status: CommandStatus.ok,
          message: 'Current dimension style is ${existing.name}.',
          data: _dimStyleData(existing, current: existing.name),
          transaction: committed,
        );
      }

      final base = existing ?? DimStyleDef(name: target);
      final next = _dimStyleFromArgs(context, base);
      if (next.$1 != null) return CommandResult.failed(next.$1!);
      final style = next.$2!;
      final committed = context.edit('DimStyle', (transaction) {
        transaction.putDimStyle(style);
        if (makeCurrent || existing == null) {
          transaction.setCurrentDimStyle(style.name);
        }
      });
      if (committed == null) {
        return const CommandResult.failed('The dimension style was not saved.');
      }
      return CommandResult(
        status: CommandStatus.ok,
        message: existing == null
            ? 'Created dimension style ${style.name}.'
            : 'Updated dimension style ${style.name}.',
        data: _dimStyleData(
          style,
          current: makeCurrent || existing == null
              ? style.name
              : context.document.currentDimStyle,
        ),
        transaction: committed,
      );
    },
  );

  static CommandResult _listDimStyles(CommandContext context) {
    final current = context.document.currentDimStyle;
    final styles = [
      for (final style in context.document.dimStyles.values)
        _dimStyleData(style, current: current),
    ];
    return CommandResult.ok(
      message: '${styles.length} dimension style(s). Current is $current.',
      data: {'current': current, 'styles': styles},
    );
  }

  static Map<String, Object?> _dimStyleData(
    DimStyleDef style, {
    required String current,
  }) => {
    'name': style.name,
    'textHeight': style.textHeight,
    'arrowSize': style.arrowSize,
    'decimalPlaces': style.decimalPlaces,
    'scale': style.scale,
    'extensionOffset': style.extensionLineOffset,
    'extensionExtend': style.extensionLineExtend,
    'textGap': style.textGap,
    'textStyle': style.textStyle,
    'current': style.name == current,
  };

  static (String?, DimStyleDef?) _dimStyleFromArgs(
    CommandContext context,
    DimStyleDef base,
  ) {
    final textHeight = context.args.number('textHeight') ?? base.textHeight;
    final arrowSize = context.args.number('arrowSize') ?? base.arrowSize;
    final decimals =
        context.args.integer('decimalPlaces') ?? base.decimalPlaces;
    final scale = context.args.number('scale') ?? base.scale;
    final exo =
        context.args.number('extensionOffset') ?? base.extensionLineOffset;
    final exe =
        context.args.number('extensionExtend') ?? base.extensionLineExtend;
    final gap = context.args.number('textGap') ?? base.textGap;
    final textStyle = context.args.text('textStyle')?.trim();
    if (textHeight <= 0) {
      return ('Text height must be positive.', null);
    }
    if (arrowSize <= 0) {
      return ('Arrow size must be positive.', null);
    }
    if (scale <= 0) {
      return ('Dimension scale must be positive.', null);
    }
    if (decimals < 0 || decimals > 8) {
      return ('Decimal places must be between 0 and 8.', null);
    }
    if (exo < 0 || exe < 0 || gap < 0) {
      return ('Extension offset, extend and text gap cannot be negative.', null);
    }
    return (
      null,
      base.copyWith(
        textHeight: textHeight,
        arrowSize: arrowSize,
        decimalPlaces: decimals,
        scale: scale,
        extensionLineOffset: exo,
        extensionLineExtend: exe,
        textGap: gap,
        textStyle: (textStyle == null || textStyle.isEmpty)
            ? base.textStyle
            : textStyle,
      ),
    );
  }

  /// Adds [entities] in one transaction and reports what happened.
  ///
  /// Returning the transaction on the result is what lets an AI turn be
  /// summarised and undone as a unit, and what lets the UI select what was just
  /// drawn without guessing at ids.
  static CommandResult _commit(
    CommandContext context,
    String label,
    List<CadEntity> entities, {
    String? message,
  }) {
    if (entities.isEmpty) return const CommandResult.cancelled();
    final committed = context.edit(label, (transaction) {
      transaction.addAll(entities);
    });
    if (committed == null) {
      return const CommandResult.failed('Nothing was created.');
    }
    context.selection.replace(committed.change.added);
    return CommandResult(
      status: CommandStatus.ok,
      message: message ??
          '$label: ${committed.change.added.length} object(s) created.',
      data: {'ids': committed.change.added},
      transaction: committed,
    );
  }

  static List<Vec2> _pointList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value) ?CommandArgs.parsePoint(item),
    ];
  }
}
