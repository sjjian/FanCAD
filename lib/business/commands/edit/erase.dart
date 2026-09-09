import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditEraseCommand extends FanCadCommand {
  const EditEraseCommand();

  @override
  String get id => 'edit.erase';
  @override
  String get title => 'Erase';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['e', 'erase', 'delete'];
  @override
  String? get icon => 'erase';
  @override
  CommandRisk get risk => CommandRisk.destructive;
  @override
  AiExposure get aiExposure => AiExposure.approvalRequired;
  @override
  String get description => 'Deletes the selected objects.';
  @override
  List<ParamSpec> get params => const [ParamSpec.selection('ids')];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'ERASE  Select objects to erase:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final committed = context.edit('Erase', (transaction) {
      transaction.eraseAll(ids);
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing was erased; the objects may be on a locked layer.',
      );
    }
    context.selection.clear();
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Erased ${committed.change.removed.length} object(s).',
      data: {'erased': committed.change.removed},
      transaction: committed,
    );
  }
}
