import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'commands.dart';

const _category = 'File';

class FileOpenRecentCommand extends FanCadCommand {
  const FileOpenRecentCommand(this.files);

  final FileCommands files;

  @override
  String get id => 'file.openRecent';
  @override
  String get title => 'Open Recent';
  @override
  String get category => _category;
  @override
  AiExposure get aiExposure => AiExposure.hidden;
  @override
  String get description => 'Reopens a recently used file.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'path',
      type: ParamType.text,
      description: 'One of the recent paths',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final recent = files.recentFiles();
    if (recent.isEmpty) {
      return const CommandResult.failed('There are no recent files.');
    }
    var path = context.args.text('path')?.trim();
    if (path == null || path.isEmpty) {
      path = (await context.input.keyword('Open recent:', recent)).trim();
    }
    if (path.isEmpty) {
      return const CommandResult.failed('No recent file was chosen.');
    }
    final ok = await files.openFile(path);
    return ok
        ? CommandResult.ok(message: 'Opened $path')
        : CommandResult.failed('Could not open $path');
  }
}
