import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawEllipseCommand extends FanCadCommand {
  const DrawEllipseCommand();

  @override
  String get id => 'draw.ellipse';
  @override
  String get title => 'Ellipse';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['el', 'ellipse'];
  @override
  String get description =>
      'Draws an ellipse from a centre, one axis endpoint, and the distance '
      'to the other axis.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.point('center', description: 'Centre of the ellipse'),
    ParamSpec.point('axisEnd', description: 'End of the first axis'),
    ParamSpec(
      name: 'otherRadius',
      type: ParamType.distance,
      description: 'Distance from the centre to the other axis',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final center = await context.resolvePoint(
      'center',
      'ELLIPSE  Specify center:',
    );
    context.input
      ..setMarkers([center])
      ..setPreview((cursor) => [OverlayLine(center, cursor)]);
    final axisEnd = await context.resolvePoint(
      'axisEnd',
      'ELLIPSE  Specify endpoint of axis:',
      basePoint: center,
    );

    context.input
      ..setMarkers([center, axisEnd])
      ..setPreview((cursor) {
        final ellipse = Construct.ellipse(
          center: center,
          axisEnd: axisEnd,
          otherRadius: center.distanceTo(cursor),
        );
        if (ellipse == null) return [OverlayLine(center, axisEnd)];
        return _ellipseOverlay(ellipse);
      });
    final otherRadius =
        context.args.number('otherRadius') ??
        await context.input.distance(
          'ELLIPSE  Specify distance to other axis:',
          basePoint: center,
        );
    context.input
      ..setPreview(null)
      ..setMarkers(const []);

    final ellipse = Construct.ellipse(
      center: center,
      axisEnd: axisEnd,
      otherRadius: otherRadius,
      props: EntityProps(layer: context.document.currentLayer),
    );
    if (ellipse == null) {
      return const CommandResult.failed(
        'The ellipse needs a positive axis length.',
      );
    }
    return commitDraw(context, 'Ellipse', [ellipse]);
  }
}

List<OverlayShape> _ellipseOverlay(EllipseEntity ellipse) {
  final majorLength = ellipse.majorAxis.length;
  final points = Flatten.ellipse(
    center: ellipse.center,
    major: ellipse.majorAxis,
    ratio: ellipse.ratio,
    startParam: 0,
    endParam: math.pi * 2,
    tolerance: math.max(majorLength * 0.02, 0.05),
  );
  return [
    OverlayPolyline([
      for (var i = 0; i + 1 < points.length; i += 2)
        Vec2(points[i], points[i + 1]),
    ], closed: true),
    OverlayLine(
      ellipse.center,
      ellipse.center + ellipse.majorAxis,
      dashed: true,
    ),
  ];
}
