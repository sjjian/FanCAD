import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _select = 'Select';

class ViewUnisolateObjectsCommand extends FanCadCommand
    implements CommandKeybindings {
  const ViewUnisolateObjectsCommand();

  @override
  String get id => 'view.unisolateObjects';
  @override
  String get title => 'Unisolate Objects';
  @override
  String get category => _select;
  @override
  List<String> get aliases => const ['unisolate', 'unisolateobjects'];
  @override
  List<String> get keybindings => const ['ctrl+shift+u'];
  @override
  String get description =>
      'Shows every object that Isolate or Hide had turned off in the '
      'current space.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final hidden = [
      for (final entity in context.document.activeEntities)
        if (!entity.props.visible) entity.id,
    ];
    if (hidden.isEmpty) {
      return const CommandResult.ok(message: 'Nothing is hidden.');
    }
    final committed = context.edit('Unisolate Objects', (transaction) {
      transaction.setVisibleOf(hidden, true);
    });
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Restored ${hidden.length} hidden object(s).',
      transaction: committed,
    );
  }
}
