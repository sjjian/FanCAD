import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Modify';

class EditAlignCommand extends FanCadCommand {
  const EditAlignCommand();

  @override
  String get id => 'edit.align';
  @override
  String get title => 'Align';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['al', 'align'];
  @override
  String get description =>
      'Moves the selection so a source point lands on a destination '
      'point. A second pair rotates to match the two directions; an '
      'optional scale matches the two lengths.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec.point('source1', description: 'First source point'),
    ParamSpec.point('dest1', description: 'First destination point'),
    ParamSpec(
      name: 'source2',
      type: ParamType.point,
      required: false,
      description: 'Second source point',
    ),
    ParamSpec(
      name: 'dest2',
      type: ParamType.point,
      required: false,
      description: 'Second destination point',
    ),
    ParamSpec(
      name: 'scale',
      type: ParamType.boolean,
      required: false,
      defaultValue: false,
      description: 'Scale so the two segments end up the same length',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      context.commandPrompt(
        'ALIGN',
        context.l10n.prompt_select_objects_to_align,
      ),
    );
    if (ids.isEmpty) return const CommandResult.cancelled();

    final source1 = await context.resolvePoint(
      'source1',
      context.commandPrompt('ALIGN', context.l10n.prompt_specify_first_source),
    );
    installTransformPreview(
      context,
      ids,
      source1,
      (cursor) => Mat3.align(source1, cursor),
    );
    final dest1 = await context.resolvePoint(
      'dest1',
      context.commandPrompt('ALIGN', context.l10n.prompt_specify_first_dest),
      basePoint: source1,
    );
    context.input.setPreview(null);

    var source2 = context.args.point('source2');
    if (source2 == null && context.input.isInteractive) {
      source2 = await context.input.pointOrNull(
        context.commandPrompt(
          'ALIGN',
          context.l10n.prompt_specify_second_source_or_enter,
        ),
      );
    }

    Vec2? dest2 = context.args.point('dest2');
    if (source2 != null && dest2 == null) {
      installTransformPreview(
        context,
        ids,
        dest1,
        (cursor) => Mat3.align(source1, dest1, source2: source2, dest2: cursor),
        extra: (cursor) => [
          OverlayLine(source1, source2!),
          OverlayLine(dest1, cursor),
        ],
      );
      dest2 = await context.resolvePoint(
        'dest2',
        context.commandPrompt('ALIGN', context.l10n.prompt_specify_second_dest),
        basePoint: dest1,
      );
      context.input.setPreview(null);
    }

    var scale = context.args.boolean('scale') ?? false;
    if (source2 != null &&
        dest2 != null &&
        context.args.boolean('scale') == null &&
        context.input.isInteractive) {
      scale = await context.input.confirm(
        context.l10n.prompt_scale_objects_align,
      );
    }

    return applyEditTransform(
      context,
      'Align',
      ids,
      Mat3.align(source1, dest1, source2: source2, dest2: dest2, scale: scale),
      copy: false,
    );
  }
}
