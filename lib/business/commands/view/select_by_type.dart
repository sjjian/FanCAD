import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _select = 'Select';

class SelectByTypeCommand extends FanCadCommand {
  const SelectByTypeCommand();

  @override
  String get id => 'select.byType';
  @override
  String get title => 'Select by Type';
  @override
  String get category => _select;
  @override
  List<String> get aliases => const ['seltype', 'selecttype'];
  @override
  String get description =>
      'Selects every object of one entity kind in the current space. '
      'LINE, CIRCLE, INSERT, DIMENSION and the other FanCAD kinds work; '
      'LWPOLYLINE and BLOCK are accepted as polyline and insert.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'kind',
      type: ParamType.text,
      description: 'Entity kind, e.g. line, circle, insert',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final raw = await context.resolveText(
      'kind',
      'SELECT  Enter object type (LINE, CIRCLE, INSERT, …):',
    );
    final kind = _tryEntityKind(raw);
    if (kind == null) {
      return CommandResult.failed(
        '"$raw" is not an object type. Use LINE, CIRCLE, ARC, POLYLINE, '
        'INSERT, TEXT, DIMENSION, …',
      );
    }
    final ids = [
      for (final entity in context.document.activeEntities)
        if (entity.kind == kind && context.document.isSelectable(entity))
          entity.id,
    ];
    context.selection.replace(ids);
    return CommandResult.ok(
      message: '${ids.length} ${kind.name} object(s) selected.',
    );
  }
}

EntityKind? _tryEntityKind(String raw) {
  final key = raw.trim().toLowerCase();
  if (key.isEmpty) return null;
  const aliases = {
    'lwpolyline': EntityKind.polyline,
    'pline': EntityKind.polyline,
    'block': EntityKind.insert,
    'blockref': EntityKind.insert,
    'dim': EntityKind.dimension,
    'dtext': EntityKind.text,
    'constructionline': EntityKind.xline,
  };
  if (aliases[key] case final kind?) return kind;
  for (final kind in EntityKind.values) {
    if (kind == EntityKind.unknown) continue;
    if (kind.name == key) return kind;
  }
  return null;
}
