import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Modify';

class EditMirrorCommand extends FanCadCommand {
  const EditMirrorCommand();

  @override
  String get id => 'edit.mirror';
  @override
  String get title => 'Mirror';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['mi', 'mirror'];
  @override
  String get description => 'Mirrors the selected objects across a line.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec.point('first', description: 'First point of the mirror line'),
    ParamSpec.point('second', description: 'Second point of the mirror line'),
    ParamSpec(
      name: 'keepOriginal',
      type: ParamType.boolean,
      description: 'Keep the source objects as well as the mirrored copies',
      required: false,
      defaultValue: true,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'MIRROR  Select objects to mirror:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final first = await context.resolvePoint(
      'first',
      'MIRROR  Specify first point of mirror line:',
    );

    final keep = context.args.boolean('keepOriginal') ?? true;
    installTransformPreview(
      context,
      ids,
      first,
      (cursor) => Mat3.mirror(first, cursor - first),
    );
    final second = await context.resolvePoint(
      'second',
      'MIRROR  Specify second point of mirror line:',
      basePoint: first,
    );
    context.input.setPreview(null);

    if (first.distanceTo(second) < 1e-12) {
      return const CommandResult.failed(
        'The two points of the mirror line coincide.',
      );
    }
    return applyEditTransform(
      context,
      'Mirror',
      ids,
      Mat3.mirror(first, second - first),
      copy: keep,
    );
  }
}
