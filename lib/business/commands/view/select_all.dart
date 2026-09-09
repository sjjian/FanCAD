import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _select = 'Select';

class SelectAllCommand extends FanCadCommand implements CommandKeybindings {
  const SelectAllCommand();

  @override
  String get id => 'select.all';
  @override
  String get title => 'Select All';
  @override
  String get category => _select;
  @override
  List<String> get keybindings => const ['ctrl+a'];
  @override
  String get description =>
      'Selects every selectable object in the current space.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = [
      for (final entity in context.document.activeEntities)
        if (context.document.isSelectable(entity)) entity.id,
    ];
    context.selection.replace(ids);
    return CommandResult.ok(message: '${ids.length} object(s) selected.');
  }
}

class SelectNoneCommand extends FanCadCommand implements CommandKeybindings {
  const SelectNoneCommand();

  @override
  String get id => 'select.none';
  @override
  String get title => 'Deselect All';
  @override
  String get category => _select;
  @override
  List<String> get keybindings => const ['ctrl+shift+a'];
  @override
  String get description => 'Clears the selection.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    context.selection.clear();
    return const CommandResult.ok();
  }
}
