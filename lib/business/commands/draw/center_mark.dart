import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawCenterMarkCommand extends FanCadCommand {
  const DrawCenterMarkCommand();

  @override
  String get id => 'draw.centerMark';
  @override
  String get title => 'Center Mark';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['dimcenter', 'centermark'];
  @override
  String? get icon => 'dimension';
  @override
  String get description =>
      'Draws a centre mark on selected circles or arcs. A short cross '
      'sits on the centre; optional extensions continue past the '
      'circumference, the usual shop-drawing DIMCENTER.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids', description: 'Circles or arcs to mark'),
    ParamSpec(
      name: 'size',
      type: ParamType.distance,
      description: 'Half-length of the centre cross',
      required: false,
      defaultValue: 2.5,
    ),
    ParamSpec(
      name: 'extend',
      type: ParamType.boolean,
      description: 'Draw extension lines past the circumference',
      required: false,
      defaultValue: true,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'DIMCENTER  Select circles or arcs:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final size = context.args.number('size') ?? 2.5;
    final extend = context.args.boolean('extend') ?? true;
    final created = <CadEntity>[];
    for (final id in ids) {
      final entity = context.document.entity(id);
      if (entity == null) continue;
      final marks = Construct.centerMark(
        entity,
        props: EntityProps(layer: context.document.currentLayer),
        size: size,
        extend: extend,
      );
      if (marks != null) created.addAll(marks);
    }
    if (created.isEmpty) {
      return const CommandResult.failed(
        'Center mark needs a circle or an arc.',
      );
    }
    return commitDraw(context, 'Center Mark', created);
  }
}
