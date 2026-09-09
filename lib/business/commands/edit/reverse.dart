import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditReverseCommand extends FanCadCommand {
  const EditReverseCommand();

  @override
  String get id => 'edit.reverse';
  @override
  String get title => 'Reverse';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['reverse', 'rev'];
  @override
  String get description =>
      'Reverses the direction of selected lines and polylines. The drawn '
      'shape stays the same; start and end swap, which matters for linetypes '
      'and for commands that follow a chain.';
  @override
  List<ParamSpec> get params => const [ParamSpec.selection('ids')];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'REVERSE  Select lines or polylines:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();

    final reversed = <CadEntity>[];
    for (final id in ids) {
      final entity = context.document.entity(id);
      if (entity == null) continue;
      final next = Construct.reverse(entity);
      if (next != null) reversed.add(next);
    }
    if (reversed.isEmpty) {
      return const CommandResult.failed(
        'Reverse currently supports lines and polylines.',
      );
    }

    final committed = context.edit('Reverse', (transaction) {
      for (final entity in reversed) {
        transaction.modify(entity);
      }
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing was reversed; the objects may be on a locked layer.',
      );
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Reversed ${reversed.length} object(s).',
      transaction: committed,
    );
  }
}
