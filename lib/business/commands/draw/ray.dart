import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawRayCommand extends FanCadCommand {
  const DrawRayCommand();

  @override
  String get id => 'draw.ray';
  @override
  String get title => 'Ray';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['ray'];
  @override
  String get description =>
      'Draws a semi-infinite ray from a start point through a second point. '
      'Unlike XLINE, it has a beginning.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.point('origin', description: 'Start of the ray'),
    ParamSpec.point('through', description: 'A point the ray passes through'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
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
    return commitDraw(context, 'Ray', [
      RayEntity(
        id: 0,
        props: EntityProps(layer: context.document.currentLayer),
        origin: origin,
        direction: direction,
      ),
    ]);
  }
}
