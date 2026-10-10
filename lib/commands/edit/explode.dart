import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditExplodeCommand extends FanCadCommand {
  const EditExplodeCommand();

  @override
  String get id => 'edit.explode';
  @override
  String get title => 'Explode';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['x', 'explode'];
  @override
  String get description =>
      'Breaks polylines into their segments, block references into copies '
      'of their contents, and dimensions into the lines, arrows and text '
      'they draw.';
  @override
  List<ParamSpec> get params => const [ParamSpec.selection('ids')];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      context.commandPrompt(
        'EXPLODE',
        context.l10n.prompt_select_objects_to_explode,
      ),
    );
    if (ids.isEmpty) return const CommandResult.cancelled();

    final committed = context.edit('Explode', (transaction) {
      for (final id in ids) {
        final entity = context.document.entity(id);
        if (entity == null) continue;
        final pieces = entity.explode(context.document);
        if (pieces.isEmpty) continue;
        transaction
          ..addAll(pieces)
          ..erase(id);
      }
    });
    if (committed == null) {
      return const CommandResult.failed(
        'None of the selected objects can be exploded.',
      );
    }
    context.selection.replace(committed.change.added);
    return CommandResult(
      status: CommandStatus.ok,
      message:
          'Explode: ${committed.change.removed.length} object(s) became '
          '${committed.change.added.length}.',
      data: {'ids': committed.change.added},
      transaction: committed,
    );
  }
}
