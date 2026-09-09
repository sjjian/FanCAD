import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditChangeLineweightCommand extends FanCadCommand {
  const EditChangeLineweightCommand();

  @override
  String get id => 'edit.changeLineweight';
  @override
  String get title => 'Change Lineweight';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['lw', 'lweight', 'lineweight'];
  @override
  String get description =>
      'Sets the lineweight of the selected objects. Accepts a millimetre '
      'value (0.25), hundredths (25), ByLayer, ByBlock, Default or '
      'hairline.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec(
      name: 'weight',
      type: ParamType.text,
      description: 'Millimetres, hundredths, ByLayer, ByBlock or hairline',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'LWEIGHT  Select objects:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final raw = await context.resolveText(
      'weight',
      'LWEIGHT  Enter weight (0.25 mm, 25, ByLayer):',
    );
    final weight = LineWeight.tryParse(raw);
    if (weight == null) {
      return CommandResult.failed(
        '"$raw" is not a lineweight. Use 0.25, 25, ByLayer, ByBlock, '
        'Default or hairline.',
      );
    }

    final committed = context.edit('Change Lineweight', (transaction) {
      transaction.setLineWeightOf(ids, weight);
    });
    if (committed == null) {
      return const CommandResult.failed('Nothing changed.');
    }
    return CommandResult(
      status: CommandStatus.ok,
      message:
          'Set lineweight on ${committed.change.modified.length} object(s).',
      transaction: committed,
    );
  }
}
