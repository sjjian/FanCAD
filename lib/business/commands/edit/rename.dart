import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Modify';

class BlockRenameCommand extends FanCadCommand {
  const BlockRenameCommand();

  @override
  String get id => 'block.rename';
  @override
  String get title => 'Rename Block';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['renameblock', 'renblock'];
  @override
  String get description =>
      'Renames a block definition and every insert that still points at '
      'the old name. Layout blocks, anonymous blocks and xrefs cannot be '
      'renamed.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'name',
      type: ParamType.text,
      description: 'Current block name',
    ),
    ParamSpec(
      name: 'newName',
      type: ParamType.text,
      description: 'New block name',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final requested = (await context.resolveText(
      'name',
      'RENAME  Enter block name to change:',
    )).trim();
    if (requested.isEmpty) {
      return const CommandResult.failed('RENAME needs the current block name.');
    }
    final block = insertableBlock(context.document, requested);
    if (block == null) {
      return CommandResult.failed(
        'There is no insertable block named "$requested".',
      );
    }
    if (block.isXref) {
      return const CommandResult.failed('An xref cannot be renamed.');
    }
    final newName = (await context.resolveText(
      'newName',
      'RENAME  Enter new block name:',
    )).trim();
    if (newName.isEmpty) {
      return const CommandResult.failed('The new block name is empty.');
    }
    if (newName.startsWith('*')) {
      return const CommandResult.failed(
        'Block names that start with * are reserved.',
      );
    }
    if (newName.toUpperCase() != block.name.toUpperCase()) {
      final taken = context.document.blocks.keys.any(
        (existing) => existing.toUpperCase() == newName.toUpperCase(),
      );
      if (taken) {
        return CommandResult.failed('A block named "$newName" already exists.');
      }
    }
    if (newName == block.name) {
      return CommandResult.ok(
        message: 'Block "$newName" is already named that.',
      );
    }
    final inserts = [
      for (final entity in context.document.entities)
        if (entity is InsertEntity &&
            entity.blockName.toUpperCase() == block.name.toUpperCase())
          entity,
    ];
    final committed = context.edit('Rename Block', (transaction) {
      if (!transaction.renameBlock(block.name, newName)) return;
      for (final entity in inserts) {
        if (entity.blockName == newName) continue;
        transaction.modify(
          InsertEntity(
            id: entity.id,
            props: entity.props,
            blockName: newName,
            position: entity.position,
            scale: entity.scale,
            rotation: entity.rotation,
            columnCount: entity.columnCount,
            rowCount: entity.rowCount,
            columnSpacing: entity.columnSpacing,
            rowSpacing: entity.rowSpacing,
          ),
        );
      }
    });
    if (committed == null) {
      return const CommandResult.failed('The block was not renamed.');
    }
    return CommandResult(
      status: CommandStatus.ok,
      message:
          'Renamed block "${block.name}" to "$newName"'
          '${inserts.isEmpty ? '.' : ' and ${inserts.length} insert(s).'}',
      data: {'from': block.name, 'to': newName, 'inserts': inserts.length},
      transaction: committed,
    );
  }
}
