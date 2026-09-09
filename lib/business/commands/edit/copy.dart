import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Modify';

class EditCopyCommand extends FanCadCommand {
  const EditCopyCommand();

  @override
  String get id => 'edit.copy';
  @override
  String get title => 'Copy';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['co', 'cp', 'copy'];
  @override
  String? get icon => 'copy';
  @override
  String get description =>
      'Copies the selected objects to one or more locations. Each second '
      'point is another copy from the same base; Escape finishes.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec.point('from', description: 'Base point'),
    ParamSpec.point('to', description: 'First destination of the base point'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection('ids', 'COPY  Select objects:');
    if (ids.isEmpty) return const CommandResult.cancelled();
    final from = await context.resolvePoint(
      'from',
      'COPY  Specify base point:',
    );
    installTransformPreview(
      context,
      ids,
      from,
      (cursor) => Mat3.translation(cursor.x - from.x, cursor.y - from.y),
    );
    final first = await context.resolvePoint(
      'to',
      'COPY  Specify second point:',
      basePoint: from,
    );
    final destinations = <Vec2>[
      first,
      ...editPointList(context.args['destinations']),
    ];
    if (context.input.isInteractive && !context.args.has('destinations')) {
      while (true) {
        installTransformPreview(
          context,
          ids,
          from,
          (cursor) => Mat3.translation(cursor.x - from.x, cursor.y - from.y),
        );
        final next = await context.input.pointOrNull(
          'COPY  Specify second point (Escape to finish):',
          basePoint: from,
        );
        if (next == null) break;
        destinations.add(next);
      }
    }
    context.input.setPreview(null);

    final matrices = [
      for (final dest in destinations)
        Mat3.translation(dest.x - from.x, dest.y - from.y),
    ].where((matrix) => !matrix.isIdentity).toList();
    if (matrices.isEmpty) {
      return const CommandResult.cancelled('The transform is a no-op.');
    }

    final committed = context.edit('Copy', (transaction) {
      for (final matrix in matrices) {
        transaction.duplicate(ids, matrix);
      }
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Copy affected nothing; the objects may be on a locked layer.',
      );
    }
    context.selection.replace(committed.change.added);
    return CommandResult(
      status: CommandStatus.ok,
      message: matrices.length == 1
          ? 'Copy: ${ids.length} object(s).'
          : 'Copy: ${ids.length} object(s) to ${matrices.length} locations.',
      data: {'ids': committed.change.added},
      transaction: committed,
    );
  }
}
