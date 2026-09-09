import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawDonutCommand extends FanCadCommand {
  const DrawDonutCommand();

  @override
  String get id => 'draw.donut';
  @override
  String get title => 'Donut';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['do', 'donut'];
  @override
  String get description =>
      'Draws a filled ring from an inside and outside diameter. A zero '
      'inside diameter is a filled disk. The result is a closed wide '
      'polyline, which is how DWG stores a donut.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'inside',
      type: ParamType.distance,
      description: 'Inside diameter; 0 for a filled disk',
      min: 0,
    ),
    ParamSpec(
      name: 'outside',
      type: ParamType.distance,
      description: 'Outside diameter',
      min: 0,
    ),
    ParamSpec.point('center', description: 'Centre of the donut'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final inside =
        context.args.number('inside') ??
        await context.input.number(
          'DONUT  Specify inside diameter:',
          defaultValue: 0,
        );
    final outside =
        context.args.number('outside') ??
        await context.input.number('DONUT  Specify outside diameter:');
    if (inside < 0 || outside < 0) {
      return const CommandResult.failed('Diameters cannot be negative.');
    }
    final innerR = math.min(inside, outside) / 2;
    final outerR = math.max(inside, outside) / 2;
    if (outerR <= 0) {
      return const CommandResult.failed(
        'The outside diameter must be positive.',
      );
    }

    final props = EntityProps(layer: context.document.currentLayer);
    final created = <CadEntity>[];

    Future<void> place(Vec2 center) async {
      final donut = Construct.donut(
        center: center,
        innerRadius: innerR,
        outerRadius: outerR,
        props: props,
      );
      if (donut != null) created.add(donut);
    }

    final supplied = context.args.point('center');
    if (supplied != null) {
      await place(supplied);
    } else {
      while (true) {
        context.input.setPreview((cursor) {
          return [
            OverlayArc(center: cursor, radius: outerR),
            if (innerR > 0) OverlayArc(center: cursor, radius: innerR),
          ];
        });
        final next = await context.input.pointOrNull(
          'DONUT  Specify center of donut:',
        );
        if (next == null) break;
        await place(next);
        if (!context.input.isInteractive) break;
      }
      context.input.setPreview(null);
    }

    if (created.isEmpty) return const CommandResult.cancelled();
    return commitDraw(context, 'Donut', created);
  }
}
