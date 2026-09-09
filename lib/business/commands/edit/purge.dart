import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class BlockPurgeCommand extends FanCadCommand {
  const BlockPurgeCommand();

  @override
  String get id => 'block.purge';
  @override
  String get title => 'Purge Unused Blocks';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['purgeblock', 'purgeblocks'];
  @override
  String get description =>
      'Deletes named block definitions that no insert references. Nested '
      'unused definitions are removed in the same pass, so a block that '
      'only existed inside another unused block is cleared too. Xrefs '
      'and layout blocks are left alone.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    if (_unusedBlockNames(context.document).isEmpty) {
      return const CommandResult.ok(message: 'No unused blocks to purge.');
    }
    final purged = <String>[];
    final committed = context.edit('Purge Blocks', (transaction) {
      while (true) {
        final unused = _unusedBlockNames(context.document);
        if (unused.isEmpty) break;
        for (final name in unused) {
          if (transaction.removeBlock(name)) purged.add(name);
        }
      }
    });
    if (committed == null || purged.isEmpty) {
      return const CommandResult.failed('Nothing was purged.');
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Purged ${purged.length} unused block(s).',
      data: {'names': purged},
      transaction: committed,
    );
  }
}

List<String> _unusedBlockNames(CadDocument document) {
  final referenced = {
    for (final entity in document.entities)
      if (entity is InsertEntity) entity.blockName.toUpperCase(),
  };
  return [
    for (final block in document.insertableBlocks)
      if (!block.isXref && !referenced.contains(block.name.toUpperCase()))
        block.name,
  ]..sort();
}
