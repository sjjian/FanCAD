import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Inquiry';

class QueryDistanceCommand extends FanCadCommand {
  const QueryDistanceCommand();

  @override
  String get id => 'query.distance';
  @override
  String get title => 'Distance';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['di', 'dist'];
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  String get description =>
      'Measures the distance and angle between two points.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.point('from'),
    ParamSpec.point('to'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
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
  }
}
