import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Modify';

class EditScaleCommand extends FanCadCommand {
  const EditScaleCommand();

  @override
  String get id => 'edit.scale';
  @override
  String get title => 'Scale';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['sc', 'scale'];
  @override
  String? get icon => 'scale';
  @override
  String get description =>
      'Scales the selected objects uniformly about a base point.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec.point('base', description: 'Fixed point of the scaling'),
    ParamSpec(
      name: 'factor',
      type: ParamType.number,
      description: 'Scale factor; 2 doubles the size, 0.5 halves it',
      min: 1e-9,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'SCALE  Select objects to scale:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final base = await context.resolvePoint(
      'base',
      'SCALE  Specify base point:',
    );

    var factor = context.args.number('factor');
    if (factor == null) {
      // Picking a distance is measured against one drawing unit, so dragging
      // two units from the base point doubles the selection.
      installTransformPreview(context, ids, base, (cursor) {
        final scale = base.distanceTo(cursor);
        return scale <= 0
            ? const Mat3.identity()
            : Mat3.scalingAbout(scale, scale, base);
      });
      factor = await context.input.number(
        'SCALE  Specify scale factor (or pick a distance):',
        defaultValue: 1,
      );
      context.input.setPreview(null);
    }
    if (factor <= 0) {
      return const CommandResult.failed('The scale factor must be positive.');
    }
    return applyEditTransform(
      context,
      'Scale',
      ids,
      Mat3.scalingAbout(factor, factor, base),
      copy: false,
    );
  }
}
