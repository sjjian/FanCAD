import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawXlineCommand extends FanCadCommand {
  const DrawXlineCommand();

  @override
  String get id => 'draw.xline';
  @override
  String get title => 'Construction Line';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['xl', 'xline'];
  @override
  String get description =>
      'Draws an infinite construction line through a point in a given '
      'direction. The second point only sets the angle; both sides extend '
      'without end.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.point('origin', description: 'A point on the line'),
    ParamSpec.point(
      'through',
      description: 'A second point that sets the direction',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final origin = await context.resolvePoint(
      'origin',
      'XLINE  Specify a point:',
    );
    context.input
      ..setMarkers([origin])
      ..setPreview(
        (cursor) => [OverlayTrackingLine(origin, (cursor - origin).angle)],
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
    return commitDraw(context, 'Xline', [
      XLineEntity(
        id: 0,
        props: EntityProps(layer: context.document.currentLayer),
        origin: origin,
        direction: direction,
      ),
    ]);
  }
}
