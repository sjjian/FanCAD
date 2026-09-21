import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'commands.dart';

const _category = 'File';

class FileCloseCommand extends FanCadCommand implements CommandKeybindings {
  const FileCloseCommand(this.files);

  final FileCommands files;

  @override
  String get id => 'file.close';
  @override
  String get title => 'Close Drawing';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['close'];
  @override
  List<String> get keybindings => const ['ctrl+w'];
  @override
  AiExposure get aiExposure => AiExposure.hidden;
  @override
  String get description => 'Closes the drawing this command is targeting.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    if (files.closeActive(context.session, force: false)) {
      return const CommandResult.ok();
    }
    // Unsaved work is the one case where a command refuses and hands the
    // decision back, rather than choosing on the user's behalf.
    final discard = await context.services.requestApproval(
      'Unsaved changes',
      '"${context.session.title}" has unsaved changes.',
    );
    if (!discard) return const CommandResult.cancelled();
    files.closeActive(context.session, force: true);
    return const CommandResult.ok(message: 'Drawing closed.');
  }
}
