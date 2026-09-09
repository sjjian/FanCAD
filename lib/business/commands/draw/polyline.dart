import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawPolylineCommand extends FanCadCommand {
  const DrawPolylineCommand();

  @override
  String get id => 'draw.polyline';
  @override
  String get title => 'Polyline';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['pl', 'pline', 'polyline'];
  @override
  String? get icon => 'polyline';
  @override
  String get description =>
      'Draws a connected sequence of segments as one polyline entity. Pass a '
      'points array to create it non-interactively.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'points',
      type: ParamType.points,
      description: 'Array of [x, y] vertices',
      required: false,
    ),
    ParamSpec(
      name: 'closed',
      type: ParamType.boolean,
      description: 'Whether to close the polyline back to its first vertex',
      required: false,
      defaultValue: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final layer = context.document.currentLayer;
    final supplied = context.args.points('points');
    if (supplied.length >= 2) {
      return commitDraw(context, 'Polyline', [
        PolylineEntity.fromPoints(
          id: 0,
          props: EntityProps(layer: layer),
          points: supplied,
          closed: context.args.boolean('closed') ?? false,
        ),
      ]);
    }
    if (!context.input.isInteractive) {
      return const CommandResult.failed(
        'Polyline needs points as [[x, y], [x, y], ...] with at least two vertices.',
      );
    }

    final points = <Vec2>[];
    var closed = context.args.boolean('closed') ?? false;
    while (true) {
      final keywords = vertexKeywords(points.length);
      context.input
        ..setMarkers(List.of(points))
        ..setPreview(
          points.isEmpty
              ? null
              : (cursor) => [
                  OverlayPolyline(List.of(points)),
                  OverlayLine(points.last, cursor),
                  if (points.length >= 2)
                    OverlayLine(points.first, cursor, dashed: true),
                ],
        );
      final pick = await context.input.pointOrKeyword(
        points.isEmpty
            ? 'PLINE  Specify start point:'
            : 'PLINE  Specify next point (Escape to finish):',
        keywords: keywords,
      );
      if (pick == null) break;
      if (pick.keyword == 'Undo') {
        if (points.isNotEmpty) points.removeLast();
        continue;
      }
      if (pick.keyword == 'Close') {
        if (points.length >= 3) closed = true;
        break;
      }
      final next = pick.point;
      if (next == null) break;
      points.add(next);
    }
    context.input
      ..setPreview(null)
      ..setMarkers(const []);

    if (points.length < 2) return const CommandResult.cancelled();
    return commitDraw(context, 'Polyline', [
      PolylineEntity.fromPoints(
        id: 0,
        props: EntityProps(layer: layer),
        points: points,
        closed: closed,
      ),
    ]);
  }
}
