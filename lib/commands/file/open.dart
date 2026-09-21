import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'commands.dart';
import 'dialog.dart';

const _category = 'File';

class FileOpenCommand extends FanCadCommand implements CommandKeybindings {
  const FileOpenCommand(this.files);

  final FileCommands files;

  @override
  String get id => 'file.open';
  @override
  String get title => 'Open...';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['open'];
  @override
  String? get icon => 'file-open';
  @override
  List<String> get keybindings => const ['ctrl+o'];
  @override
  AiExposure get aiExposure => AiExposure.hidden;
  @override
  String get description => 'Opens a DWG or DXF file.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'path',
      type: ParamType.text,
      description: 'Absolute path to the file',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    var path = context.args.text('path');
    if (path == null || path.isEmpty) {
      late final String? file;
      try {
        file = await openFileDialog();
      } catch (error) {
        return CommandResult.failed('The file dialog failed: $error');
      }
      if (file == null) return const CommandResult.cancelled();
      path = file;
    }
    context.input.write('Opening $path …');
    final ok = await files.openFile(path);
    return ok
        ? CommandResult.ok(message: 'Opened $path')
        : CommandResult.failed('Could not open $path');
  }
}
