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
    _hatch(),
  ];

  static const String _category = 'Draw';

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
        'Draws a clamped B-spline from control points. The curve passes '
        'through the first and last points and is pulled toward the ones in '
        'between. Pass a points array to create it non-interactively.',
    params: const [
      ParamSpec(
        name: 'points',
        type: ParamType.json,
        description: 'Array of [x, y] control points',
        required: false,
      ),
    ],
    handler: (context) async {
      final layer = context.document.currentLayer;
      final supplied = _pointList(context.args['points']);
      if (supplied.length >= 2) {
        final spline = Construct.splineFromControls(
          supplied,
          props: EntityProps(layer: layer),
        );
        if (spline == null) {
          return const CommandResult.failed('Need at least two control points.');
        }
        return _commit(context, 'Spline', [spline]);
      }

      final points = <Vec2>[];
      while (true) {
        context.input
          ..setMarkers(List.of(points))
          ..setPreview(
            points.isEmpty
                ? null
                : (cursor) => _splineOverlay([...points, cursor]),
          );
        final next = await context.input.pointOrNull(
          points.isEmpty
              ? 'SPLINE  Specify first point:'
              : 'SPLINE  Specify next control point (Escape to finish):',
        );
        if (next == null) break;
        points.add(next);
      }
      context.input
        ..setPreview(null)
        ..setMarkers(const []);

      if (points.length < 2) return const CommandResult.cancelled();
      final spline = Construct.splineFromControls(
        points,
        props: EntityProps(layer: layer),
      );
      if (spline == null) {
        return const CommandResult.failed('Need at least two control points.');
      }
      return _commit(context, 'Spline', [spline]);
    },
  );

  static List<OverlayShape> _splineOverlay(List<Vec2> points) {
    final spline = Construct.splineFromControls(points);
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
        'Places point markers that split a line into equal segments. The '
        'endpoints are left alone; only the interior divisions are created.',
    params: const [
      ParamSpec(
        name: 'target',
        type: ParamType.entity,
        description: 'The line to divide',
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
          'DIVIDE  Select a line:',
          useExistingSelection: false,
          single: true,
        );
        if (picked.isEmpty) return const CommandResult.cancelled();
        targetId = picked.first;
      }

      final target = context.document.entity(targetId);
      if (target is! LineEntity) {
        return const CommandResult.failed(
          'Divide currently supports lines only.',
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

      final points = Construct.divideLine(target, segments);
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
        'Places point markers at a fixed spacing along a line, starting from '
        'the end nearer the pick. Endpoints are not marked.',
    params: const [
      ParamSpec(
        name: 'target',
        type: ParamType.entity,
        description: 'The line to measure',
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
          'MEASURE  Select a line:',
          useExistingSelection: false,
          single: true,
        );
        if (picked.isEmpty) return const CommandResult.cancelled();
        targetId = picked.first;
      }

      final target = context.document.entity(targetId);
      if (target is! LineEntity) {
        return const CommandResult.failed(
          'Measure currently supports lines only.',
        );
      }

      final pick = context.args.point('pick') ?? target.start;
      final spacing = context.args.number('spacing') ??
          await context.input.number('MEASURE  Specify segment length:');
      if (spacing <= 0) {
        return const CommandResult.failed('The spacing must be positive.');
      }

      final points = Construct.measureLine(target, spacing, pick);
      if (points.isEmpty) {
        return const CommandResult.failed(
          'The line is shorter than the spacing, so nothing was placed.',
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
    ],
    handler: (context) async {
      final ids = await context.resolveSelection(
        'ids',
        'HATCH  Select closed boundaries:',
      );
      if (ids.isEmpty) return const CommandResult.cancelled();

      final pattern = context.args.text('pattern') ?? 'SOLID';
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
        ),
      ]);
    },
  );

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
