import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawDimAngularCommand extends FanCadCommand {
  const DrawDimAngularCommand();

  @override
  String get id => 'draw.dimAngular';
  @override
  String get title => 'Angular Dimension';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['dimangular', 'dimang'];
  @override
  String? get icon => 'dimension';
  @override
  String get description =>
      'Places an angular dimension. Pick an arc and its centre is the '
      'vertex; pick two lines and their intersection is the vertex; the '
      'last pick sits on the dimension arc and chooses which sector is '
      'labelled. Three points still work when a vertex is supplied.';
  @override
  List<ParamSpec> get params => const [
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
    ParamSpec.point('dimLine', description: 'A point on the dimension arc'),
    dimStyleParam,
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
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
      ..setPreview(
        (cursor) => [OverlayLine(vertex, first), OverlayLine(vertex, cursor)],
      );
    final second = await context.resolvePoint(
      'second',
      'DIMANGULAR  Specify a point on the second ray:',
      basePoint: vertex,
    );
    context.input
      ..setMarkers([vertex, first, second])
      ..setPreview(
        (cursor) => _dimAngularOverlay(vertex, first, second, cursor),
      );
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
      styleName: dimStyleName(context),
    );
    if (entity == null) {
      return const CommandResult.failed(
        'The three points do not form an angle.',
      );
    }
    return commitDraw(context, 'Angular Dimension', [entity]);
  }
}

List<OverlayShape> _dimAngularOverlay(
  Vec2 vertex,
  Vec2 first,
  Vec2 second,
  Vec2 cursor,
) {
  final dim = Construct.angularDimension(vertex, first, second, cursor);
  if (dim == null) {
    return [OverlayLine(vertex, first), OverlayLine(vertex, second)];
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

Future<CommandResult> _dimAngularFromObjects(CommandContext context) async {
  final arcId = context.args.integer('arc');
  if (arcId != null) {
    return _dimAngularFromArc(context, arcId);
  }
  final firstId = context.args.integer('firstLine');
  final secondId = context.args.integer('secondLine');
  final int id1;
  final int id2;
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
    styleName: dimStyleName(context),
  );
  if (entity == null) {
    return const CommandResult.failed(
      'The two lines do not form an angle at that location.',
    );
  }
  return commitDraw(context, 'Angular Dimension', [entity]);
}

Future<CommandResult> _dimAngularFromArc(
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
    styleName: dimStyleName(context),
  );
  if (entity == null) {
    return const CommandResult.failed(
      'The arc does not form an angle that can be labelled.',
    );
  }
  return commitDraw(context, 'Angular Dimension', [entity]);
}

List<OverlayShape> _dimAngularFromLinesOverlay(
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
