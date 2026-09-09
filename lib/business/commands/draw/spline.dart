import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawSplineCommand extends FanCadCommand {
  const DrawSplineCommand();

  @override
  String get id => 'draw.spline';
  @override
  String get title => 'Spline';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['spl', 'spline'];
  @override
  String get description =>
      'Draws a clamped B-spline. Control-point mode pulls the curve toward '
      'the clicks and only guarantees the ends. Fit mode interpolates every '
      'point. Pass a points array to create it non-interactively.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'method',
      type: ParamType.text,
      description: 'Control or Fit',
      required: false,
    ),
    ParamSpec(
      name: 'points',
      type: ParamType.points,
      description: 'Array of [x, y] points',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final layer = context.document.currentLayer;
    final supplied = context.args.points('points');
    final useFit = _splineUsesFit(context.args.text('method'));
    if (supplied.length >= 2) {
      final spline = useFit
          ? Construct.splineFromFit(supplied, props: EntityProps(layer: layer))
          : Construct.splineFromControls(
              supplied,
              props: EntityProps(layer: layer),
            );
      if (spline == null) {
        return CommandResult.failed(
          useFit
              ? 'Need at least two fit points that can be interpolated.'
              : 'Need at least two control points.',
        );
      }
      return commitDraw(context, 'Spline', [spline]);
    }
    if (!context.input.isInteractive) {
      return const CommandResult.failed(
        'Spline needs points as [[x, y], [x, y], ...] with at least two vertices.',
      );
    }

    final method =
        context.args.text('method') ??
        await context.input.keyword(
          'SPLINE  Enter method [Control/Fit]:',
          const ['Control', 'Fit'],
          defaultOption: 'Control',
        );
    final fit = _splineUsesFit(method);
    final kind = fit ? 'fit' : 'control';
    final points = <Vec2>[];
    while (true) {
      final keywords = [if (points.isNotEmpty) 'Undo'];
      context.input
        ..setMarkers(List.of(points))
        ..setPreview(
          points.isEmpty
              ? null
              : (cursor) => _splineOverlay([...points, cursor], fit: fit),
        );
      final pick = await context.input.pointOrKeyword(
        points.isEmpty
            ? 'SPLINE  Specify first $kind point:'
            : 'SPLINE  Specify next $kind point (Escape to finish):',
        keywords: keywords,
      );
      if (pick == null) break;
      if (pick.keyword == 'Undo') {
        if (points.isNotEmpty) points.removeLast();
        continue;
      }
      final next = pick.point;
      if (next == null) break;
      points.add(next);
    }
    context.input
      ..setPreview(null)
      ..setMarkers(const []);

    if (points.length < 2) return const CommandResult.cancelled();
    final spline = fit
        ? Construct.splineFromFit(points, props: EntityProps(layer: layer))
        : Construct.splineFromControls(
            points,
            props: EntityProps(layer: layer),
          );
    if (spline == null) {
      return CommandResult.failed(
        fit
            ? 'Need at least two fit points that can be interpolated.'
            : 'Need at least two control points.',
      );
    }
    return commitDraw(context, 'Spline', [spline]);
  }
}

bool _splineUsesFit(String? method) =>
    (method ?? '').trim().toLowerCase() == 'fit';

List<OverlayShape> _splineOverlay(List<Vec2> points, {bool fit = false}) {
  final spline = fit
      ? Construct.splineFromFit(points)
      : Construct.splineFromControls(points);
  if (spline == null) return [OverlayPolyline(List.of(points))];
  final sampled = Flatten.bspline(
    controlPoints: spline.controlPoints,
    knots: spline.knots,
    degree: spline.degree,
    tolerance: 0.2,
  );
  return [
    OverlayPolyline(List.of(points), dashed: true),
    OverlayPolyline([
      for (var i = 0; i + 1 < sampled.length; i += 2)
        Vec2(sampled[i], sampled[i + 1]),
    ]),
  ];
}
