import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawLeaderCommand extends FanCadCommand {
  const DrawLeaderCommand();

  @override
  String get id => 'draw.leader';
  @override
  String get title => 'Leader';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['le', 'leader', 'qleader'];
  @override
  String? get icon => 'leader';
  @override
  String get description =>
      'Draws a leader from an arrow tip through one or more vertices. '
      'Optional annotation text sits on a horizontal landing at the last '
      'point, the same way AutoCAD LEADER places a callout.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'points',
      type: ParamType.points,
      description: 'Array of [x, y] vertices, first is the arrow tip',
      required: false,
    ),
    ParamSpec(
      name: 'text',
      type: ParamType.text,
      description: 'Annotation placed at the landing; empty is the leader only',
      required: false,
    ),
    ParamSpec(
      name: 'height',
      type: ParamType.distance,
      description: 'Annotation height in drawing units',
      required: false,
      defaultValue: 2.5,
    ),
    ParamSpec(
      name: 'arrow',
      type: ParamType.boolean,
      description: 'Whether the first vertex draws an arrowhead',
      required: false,
      defaultValue: true,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final layer = context.document.currentLayer;
    var points = pointList(context.args['points']);
    if (points.length < 2) {
      points = [];
      while (true) {
        final keywords = [if (points.isNotEmpty) 'Undo'];
        context.input
          ..setMarkers(List.of(points))
          ..setPreview(
            points.isEmpty
                ? null
                : (cursor) => [
                    OverlayPolyline(List.of(points)),
                    OverlayLine(points.last, cursor),
                  ],
          );
        final pick = await context.input.pointOrKeyword(
          points.isEmpty
              ? 'LEADER  Specify first leader point:'
              : 'LEADER  Specify next point (Escape to finish):',
          keywords: keywords,
        );
        if (pick == null) break;
        if (pick.keyword == 'Undo') {
          if (points.isNotEmpty) points.removeLast();
          continue;
        }
        final next = pick.point;
        if (next == null) break;
        if (points.isEmpty || next.distanceTo(points.last) > 1e-12) {
          points.add(next);
        }
        if (!context.input.isInteractive && points.length >= 2) break;
      }
      context.input
        ..setPreview(null)
        ..setMarkers(const []);
    }

    if (points.length < 2) {
      return const CommandResult.failed('A leader needs at least two points.');
    }

    final annotation =
        context.args.text('text') ??
        (context.input.isInteractive
            ? await context.input.text(
                'LEADER  Enter annotation text <none>:',
                defaultValue: '',
              )
            : '');
    final height = context.args.number('height') ?? 2.5;
    final created = Construct.leader(
      points,
      props: EntityProps(layer: layer),
      annotation: annotation,
      textHeight: height,
      hasArrowHead: context.args.boolean('arrow') ?? true,
    );
    if (created == null) {
      return const CommandResult.failed(
        'A leader needs at least two distinct points.',
      );
    }
    return commitDraw(context, 'Leader', created);
  }
}
