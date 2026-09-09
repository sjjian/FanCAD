import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Modify';

class EditRotateCommand extends FanCadCommand {
  const EditRotateCommand();

  @override
  String get id => 'edit.rotate';
  @override
  String get title => 'Rotate';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['ro', 'rotate'];
  @override
  String? get icon => 'rotate';
  @override
  String get description =>
      'Rotates the selected objects about a base point. The angle is in '
      'degrees, counter-clockwise.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec.point('base', description: 'Centre of rotation'),
    ParamSpec(
      name: 'angle',
      type: ParamType.angle,
      description: 'Rotation in degrees, counter-clockwise',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'ROTATE  Select objects to rotate:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final base = await context.resolvePoint(
      'base',
      'ROTATE  Specify base point:',
    );

    final supplied = context.args.number('angle');
    double angle;
    if (supplied != null) {
      angle = supplied * math.pi / 180;
    } else {
      installTransformPreview(
        context,
        ids,
        base,
        (cursor) => Mat3.rotationAbout((cursor - base).angle, base),
        extra: (cursor) => [
          OverlayArc(center: base, radius: base.distanceTo(cursor)),
        ],
      );
      angle = await context.input.angle(
        'ROTATE  Specify rotation angle:',
        basePoint: base,
      );
      context.input.setPreview(null);
    }
    return applyEditTransform(
      context,
      'Rotate',
      ids,
      Mat3.rotationAbout(angle, base),
      copy: false,
    );
  }
}
