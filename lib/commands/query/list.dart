import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'describe.dart';

const _category = 'Inquiry';

class QueryListCommand extends FanCadCommand {
  const QueryListCommand();

  @override
  String get id => 'query.list';
  @override
  String get title => 'List';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['li', 'list'];
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  String get description =>
      'Reports the full properties of the selected objects.';
  @override
  List<ParamSpec> get params => const [ParamSpec.selection('ids')];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      context.commandPrompt('LIST', context.l10n.prompt_select_objects),
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final records = <Map<String, Object?>>[];
    var written = 0;
    for (final id in ids.take(500)) {
      final entity = context.document.entity(id);
      if (entity == null) continue;
      final record = describeEntity(context.document, entity);
      records.add(record);
      if (written < 20) {
        context.input.write(_formatRecord(entity, record));
        written++;
      }
    }
    if (records.length > 20) {
      context.input.write('... and ${records.length - 20} more.');
    }
    context.services.revealPanel('properties');
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Listed ${records.length} object(s).',
      data: {'entities': records},
    );
  }
}

String _formatRecord(CadEntity entity, Map<String, Object?> record) {
  final parts = <String>[];
  for (final entry in record.entries) {
    if (entry.key == 'id' || entry.key == 'kind') continue;
    final value = entry.value;
    if (value is List && value.length == 2 && value.first is num) {
      parts.add(
        '${entry.key}=(${(value[0] as num).toStringAsFixed(3)}, '
        '${(value[1] as num).toStringAsFixed(3)})',
      );
    } else if (value is num) {
      parts.add('${entry.key}=${value.toStringAsFixed(3)}');
    } else if (value is! List && value != null) {
      parts.add('${entry.key}=$value');
    }
  }
  return '${entity.displayId}  ${parts.join('  ')}';
}
