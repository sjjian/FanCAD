import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Modify';

class BlockEditCommand extends FanCadCommand {
  const BlockEditCommand();

  @override
  String get id => 'block.edit';
  @override
  String get title => 'Edit Block';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['bedit'];
  @override
  String get description =>
      'Opens a block definition on the canvas. New and changed objects '
      'belong to that block, and existing inserts show the update. Layout '
      'blocks and anonymous blocks cannot be opened.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'name', type: ParamType.text, description: 'Block name'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final requested = (await context.resolveText(
      'name',
      context.commandPrompt('BEDIT', context.l10n.prompt_enter_block_name),
    )).trim();
    if (requested.isEmpty) {
      return const CommandResult.failed('BEDIT needs a block name.');
    }
    final block = insertableBlock(context.document, requested);
    if (block == null) {
      return CommandResult.failed(
        'There is no insertable block named "$requested".',
      );
    }
    if (context.document.editedBlockName == block.name) {
      return CommandResult.ok(
        message: 'Already editing block "${block.name}".',
      );
    }
    final entering = context.document.editedBlockName == null;
    context.selection.clear();
    if (!context.document.setEditedBlock(block.name)) {
      return CommandResult.failed('Block "${block.name}" cannot be edited.');
    }
    context.services.invalidate();
    if (entering) {
      // A layout switch can leave a camera from an earlier edit. Replace it
      // with the view on screen now, which is the one close should restore.
      context.services.dropHeldView();
      context.services.holdView();
    }
    context.services.zoomTo(null);
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Editing block "${block.name}".',
      data: {'block': block.name},
    );
  }
}

class BlockCloseCommand extends FanCadCommand {
  const BlockCloseCommand();

  @override
  String get id => 'block.close';
  @override
  String get title => 'Close Block';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['bclose'];
  @override
  String get description =>
      'Leaves block editing and returns the canvas to the current layout.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final name = context.document.editedBlockName;
    if (name == null) {
      context.services.dropHeldView();
      return const CommandResult.ok(message: 'Not editing a block.');
    }
    context.selection.clear();
    context.document.setEditedBlock(null);
    context.services.invalidate();
    if (!context.services.restoreHeldView()) {
      context.services.zoomTo(null);
    }
    return CommandResult.ok(message: 'Closed block "$name".');
  }
}
