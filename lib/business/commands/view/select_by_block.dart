import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _select = 'Select';

class SelectByBlockCommand extends FanCadCommand {
  const SelectByBlockCommand();

  @override
  String get id => 'select.byBlock';
  @override
  String get title => 'Select by Block';
  @override
  String get category => _select;
  @override
  List<String> get aliases => const ['selblock', 'selectblock'];
  @override
  String get description =>
      'Selects every insert of a named block in the current space. The '
      'name is case-insensitive, the same way INSERT and RENAME look it up.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'name', type: ParamType.text, description: 'Block name'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final requested = (await context.resolveText(
      'name',
      'SELECT  Enter block name:',
    )).trim();
    if (requested.isEmpty) {
      return const CommandResult.failed('SELECT needs a block name.');
    }
    final key = requested.toUpperCase();
    BlockRecord? block;
    for (final candidate in context.document.insertableBlocks) {
      if (candidate.name.toUpperCase() == key) {
        block = candidate;
        break;
      }
    }
    if (block == null) {
      return CommandResult.failed(
        'There is no insertable block named "$requested".',
      );
    }
    final ids = [
      for (final entity in context.document.activeEntities)
        if (entity is InsertEntity &&
            entity.blockName.toUpperCase() == key &&
            context.document.isSelectable(entity))
          entity.id,
    ];
    context.selection.replace(ids);
    return CommandResult.ok(
      message: '${ids.length} insert(s) of "${block.name}" selected.',
    );
  }
}
