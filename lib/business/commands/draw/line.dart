import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawLineCommand extends FanCadCommand {
  const DrawLineCommand();

  @override
  String get id => 'draw.line';
  @override
  String get title => 'Line';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['l', 'line'];
  @override
  String? get icon => 'line';
  @override
  String get description =>
      'Draws one or more connected straight line segments. Supply start and '
      'end to draw a single segment non-interactively.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.point('start', description: 'Start of the first segment'),
    ParamSpec.point('end', description: 'End of the first segment'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final layer = context.document.currentLayer;
    final points = <Vec2>[];
    final created = <CadEntity>[];

    // The first point has no rubber band to draw, so the preview only
    // becomes interesting from the second prompt onwards. Undo and Close
    // share that prompt so a mistyped vertex does not cancel the command.
    while (true) {
      final keywords = vertexKeywords(points.length);
      context.input
        ..setMarkers(List.of(points))
        ..setPreview(
          points.isEmpty
              ? null
              : (cursor) => [
                  if (points.length > 1) OverlayPolyline(List.of(points)),
                  OverlayLine(points.last, cursor),
                ],
        );
      final pick = await context.input.pointOrKeyword(
        points.isEmpty
            ? 'LINE  Specify first point:'
            : 'LINE  Specify next point (Escape to finish):',
        keywords: keywords,
      );
      if (pick == null) break;
      if (pick.keyword == 'Undo') {
        if (created.isNotEmpty) created.removeLast();
        if (points.isNotEmpty) points.removeLast();
        continue;
      }
      if (pick.keyword == 'Close') {
        if (points.length >= 3 &&
            points.last.distanceTo(points.first) > 1e-12) {
          created.add(
            LineEntity(
              id: 0,
              props: EntityProps(layer: layer),
              start: points.last,
              end: points.first,
            ),
          );
        }
        break;
      }
      final next = pick.point;
      if (next == null) break;
      if (points.isNotEmpty && next.distanceTo(points.last) > 1e-12) {
        created.add(
          LineEntity(
            id: 0,
            props: EntityProps(layer: layer),
            start: points.last,
            end: next,
          ),
        );
      }
      points.add(next);
      // A non-interactive caller supplied exactly two points and has no way
      // to answer a third prompt, so one segment is the whole command.
      if (!context.input.isInteractive && points.length >= 2) break;
    }
    context.input
      ..setPreview(null)
      ..setMarkers(const []);

    if (created.isEmpty) return const CommandResult.cancelled();
    return commitDraw(context, 'Line', created);
  }
}
