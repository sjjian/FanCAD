import 'package:fancad_core/fancad_core.dart';

List<BlockRecord> xrefsFromContext(CommandContext context) {
  final requested = context.args.text('name')?.trim() ?? '';
  if (requested.isNotEmpty) {
    final block = xrefNamed(context.document, requested);
    return block == null ? const [] : [block];
  }

  final fromSelection = <String, BlockRecord>{};
  for (final id in context.selection.ids) {
    final entity = context.document.entity(id);
    if (entity is! InsertEntity) continue;
    final block = xrefNamed(context.document, entity.blockName);
    if (block != null) fromSelection[block.name] = block;
  }
  if (fromSelection.isNotEmpty) return fromSelection.values.toList();

  final all = [
    for (final block in context.document.blocks.values)
      if (block.isXref) block,
  ];
  return all.length == 1 ? all : const [];
}

BlockRecord? xrefNamed(CadDocument document, String name) {
  final needle = name.toLowerCase();
  for (final block in document.blocks.values) {
    if (block.isXref && block.name.toLowerCase() == needle) return block;
  }
  return null;
}
