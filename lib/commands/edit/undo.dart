import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditUndoCommand extends FanCadCommand implements CommandKeybindings {
  const EditUndoCommand();

  @override
  String get id => 'edit.undo';
  @override
  String get title => 'Undo';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['u', 'undo'];
  @override
  String? get icon => 'undo';
  @override
  List<String> get keybindings => const ['ctrl+z'];
  @override
  bool get repeatable => false;
  @override
  AiExposure get aiExposure => AiExposure.hidden;
  @override
  String get description => 'Reverses the most recent change.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final label = context.session.history.nextUndoLabel;
    if (!context.session.undo()) {
      return const CommandResult.failed('There is nothing to undo.');
    }
    return CommandResult.ok(message: 'Undo: ${label ?? 'change reversed'}');
  }
}

class EditRedoCommand extends FanCadCommand implements CommandKeybindings {
  const EditRedoCommand();

  @override
  String get id => 'edit.redo';
  @override
  String get title => 'Redo';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['redo'];
  @override
  String? get icon => 'redo';
  @override
  List<String> get keybindings => const ['ctrl+shift+z'];
  @override
  bool get repeatable => false;
  @override
  AiExposure get aiExposure => AiExposure.hidden;
  @override
  String get description => 'Re-applies the most recently undone change.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final label = context.session.history.nextRedoLabel;
    if (!context.session.redo()) {
      return const CommandResult.failed('There is nothing to redo.');
    }
    return CommandResult.ok(message: 'Redo: ${label ?? 'change re-applied'}');
  }
}
