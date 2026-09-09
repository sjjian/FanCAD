import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawCircle2pCommand extends FanCadCommand {
  const DrawCircle2pCommand();

  @override
  String get id => 'draw.circle2p';
  @override
  String get title => 'Circle (2 Points)';
  @override
  String get category => _category;
  @override
  String get description =>
      'Draws a circle whose diameter is the segment between two '
      'points.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.point('first', description: 'One end of the diameter'),
    ParamSpec.point('second', description: 'The other end of the diameter'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
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
    return commitDraw(context, 'Circle', [
      CircleEntity(
        id: 0,
        props: EntityProps(layer: context.document.currentLayer),
        center: first.lerp(second, 0.5),
        radius: radius,
      ),
    ]);
  }
}
