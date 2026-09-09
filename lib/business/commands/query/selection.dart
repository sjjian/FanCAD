import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'describe.dart';

const _category = 'Inquiry';

class QuerySelectionCommand extends FanCadCommand {
  const QuerySelectionCommand();

  @override
  String get id => 'query.selection';
  @override
  String get title => 'Query Selection';
  @override
  String get category => _category;
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  String get description =>
      'Returns the current selection as structured records (id, kind, '
      'layer, bounds, short geometry). Use this instead of guessing ids. '
      'An empty selection is a successful empty list, not a prompt.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = context.selection.ids.toList();
    final records = <Map<String, Object?>>[];
    for (final id in ids.take(200)) {
      final entity = context.document.entity(id);
      if (entity == null) continue;
      records.add(describeEntity(context.document, entity));
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: ids.isEmpty
          ? 'Nothing is selected.'
          : ids.length == 1
          ? '1 object selected.'
          : '${ids.length} objects selected.',
      data: {
        'count': ids.length,
        'returned': records.length,
        'entities': records,
      },
    );
  }
}
