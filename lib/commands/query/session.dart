import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Inquiry';

class QuerySessionCommand extends FanCadCommand {
  const QuerySessionCommand();

  @override
  String get id => 'query.session';
  @override
  String get title => 'Session';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['session'];
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  String get description =>
      'Returns compact statistics for the live session: which drawing is '
      'targeted, how many objects are selected, the visible window, snap, '
      'and any command already running. Call query.summary for entity counts '
      'and query.selection when you need the picked objects.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final hosted = context.services.describeSession(context.session);
    final data = hosted.isNotEmpty ? hosted : _fromSession(context.session);
    final count = data['selectionCount'];
    final n = count is int ? count : 0;
    final running = data['runningCommand'];
    final command = running is String && running.isNotEmpty ? running : 'none';
    final picked = n == 0 ? 'Nothing selected' : '$n selected';
    return CommandResult(
      status: CommandStatus.ok,
      message: '$picked. Running command: $command.',
      data: data,
    );
  }
}

Map<String, Object?> _fromSession(DocumentSession session) {
  final path = session.filePath?.trim() ?? '';
  return {
    'drawingId': session.id,
    'title': session.title,
    if (path.isNotEmpty) 'path': path,
    'selectionCount': session.selection.ids.length,
    'viewport': null,
    'lastCreatedIds': const <int>[],
    'lastModifiedIds': const <int>[],
  };
}
