import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Modify';

class EditOffsetCommand extends FanCadCommand {
  const EditOffsetCommand();

  @override
  String get id => 'edit.offset';
  @override
  String get title => 'Offset';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['o', 'offset'];
  @override
  String? get icon => 'offset';
  @override
  String get description =>
      'Creates parallel copies of lines, arcs, circles and polylines at a '
      'fixed distance.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'distance',
      type: ParamType.distance,
      description: 'Offset distance',
      min: 1e-9,
    ),
    ParamSpec.selection('ids'),
    ParamSpec.point(
      'side',
      description: 'A point on the side to offset towards',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final distance =
        context.args.number('distance') ??
        await context.input.number('OFFSET  Specify offset distance:');
    if (distance <= 0) {
      return const CommandResult.failed('The distance must be positive.');
    }
    final ids = await context.resolveSelection(
      'ids',
      'OFFSET  Select objects to offset:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();

    context.input.setPreview((cursor) {
      final shapes = <OverlayShape>[];
      for (final id in ids) {
        final entity = context.document.entity(id);
        if (entity == null) continue;
        final offset = Construct.offset(entity, distance, cursor);
        if (offset == null) continue;
        shapes.addAll(editOutline(context.document, offset));
      }
      return shapes;
    });
    final side = await context.resolvePoint(
      'side',
      'OFFSET  Specify a point on the side to offset:',
    );
    context.input.setPreview(null);

    final created = <CadEntity>[];
    final skipped = <String>[];
    for (final id in ids) {
      final entity = context.document.entity(id);
      if (entity == null) continue;
      final offset = Construct.offset(entity, distance, side);
      if (offset == null) {
        skipped.add(entity.kind.name);
        continue;
      }
      created.add(offset);
    }
    if (created.isEmpty) {
      return CommandResult.failed(
        'Offset is not supported for ${skipped.toSet().join(', ')}.',
      );
    }
    final committed = context.edit('Offset', (transaction) {
      transaction.addAll(created);
    });
    if (committed == null) {
      return const CommandResult.failed('Nothing was offset.');
    }
    context.selection.replace(committed.change.added);
    return CommandResult(
      status: CommandStatus.ok,
      message: skipped.isEmpty
          ? 'Offset ${committed.change.added.length} object(s).'
          : 'Offset ${committed.change.added.length} object(s); '
                '${skipped.length} unsupported type(s) were skipped.',
      data: {'ids': committed.change.added},
      transaction: committed,
    );
  }
}
