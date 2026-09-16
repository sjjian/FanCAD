import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditChangeColorCommand extends FanCadCommand {
  const EditChangeColorCommand();

  @override
  String get id => 'edit.changeColor';
  @override
  String get title => 'Change Colour';
  @override
  String get category => _category;
  @override
  String get description =>
      'Sets the colour of the selected objects. Accepts an AutoCAD Color '
      'Index (1-255), a #rrggbb value, or ByLayer.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec(
      name: 'color',
      type: ParamType.text,
      description: 'ACI index, #rrggbb, ByLayer or ByBlock',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      context.l10n.prompt_select_objects_recolour,
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final raw = await context.resolveText(
      'color',
      context.l10n.prompt_enter_colour,
    );
    final color = cadColorFromJson(raw);
    final committed = context.edit('Change Colour', (transaction) {
      transaction.setColorOf(ids, color);
    });
    if (committed == null) {
      return const CommandResult.failed('Nothing changed.');
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Recoloured ${committed.change.modified.length} object(s).',
      transaction: committed,
    );
  }
}
