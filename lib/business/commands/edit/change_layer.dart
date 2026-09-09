import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditChangeLayerCommand extends FanCadCommand {
  const EditChangeLayerCommand();

  @override
  String get id => 'edit.changeLayer';
  @override
  String get title => 'Change Layer';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['chlayer'];
  @override
  String get description =>
      'Moves the selected objects onto a different layer.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec(
      name: 'layer',
      type: ParamType.layer,
      description: 'Target layer name',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'Select objects to move to another layer:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final layer = await context.resolveText('layer', 'Enter layer name:');
    if (context.document.layer(layer) == null) {
      return CommandResult.failed('There is no layer named "$layer".');
    }
    final committed = context.edit('Change Layer', (transaction) {
      transaction.setLayerOf(ids, layer);
    });
    if (committed == null) {
      return const CommandResult.failed('Nothing changed.');
    }
    return CommandResult(
      status: CommandStatus.ok,
      message:
          'Moved ${committed.change.modified.length} object(s) to '
          '"$layer".',
      transaction: committed,
    );
  }
}
