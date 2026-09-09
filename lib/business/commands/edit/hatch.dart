import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditHatchCommand extends FanCadCommand {
  const EditHatchCommand();

  @override
  String get id => 'edit.hatch';
  @override
  String get title => 'Hatch Edit';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['hatchedit', 'he'];
  @override
  String get description =>
      'Changes the pattern, scale or angle of selected hatches. Omit a '
      'field to leave it. Angle is in degrees.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec(
      name: 'pattern',
      type: ParamType.text,
      description: 'Pattern name, or SOLID',
      required: false,
    ),
    ParamSpec(
      name: 'scale',
      type: ParamType.distance,
      description: 'Pattern scale',
      required: false,
    ),
    ParamSpec(
      name: 'angle',
      type: ParamType.angle,
      description: 'Pattern rotation in degrees',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'HATCHEDIT  Select hatch objects:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();

    final targets = <HatchEntity>[
      for (final id in ids)
        if (context.document.entity(id) case final HatchEntity hatch) hatch,
    ];
    if (targets.isEmpty) {
      return const CommandResult.failed('Select at least one hatch.');
    }

    final pattern = context.args.text('pattern')?.trim();
    final scale = context.args.number('scale');
    final angleDeg = context.args.number('angle');
    if (pattern == null && scale == null && angleDeg == null) {
      return const CommandResult.failed(
        'Supply a pattern, scale or angle to change.',
      );
    }
    if (scale != null && scale <= 0) {
      return const CommandResult.failed('Hatch scale must be positive.');
    }

    final committed = context.edit('Hatch Edit', (transaction) {
      for (final hatch in targets) {
        final name = pattern?.toUpperCase();
        final next = hatch.copyWith(
          patternName: name,
          solid: name == null ? null : name == 'SOLID',
          patternScale: scale,
          patternAngle: angleDeg == null ? null : angleDeg * math.pi / 180,
        );
        if (next.patternName == hatch.patternName &&
            next.solid == hatch.solid &&
            next.patternScale == hatch.patternScale &&
            next.patternAngle == hatch.patternAngle) {
          continue;
        }
        transaction.modify(next);
      }
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing changed; the hatch already matches or is locked.',
      );
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Edited ${committed.change.modified.length} hatch(es).',
      data: {'ids': committed.change.modified},
      transaction: committed,
    );
  }
}
