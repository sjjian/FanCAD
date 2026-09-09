import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawPolygonCommand extends FanCadCommand {
  const DrawPolygonCommand();

  @override
  String get id => 'draw.polygon';
  @override
  String get title => 'Polygon';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['pol', 'polygon'];
  @override
  String get description => 'Draws a regular polygon inscribed in a circle.';
  @override
  List<ParamSpec> get params => const [
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
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final sides =
        context.args.integer('sides') ??
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
          OverlayPolyline([
            for (var i = 0; i < polygon.vertexCount; i++) polygon.vertexAt(i),
          ], closed: true),
          OverlayArc(center: center, radius: radius),
        ];
      });
    final radius =
        context.args.number('radius') ??
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
    return commitDraw(context, 'Polygon', [
      Construct.polygon(
        center: center,
        radius: radius,
        sides: sides,
        props: EntityProps(layer: context.document.currentLayer),
      ),
    ]);
  }
}
