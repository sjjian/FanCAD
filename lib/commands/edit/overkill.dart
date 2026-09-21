import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditOverkillCommand extends FanCadCommand {
  const EditOverkillCommand();

  @override
  String get id => 'edit.overkill';
  @override
  String get title => 'Overkill';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['overkill'];
  @override
  CommandRisk get risk => CommandRisk.destructive;
  @override
  AiExposure get aiExposure => AiExposure.approvalRequired;
  @override
  String get description =>
      'Deletes exact geometric duplicates and folds overlapping or abutting '
      'collinear lines into one stroke. The first copy is kept and '
      'stretched to the union. Omitted ids means the whole current space, '
      'so a leftover selection cannot hide the rest of the duplicates.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'ids',
      type: ParamType.selection,
      required: false,
      description: 'Objects to inspect; omitted uses the current space',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final provided = context.args.ids('ids');
    final ids = <int>[
      if (provided != null && provided.isNotEmpty)
        ...provided
      else
        for (final entity in context.document.activeEntities)
          if (context.document.isSelectable(entity)) entity.id,
    ];
    if (ids.isEmpty) return const CommandResult.cancelled();

    final plan = Construct.overkill([
      for (final id in ids) ?context.document.entity(id),
    ]);
    if (plan.isEmpty) {
      return const CommandResult.ok(message: 'No duplicate geometry.');
    }

    final committed = context.edit('Overkill', (transaction) {
      for (final entity in plan.replace) {
        transaction.modify(entity);
      }
      transaction.eraseAll(plan.erase);
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing was deleted; the duplicates may be on a locked layer.',
      );
    }
    context.selection.removeAll(committed.change.removed);
    final erased = committed.change.removed.length;
    final merged = plan.replace.length;
    return CommandResult(
      status: CommandStatus.ok,
      message: merged == 0
          ? 'Deleted $erased duplicate object(s).'
          : 'Merged $merged overlapping line(s); deleted $erased.',
      data: {
        'erased': committed.change.removed,
        'replaced': [for (final entity in plan.replace) entity.id],
      },
      transaction: committed,
    );
  }
}
