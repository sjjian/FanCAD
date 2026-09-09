import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawArcCommand extends FanCadCommand {
  const DrawArcCommand();

  @override
  String get id => 'draw.arc';
  @override
  String get title => 'Arc';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['a', 'arc'];
  @override
  String? get icon => 'arc';
  @override
  String get description =>
      'Draws a circular arc through three points: start, a point on the arc, '
      'and end.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.point('start', description: 'Start of the arc'),
    ParamSpec.point('via', description: 'A point the arc passes through'),
    ParamSpec.point('end', description: 'End of the arc'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
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
      return commitDraw(
        context,
        'Line',
        [LineEntity(id: 0, props: props, start: start, end: end)],
        message: 'The three points were collinear, so a line was drawn.',
      );
    }
    return commitDraw(context, 'Arc', [arc]);
  }
}
