import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Inquiry';

class QueryAngleCommand extends FanCadCommand {
  const QueryAngleCommand();

  @override
  String get id => 'query.angle';
  @override
  String get title => 'Angle';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['ang', 'angle'];
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  String get description =>
      'Measures the angle at a vertex between two rays. The first point is '
      'the vertex; the next two define the sides.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.point('vertex', description: 'Vertex of the angle'),
    ParamSpec.point('first', description: 'A point on the first ray'),
    ParamSpec.point('second', description: 'A point on the second ray'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
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
      data: {'angle': interior, 'signed': signed},
    );
  }
}
