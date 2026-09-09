import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'commands.dart';

const _category = 'File';

class FileNewCommand extends FanCadCommand implements CommandKeybindings {
  const FileNewCommand(this.files);

  final FileCommands files;

  @override
  String get id => 'file.new';
  @override
  String get title => 'New Drawing';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['new'];
  @override
  String? get icon => 'file-new';
  @override
  List<String> get keybindings => const ['ctrl+n'];
  @override
  AiExposure get aiExposure => AiExposure.hidden;
  @override
  String get description => 'Creates an empty drawing in a new tab.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    files.newDocument();
    return const CommandResult.ok(message: 'New drawing created.');
  }
}
