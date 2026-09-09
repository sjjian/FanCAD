import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawCircleCommand extends FanCadCommand {
  const DrawCircleCommand();

  @override
  String get id => 'draw.circle';
  @override
  String get title => 'Circle';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['c', 'circle'];
  @override
  String? get icon => 'circle';
  @override
  String get description => 'Draws a circle from a centre point and a radius.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.point('center', description: 'Centre of the circle'),
    ParamSpec(
      name: 'radius',
      type: ParamType.distance,
      description: 'Radius in drawing units',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
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
    final radius =
        context.args.number('radius') ??
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
    return commitDraw(context, 'Circle', [
      CircleEntity(
        id: 0,
        props: EntityProps(layer: context.document.currentLayer),
        center: center,
        radius: radius,
      ),
    ]);
  }
}
