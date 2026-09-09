import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Modify';

class EditPolarArrayCommand extends FanCadCommand {
  const EditPolarArrayCommand();

  @override
  String get id => 'edit.polarArray';
  @override
  String get title => 'Polar Array';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['arraypolar', 'polararray'];
  @override
  String get description =>
      'Creates copies of the selected objects rotated about a centre. A fill '
      'of 360° spaces items around the full circle; a smaller fill spaces '
      'them from the original through that angle, inclusive.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec.point('center', description: 'Centre of the array'),
    ParamSpec(
      name: 'count',
      type: ParamType.integer,
      description: 'Number of items, including the original',
      min: 2,
    ),
    ParamSpec(
      name: 'fillAngle',
      type: ParamType.angle,
      description: 'Angle to fill, in degrees, default 360',
      required: false,
      defaultValue: 360,
    ),
    ParamSpec(
      name: 'rotateItems',
      type: ParamType.boolean,
      description: 'Rotate each copy as it is placed',
      required: false,
      defaultValue: true,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'ARRAY  Select objects to array:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();

    final count =
        context.args.integer('count') ??
        await context.input.integer(
          'ARRAY  Enter number of items:',
          defaultValue: 6,
        );
    if (count < 2) {
      return const CommandResult.failed(
        'A polar array needs at least two items.',
      );
    }
    final fillDegrees =
        context.args.number('fillAngle') ??
        (context.input.isInteractive
            ? await context.input.number(
                'ARRAY  Enter the angle to fill:',
                defaultValue: 360,
              )
            : 360);
    if (fillDegrees.abs() < 1e-9) {
      return const CommandResult.failed('The fill angle cannot be zero.');
    }
    final rotateItems = context.args.boolean('rotateItems') ?? true;

    // A full circle uses count equal intervals so the last copy does not
    // land on the original; a partial fill includes both ends, so one
    // fewer interval.
    final fullCircle = (fillDegrees.abs() - 360).abs() < 1e-6;
    final step =
        (fillDegrees * math.pi / 180) / (fullCircle ? count : count - 1);

    var box = const Bounds2.empty();
    for (final id in ids) {
      final entity = context.document.entity(id);
      if (entity != null) {
        box = box.union(context.document.boundsOfEntity(entity));
      }
    }
    final centroid = box.isEmpty ? const Vec2.zero() : box.center;

    Mat3 matrixFor(double angle, Vec2 center) {
      if (rotateItems) return Mat3.rotationAbout(angle, center);
      final moved = centroid.rotated(angle, center);
      return Mat3.translation(moved.x - centroid.x, moved.y - centroid.y);
    }

    context.input.setPreview((cursor) {
      final radius = cursor.distanceTo(centroid);
      return [
        OverlayArc(center: cursor, radius: radius <= 0 ? 1 : radius),
        if (ids.length <= 20)
          for (final id in ids)
            if (context.document.entity(id) case final entity?)
              ...editOutline(
                context.document,
                entity.transformed(matrixFor(step, cursor)),
              ),
      ];
    });
    final center = await context.resolvePoint(
      'center',
      'ARRAY  Specify center point:',
    );
    context.input.setPreview(null);

    final copies = count - 1;
    if (copies * ids.length > 5000) {
      final proceed = await context.services.requestApproval(
        'Create a large array?',
        'This would add ${copies * ids.length} objects to the drawing.',
      );
      if (!proceed) return const CommandResult.cancelled();
    }

    final committed = context.edit('Polar Array', (transaction) {
      for (var i = 1; i < count; i++) {
        transaction.duplicate(ids, matrixFor(step * i, center));
      }
    });
    if (committed == null) {
      return const CommandResult.failed('Nothing was arrayed.');
    }
    context.selection.replace(committed.change.added);
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Polar array: ${committed.change.added.length} copies created.',
      data: {'ids': committed.change.added},
      transaction: committed,
    );
  }
}
