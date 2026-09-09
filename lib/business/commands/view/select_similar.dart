import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _select = 'Select';

class SelectSimilarCommand extends FanCadCommand {
  const SelectSimilarCommand();

  @override
  String get id => 'select.similar';
  @override
  String get title => 'Select Similar';
  @override
  String get category => _select;
  @override
  String get description =>
      'Extends the selection to every object of the same type and layer.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final seeds = context.selection.ids;
    if (seeds.isEmpty) {
      return const CommandResult.failed('Select one object first.');
    }
    final signatures = <String>{};
    for (final id in seeds) {
      final entity = context.document.entity(id);
      if (entity != null) {
        signatures.add('${entity.kind.name}|${entity.props.layer}');
      }
    }
    final ids = [
      for (final entity in context.document.activeEntities)
        if (signatures.contains('${entity.kind.name}|${entity.props.layer}') &&
            context.document.isSelectable(entity))
          entity.id,
    ];
    context.selection.replace(ids);
    return CommandResult.ok(message: '${ids.length} object(s) selected.');
  }
}
