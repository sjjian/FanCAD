import 'dart:typed_data';

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

/// Creates planar REGION objects from closed boundaries.
///
/// The first version reuses the HATCH boundary tracer. Its loops are already
/// flattened, so the created REGION is marked approximated until the
/// curve-aware boundary tracer lands.
class DrawRegionCommand extends FanCadCommand {
  const DrawRegionCommand();

  @override
  String get id => 'draw.region';
  @override
  String get title => 'Region';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['reg', 'region'];
  @override
  String get description =>
      'Creates a 2D region from an internal point or selected closed '
      'boundaries.';

  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'inside',
      type: ParamType.point,
      description: 'A point inside the area',
      required: false,
    ),
    ParamSpec(
      name: 'ids',
      type: ParamType.selection,
      description: 'Closed boundaries to convert, or the curves to search',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final geometry = await _regionGeometry(context);
    if (geometry == null) return const CommandResult.cancelled();
    if (geometry.components.isEmpty) {
      return const CommandResult.failed(
        'None of the selected objects form a closed boundary.',
      );
    }
    return commitDraw(context, 'Region', [
      RegionEntity(
        id: 0,
        props: EntityProps(layer: context.document.currentLayer),
        components: geometry.components,
        approximated: geometry.approximated,
      ),
    ]);
  }
}

Future<RegionGeometry?> _regionGeometry(CommandContext context) async {
  final inside = context.args.point('inside');
  final idsArg = context.args.ids('ids');

  if (inside != null) {
    final loops = Construct.boundaryFromPick(
      _candidates(context, idsArg),
      inside,
    );
    return RegionGeometry.fromLoops(_toRegionLoops(loops), approximated: true);
  }
  if (idsArg != null && idsArg.isNotEmpty) {
    final selected = _candidates(context, idsArg).toList();
    final exact = const RegionBuilder().build(selected);
    if (exact != null && exact.components.isNotEmpty) return exact;
    return RegionGeometry.fromLoops(
      _toRegionLoops(_loopsFromClosed(context, idsArg)),
      approximated: true,
    );
  }
  if (!context.input.isInteractive) return null;

  final answer = await context.input.pointOrKeyword(
    context.commandPrompt(
      'REGION',
      context.l10n.prompt_hatch_internal_or_select,
    ),
    keywords: const ['Select'],
  );
  if (answer == null) return null;
  if (answer.isPoint) {
    final loops = Construct.boundaryFromPick(
      context.document.activeEntities,
      answer.point!,
    );
    return RegionGeometry.fromLoops(_toRegionLoops(loops), approximated: true);
  }
  final ids = await context.input.selection(
    context.commandPrompt(
      'REGION',
      context.l10n.prompt_select_closed_boundaries,
    ),
  );
  if (ids.isEmpty) return null;
  final selected = _candidates(context, ids).toList();
  final exact = const RegionBuilder().build(selected);
  if (exact != null && exact.components.isNotEmpty) return exact;
  return RegionGeometry.fromLoops(
    _toRegionLoops(_loopsFromClosed(context, ids)),
    approximated: true,
  );
}

Iterable<CadEntity> _candidates(CommandContext context, List<int>? ids) {
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

List<RegionLoop> _toRegionLoops(List<HatchLoop> loops) => [
  for (final loop in loops)
    RegionLoop([RegionPolyline(Float64List.fromList(loop.vertices))]),
];
