import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawDimRadiusCommand extends FanCadCommand {
  const DrawDimRadiusCommand();

  @override
  String get id => 'draw.dimRadius';
  @override
  String get title => 'Radius Dimension';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['dimradius', 'dimrad'];
  @override
  String? get icon => 'dimension';
  @override
  String get description =>
      'Places a radius dimension on a circle or arc. The second pick is '
      'the arrow tip; the text is the radius, prefixed with R.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'target',
      type: ParamType.entity,
      description: 'Circle or arc to dimension',
      required: false,
    ),
    ParamSpec.point('dimLine', description: 'Arrow tip and text location'),
    dimStyleParam,
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final supplied = context.args.integer('target');
    final int targetId;
    if (supplied != null) {
      targetId = supplied;
    } else {
      context.selection.clear();
      final picked = await context.input.selection(
        'DIMRADIUS  Select arc or circle:',
        useExistingSelection: false,
        single: true,
      );
      if (picked.isEmpty) return const CommandResult.cancelled();
      targetId = picked.first;
    }
    final target = context.document.entity(targetId);
    if (target == null || (target is! CircleEntity && target is! ArcEntity)) {
      return const CommandResult.failed(
        'Radius dimension needs a circle or an arc.',
      );
    }
    final center = target is CircleEntity
        ? target.center
        : (target as ArcEntity).center;
    context.input.setPreview((cursor) => [OverlayLine(center, cursor)]);
    final dimLine = await context.resolvePoint(
      'dimLine',
      'DIMRADIUS  Specify dimension line location:',
      basePoint: center,
    );
    context.input.setPreview(null);
    final entity = Construct.radiusDimension(
      target,
      dimLine,
      props: EntityProps(layer: context.document.currentLayer),
      styleName: dimStyleName(context),
    );
    if (entity == null) {
      return const CommandResult.failed(
        'The circle or arc has no radius to measure.',
      );
    }
    return commitDraw(context, 'Radius Dimension', [entity]);
  }
}

class DrawDimDiameterCommand extends FanCadCommand {
  const DrawDimDiameterCommand();

  @override
  String get id => 'draw.dimDiameter';
  @override
  String get title => 'Diameter Dimension';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['dimdiameter', 'dimdia'];
  @override
  String? get icon => 'dimension';
  @override
  String get description =>
      'Places a diameter dimension on a circle or arc. The second pick is '
      'the arrow tip; the text is the diameter, prefixed with Ø.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'target',
      type: ParamType.entity,
      description: 'Circle or arc to dimension',
      required: false,
    ),
    ParamSpec.point('dimLine', description: 'Arrow tip and text location'),
    dimStyleParam,
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final supplied = context.args.integer('target');
    final int targetId;
    if (supplied != null) {
      targetId = supplied;
    } else {
      context.selection.clear();
      final picked = await context.input.selection(
        'DIMDIAMETER  Select arc or circle:',
        useExistingSelection: false,
        single: true,
      );
      if (picked.isEmpty) return const CommandResult.cancelled();
      targetId = picked.first;
    }
    final target = context.document.entity(targetId);
    if (target == null || (target is! CircleEntity && target is! ArcEntity)) {
      return const CommandResult.failed(
        'Diameter dimension needs a circle or an arc.',
      );
    }
    final center = target is CircleEntity
        ? target.center
        : (target as ArcEntity).center;
    context.input.setPreview((cursor) {
      final dir = cursor - center;
      if (dir.length < 1e-9) return const <OverlayShape>[];
      final far = center - dir.normalized() * dir.length;
      return [OverlayLine(far, cursor)];
    });
    final dimLine = await context.resolvePoint(
      'dimLine',
      'DIMDIAMETER  Specify dimension line location:',
      basePoint: center,
    );
    context.input.setPreview(null);
    final entity = Construct.diameterDimension(
      target,
      dimLine,
      props: EntityProps(layer: context.document.currentLayer),
      styleName: dimStyleName(context),
    );
    if (entity == null) {
      return const CommandResult.failed(
        'The circle or arc has no diameter to measure.',
      );
    }
    return commitDraw(context, 'Diameter Dimension', [entity]);
  }
}
