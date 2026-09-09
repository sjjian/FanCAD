import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawDimLinearCommand extends FanCadCommand {
  const DrawDimLinearCommand();

  @override
  String get id => 'draw.dimLinear';
  @override
  String get title => 'Linear Dimension';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['dli', 'dimlinear', 'dim'];
  @override
  String? get icon => 'dimension';
  @override
  String get description =>
      'Places a horizontal or vertical dimension. The dimension-line pick '
      'chooses the axis: above or below the origins measures width; left '
      'or right measures height. A line can stand in for the two origins.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'target',
      type: ParamType.entity,
      description: 'Line whose endpoints become the two origins',
      required: false,
    ),
    ParamSpec(
      name: 'first',
      type: ParamType.point,
      description: 'First extension-line origin',
      required: false,
    ),
    ParamSpec(
      name: 'second',
      type: ParamType.point,
      description: 'Second extension-line origin',
      required: false,
    ),
    ParamSpec.point('dimLine', description: 'A point on the dimension line'),
    dimStyleParam,
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final origins = await _resolveDimOrigins(
      context,
      command: 'DIMLINEAR',
      needs: 'a line',
    );
    if (origins.error != null) {
      return CommandResult.failed(origins.error!);
    }
    final first = origins.first;
    final second = origins.second;
    final sourceIds = origins.sourceId == null
        ? const <int>[]
        : [origins.sourceId!];
    context.input.setPreview(
      (cursor) => dimLinearOverlay(first, second, cursor),
    );
    final dimLine = await context.resolvePoint(
      'dimLine',
      'DIMLINEAR  Specify dimension line location:',
      basePoint: first.lerp(second, 0.5),
    );
    context.input.setPreview(null);
    final entity = Construct.linearDimension(
      first,
      second,
      dimLine,
      props: EntityProps(layer: context.document.currentLayer),
      styleName: dimStyleName(context),
      sourceIds: sourceIds,
    );
    if (entity == null) {
      return const CommandResult.failed(
        'The measurement is zero. Place the dimension line so it shows a '
        'horizontal or vertical length.',
      );
    }
    return commitDraw(context, 'Linear Dimension', [entity]);
  }
}

class DrawDimAlignedCommand extends FanCadCommand {
  const DrawDimAlignedCommand();

  @override
  String get id => 'draw.dimAligned';
  @override
  String get title => 'Aligned Dimension';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['dal', 'dimaligned'];
  @override
  String? get icon => 'dimension';
  @override
  String get description =>
      'Places a dimension parallel to the two origins. The text is the '
      'true distance, not the horizontal or vertical component. A line '
      'can stand in for the two origins.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'target',
      type: ParamType.entity,
      description: 'Line whose endpoints become the two origins',
      required: false,
    ),
    ParamSpec(
      name: 'first',
      type: ParamType.point,
      description: 'First extension-line origin',
      required: false,
    ),
    ParamSpec(
      name: 'second',
      type: ParamType.point,
      description: 'Second extension-line origin',
      required: false,
    ),
    ParamSpec.point('dimLine', description: 'A point on the dimension line'),
    dimStyleParam,
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final origins = await _resolveDimOrigins(
      context,
      command: 'DIMALIGNED',
      needs: 'a line',
    );
    if (origins.error != null) {
      return CommandResult.failed(origins.error!);
    }
    final first = origins.first;
    final second = origins.second;
    final sourceIds = origins.sourceId == null
        ? const <int>[]
        : [origins.sourceId!];
    context.input.setPreview(
      (cursor) => dimAlignedOverlay(first, second, cursor),
    );
    final dimLine = await context.resolvePoint(
      'dimLine',
      'DIMALIGNED  Specify dimension line location:',
      basePoint: first.lerp(second, 0.5),
    );
    context.input.setPreview(null);
    final entity = Construct.alignedDimension(
      first,
      second,
      dimLine,
      props: EntityProps(layer: context.document.currentLayer),
      styleName: dimStyleName(context),
      sourceIds: sourceIds,
    );
    if (entity == null) {
      return const CommandResult.failed('The two origins are the same point.');
    }
    return commitDraw(context, 'Aligned Dimension', [entity]);
  }
}

/// Two extension-line origins: a line's endpoints, or two picked points.
Future<({Vec2 first, Vec2 second, int? sourceId, String? error})>
_resolveDimOrigins(
  CommandContext context, {
  required String command,
  required String needs,
}) async {
  final targetId = context.args.integer('target');
  if (targetId != null) {
    final target = context.document.entity(targetId);
    if (target is! LineEntity) {
      return (
        first: const Vec2.zero(),
        second: const Vec2.zero(),
        sourceId: null,
        error: '$command from an object needs $needs.',
      );
    }
    return (
      first: target.start,
      second: target.end,
      sourceId: target.id,
      error: null,
    );
  }
  final first = await context.resolvePoint(
    'first',
    '$command  Specify first extension line origin:',
  );
  final second = await context.resolvePoint(
    'second',
    '$command  Specify second extension line origin:',
    basePoint: first,
  );
  return (first: first, second: second, sourceId: null, error: null);
}
