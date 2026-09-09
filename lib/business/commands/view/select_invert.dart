import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _select = 'Select';

class SelectInvertCommand extends FanCadCommand {
  const SelectInvertCommand();

  @override
  String get id => 'select.invert';
  @override
  String get title => 'Invert Selection';
  @override
  String get category => _select;
  @override
  String get description =>
      'Selects everything that is not currently selected.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final current = context.selection.ids.toSet();
    final ids = [
      for (final entity in context.document.activeEntities)
        if (!current.contains(entity.id) &&
            context.document.isSelectable(entity))
          entity.id,
    ];
    context.selection.replace(ids);
    return CommandResult.ok(message: '${ids.length} object(s) selected.');
  }
}
