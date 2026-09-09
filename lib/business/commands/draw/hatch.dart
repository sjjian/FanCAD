import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawHatchCommand extends FanCadCommand {
  const DrawHatchCommand();

  @override
  String get id => 'draw.hatch';
  @override
  String get title => 'Hatch';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['h', 'hatch'];
  @override
  String get description =>
      'Fills the area around an internal point, or around selected '
      'closed boundaries. Four lines that meet still count as a boundary.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'inside',
      type: ParamType.point,
      description: 'A point inside the area to fill',
      required: false,
    ),
    ParamSpec(
      name: 'ids',
      type: ParamType.selection,
      description: 'Closed boundaries to fill, or the curves to search',
      required: false,
    ),
    ParamSpec(
      name: 'pattern',
      type: ParamType.text,
      description: 'Pattern name, or SOLID for a solid fill',
      required: false,
      defaultValue: 'SOLID',
    ),
    ParamSpec(
      name: 'scale',
      type: ParamType.distance,
      description: 'Pattern scale',
      required: false,
      defaultValue: 1,
    ),
    ParamSpec(
      name: 'angle',
      type: ParamType.angle,
      description: 'Pattern rotation in degrees',
      required: false,
      defaultValue: 0,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final pattern = context.args.text('pattern') ?? 'SOLID';
    final scale = context.args.number('scale') ?? 1;
    if (scale <= 0) {
      return const CommandResult.failed('Hatch scale must be positive.');
    }
    final angle = (context.args.number('angle') ?? 0) * math.pi / 180;
    final loops = await _hatchLoops(context);
    if (loops == null) return const CommandResult.cancelled();
    if (loops.isEmpty) {
      final usedPick = context.args.point('inside') != null;
      final usedIds = (context.args.ids('ids') ?? []).isNotEmpty;
      return CommandResult.failed(
        usedIds && !usedPick
            ? 'None of the selected objects form a closed boundary.'
            : 'No closed boundary encloses that point.',
      );
    }
    return commitDraw(context, 'Hatch', [
      HatchEntity(
        id: 0,
        props: EntityProps(layer: context.document.currentLayer),
        loops: loops,
        patternName: pattern.toUpperCase(),
        solid: pattern.toUpperCase() == 'SOLID',
        patternScale: scale,
        patternAngle: angle,
      ),
    ]);
  }
}

/// Resolves hatch loops from an internal pick, or from selected closed
/// entities when the caller already knows the rings.
Future<List<HatchLoop>?> _hatchLoops(CommandContext context) async {
  final inside = context.args.point('inside');
  final idsArg = context.args.ids('ids');

  if (inside != null) {
    return Construct.boundaryFromPick(
      _hatchCandidates(context, idsArg),
      inside,
    );
  }

  if (idsArg != null && idsArg.isNotEmpty) {
    return _loopsFromClosed(context, idsArg);
  }

  if (!context.input.isInteractive) {
    return const [];
  }

  final answer = await context.input.pointOrKeyword(
    'HATCH  Specify internal point or [Select]:',
    keywords: const ['Select'],
  );
  if (answer == null) return null;
  if (answer.isPoint) {
    return Construct.boundaryFromPick(
      context.document.activeEntities,
      answer.point!,
    );
  }
  final ids = await context.input.selection('HATCH  Select closed boundaries:');
  if (ids.isEmpty) return null;
  return _loopsFromClosed(context, ids);
}

Iterable<CadEntity> _hatchCandidates(CommandContext context, List<int>? ids) {
  if (ids != null && ids.isNotEmpty) {
    return [
      for (final id in ids)
        if (context.document.entity(id) != null) context.document.entity(id)!,
    ];
  }
  return context.document.activeEntities;
}

List<HatchLoop> _loopsFromClosed(CommandContext context, List<int> ids) {
  final loops = <HatchLoop>[];
  for (final id in ids) {
    final entity = context.document.entity(id);
    if (entity == null) continue;
    // Only genuinely closed geometry can bound a fill; hatching an open
    // polyline silently produces nonsense, so it is refused per entity.
    final sink = PolylineSink();
    entity.emit(context.document.emitContext(tolerance: 0.05), sink);
    for (var i = 0; i < sink.polylines.length; i++) {
      if (!sink.closedFlags[i]) continue;
      if (sink.polylines[i].length < 6) continue;
      loops.add(HatchLoop(vertices: sink.polylines[i]));
    }
  }
  return loops;
}
