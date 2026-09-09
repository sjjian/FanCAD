import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'commands.dart';

const _category = 'File';

class FileSaveCommand extends FanCadCommand implements CommandKeybindings {
  const FileSaveCommand(this.files);

  final FileCommands files;

  @override
  String get id => 'file.save';
  @override
  String get title => 'Save';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['save', 'qsave'];
  @override
  String? get icon => 'save';
  @override
  List<String> get keybindings => const ['ctrl+s'];
  @override
  AiExposure get aiExposure => AiExposure.hidden;
  @override
  String get description =>
      'Saves the drawing this command is targeting, asking for a path when it '
      'has never been saved.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    var path = context.session.filePath;
    if (path == null || path.isEmpty) {
      late final String? chosen;
      try {
        chosen = await files.pickSavePath(context.session.title);
      } catch (error) {
        return CommandResult.failed('The file dialog failed: $error');
      }
      if (chosen == null) return const CommandResult.cancelled();
      path = chosen;
    }
    final written = await files.saveActive(context.session, path);
    return written == null
        ? const CommandResult.failed('The file was not written.')
        : CommandResult.ok(message: 'Saved to $written');
  }
}

class FileSaveAsCommand extends FanCadCommand implements CommandKeybindings {
  const FileSaveAsCommand(this.files);

  final FileCommands files;

  @override
  String get id => 'file.saveAs';
  @override
  String get title => 'Save As...';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['saveas'];
  @override
  List<String> get keybindings => const ['ctrl+shift+s'];
  @override
  AiExposure get aiExposure => AiExposure.hidden;
  @override
  String get description =>
      'Saves the drawing this command is targeting to a new file.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'path',
      type: ParamType.text,
      description: 'Destination path',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    var path = context.args.text('path');
    if (path == null || path.isEmpty) {
      late final String? chosen;
      try {
        chosen = await files.pickSavePath(context.session.title);
      } catch (error) {
        return CommandResult.failed('The file dialog failed: $error');
      }
      if (chosen == null) return const CommandResult.cancelled();
      path = chosen;
    }
    final written = await files.saveActive(context.session, path);
    return written == null
        ? const CommandResult.failed('The file was not written.')
        : CommandResult.ok(message: 'Saved to $written');
  }
}
