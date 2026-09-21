import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Inquiry';

class QuerySummaryCommand extends FanCadCommand {
  const QuerySummaryCommand();

  @override
  String get id => 'query.summary';
  @override
  String get title => 'Drawing Summary';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['summary'];
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  String get description =>
      'Returns a compact statistical summary of the drawing: extents, entity '
      'counts by type, and per-layer counts. Use this first to understand a '
      'drawing before querying its contents.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final document = context.document;
    final byKind = <String, int>{};
    final byLayer = <String, int>{};
    for (final entity in document.activeEntities) {
      byKind.update(entity.kind.name, (n) => n + 1, ifAbsent: () => 1);
      byLayer.update(entity.props.layer, (n) => n + 1, ifAbsent: () => 1);
    }
    final extents = document.extents;
    final data = {
      'entityCount': document.entityCount,
      'activeLayout': document.activeLayoutName,
      'currentLayer': document.currentLayer,
      'extents': extents.isEmpty
          ? null
          : {
              'min': [extents.minX, extents.minY],
              'max': [extents.maxX, extents.maxY],
            },
      'byKind': byKind,
      'byLayer': byLayer,
      'layers': [
        for (final layer in document.layers.values)
          {
            'name': layer.name,
            'visible': layer.isEffectivelyVisible,
            'locked': layer.locked,
            'count': byLayer[layer.name] ?? 0,
          },
      ],
      'blocks': [
        for (final block in document.blocks.values)
          if (!block.isLayoutBlock) block.name,
      ],
    };
    return CommandResult(
      status: CommandStatus.ok,
      message: _describeSummary(document, byKind, extents),
      data: data,
    );
  }
}

String _describeSummary(
  CadDocument document,
  Map<String, int> byKind,
  Bounds2 extents,
) {
  final kinds = byKind.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top = kinds
      .take(5)
      .map((entry) => '${entry.value} ${entry.key}')
      .join(', ');
  final size = extents.isEmpty
      ? 'empty'
      : '${extents.width.toStringAsFixed(1)} x '
            '${extents.height.toStringAsFixed(1)}';
  return '${document.entityCount} objects ($top) across '
      '${document.layers.length} layers, extents $size.';
}
