import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'commands.dart';

const _category = 'File';

class FileListCommand extends FanCadCommand {
  const FileListCommand(this.files);

  final FileCommands files;

  @override
  String get id => 'file.list';
  @override
  String get title => 'List Drawings';
  @override
  String get category => _category;
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  String get description =>
      'Lists every open drawing tab: id, title, path, dirty, whether it is '
      'active, entity count, and the current layout. Use the id as the '
      'fancad tab selector to operate on a drawing without switching the UI.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final sessions = files.listSessions?.call() ?? const <DocumentSession>[];
    final activeId = files.activeSessionId?.call();
    return CommandResult.ok(
      message: '${sessions.length} open drawing(s).',
      data: {
        'drawings': [
          for (final session in sessions)
            {
              'id': session.id,
              'title': session.title,
              'path': session.filePath,
              'dirty': session.isDirty,
              'active': session.id == activeId,
              'entityCount': session.document.entityCount,
              'activeLayout': session.document.activeLayoutName,
            },
        ],
      },
    );
  }
}
