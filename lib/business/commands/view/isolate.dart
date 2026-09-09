import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _select = 'Select';

class ViewIsolateObjectsCommand extends FanCadCommand
    implements CommandKeybindings {
  const ViewIsolateObjectsCommand();

  @override
  String get id => 'view.isolateObjects';
  @override
  String get title => 'Isolate Objects';
  @override
  String get category => _select;
  @override
  List<String> get aliases => const ['isolate', 'isolateobjects'];
  @override
  List<String> get keybindings => const ['ctrl+shift+i'];
  @override
  String get description =>
      'Hides every object in the current space except the selection, so the '
      'rest of the drawing is out of the way without being deleted.';
  @override
  List<ParamSpec> get params => const [ParamSpec.selection('ids')];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'ISOLATE  Select objects to keep visible:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final keep = ids.toSet();
    final hidden = [
      for (final entity in context.document.activeEntities)
        if (!keep.contains(entity.id) && entity.props.visible) entity.id,
    ];
    if (hidden.isEmpty) {
      return const CommandResult.ok(
        message: 'The rest of the drawing is already hidden.',
      );
    }
    final committed = context.edit('Isolate Objects', (transaction) {
      transaction.setVisibleOf(hidden, false);
    });
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Isolated ${keep.length} object(s); hid ${hidden.length}.',
      transaction: committed,
    );
  }
}

class ViewHideObjectsCommand extends FanCadCommand
    implements CommandKeybindings {
  const ViewHideObjectsCommand();

  @override
  String get id => 'view.hideObjects';
  @override
  String get title => 'Hide Objects';
  @override
  String get category => _select;
  @override
  List<String> get aliases => const ['hide', 'hideobjects'];
  @override
  List<String> get keybindings => const ['ctrl+shift+h'];
  @override
  String get description => 'Hides the selected objects without deleting them.';
  @override
  List<ParamSpec> get params => const [ParamSpec.selection('ids')];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'HIDE  Select objects to hide:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final committed = context.edit('Hide Objects', (transaction) {
      transaction.setVisibleOf(ids, false);
    });
    context.selection.clear();
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Hid ${ids.length} object(s).',
      transaction: committed,
    );
  }
}
