import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditChamferCommand extends FanCadCommand {
  const EditChamferCommand();

  @override
  String get id => 'edit.chamfer';
  @override
  String get title => 'Chamfer';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['cha', 'chamfer'];
  @override
  String? get icon => 'chamfer';
  @override
  String get description =>
      'Cuts a straight bevel between two lines, or at vertices of a '
      'polyline. Pass all=true to chamfer every straight corner. The two '
      'distances are measured from the corner back along each segment; omit '
      'the second to use the same length on both.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'dist1',
      type: ParamType.distance,
      description: 'Distance along the first line',
      required: false,
      min: 0,
    ),
    ParamSpec(
      name: 'all',
      type: ParamType.boolean,
      description: 'Bevel every straight vertex of a polyline',
      required: false,
    ),
    ParamSpec(
      name: 'dist2',
      type: ParamType.distance,
      description: 'Distance along the second line; defaults to dist1',
      required: false,
      min: 0,
    ),
    ParamSpec(
      name: 'first',
      type: ParamType.entity,
      description: 'First line',
      required: false,
    ),
    ParamSpec(
      name: 'second',
      type: ParamType.entity,
      description: 'Second line',
      required: false,
    ),
    ParamSpec(
      name: 'pick1',
      type: ParamType.point,
      description: 'Point on the first line that marks the side to keep',
      required: false,
    ),
    ParamSpec(
      name: 'pick2',
      type: ParamType.point,
      description: 'Point on the second line that marks the side to keep',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final dist1 =
        context.args.number('dist1') ??
        await context.input.number(
          'CHAMFER  Specify first chamfer distance:',
          defaultValue: 0,
        );
    if (dist1 < 0) {
      return const CommandResult.failed('Distances cannot be negative.');
    }
    final dist2 =
        context.args.number('dist2') ??
        (context.input.isInteractive
            ? await context.input.number(
                'CHAMFER  Specify second chamfer distance:',
                defaultValue: dist1,
              )
            : dist1);
    if (dist2 < 0) {
      return const CommandResult.failed('Distances cannot be negative.');
    }

    final firstId = context.args.integer('first');
    final secondId = context.args.integer('second');
    final int id1;
    final int? id2;
    if (firstId != null && secondId != null) {
      id1 = firstId;
      id2 = secondId;
    } else if (firstId != null && secondId == null) {
      id1 = firstId;
      id2 = null;
    } else {
      context.selection.clear();
      final firstPick = await context.input.selection(
        'CHAMFER  Select first object:',
        useExistingSelection: false,
        single: true,
      );
      if (firstPick.isEmpty) return const CommandResult.cancelled();
      id1 = firstPick.first;
      final firstEntity = context.document.entity(id1);
      if (firstEntity is PolylineEntity) {
        return _chamferPolyline(context, firstEntity, dist1, dist2);
      }
      final secondPick = await context.input.selection(
        'CHAMFER  Select second line:',
        useExistingSelection: false,
        single: true,
      );
      if (secondPick.isEmpty) return const CommandResult.cancelled();
      id2 = secondPick.first;
    }

    final first = context.document.entity(id1);
    if (first is PolylineEntity && (id2 == null || id2 == id1)) {
      return _chamferPolyline(context, first, dist1, dist2);
    }

    final second = id2 == null ? null : context.document.entity(id2);
    if (first is! LineEntity || second is! LineEntity) {
      return const CommandResult.failed(
        'Chamfer a polyline vertex, or two lines.',
      );
    }
    if (id1 == id2) {
      return const CommandResult.failed('Select two different lines.');
    }

    final pick1 = context.args.point('pick1') ?? first.midpoint;
    final pick2 = context.args.point('pick2') ?? second.midpoint;
    final result = Construct.chamferLines(
      first,
      second,
      dist1,
      dist2,
      pick1,
      pick2,
      cutProps: EntityProps(layer: context.document.currentLayer),
    );
    if (result == null) {
      return const CommandResult.failed(
        'The two lines are parallel or do not form a chamferable corner.',
      );
    }

    final committed = context.edit('Chamfer', (transaction) {
      transaction
        ..modify(result.first)
        ..modify(result.second);
      if (result.cut != null) transaction.add(result.cut!);
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing was chamfered; the lines may be on a locked layer.',
      );
    }
    context.selection.replace([
      result.first.id,
      result.second.id,
      ...committed.change.added,
    ]);
    return CommandResult(
      status: CommandStatus.ok,
      message: result.cut == null
          ? 'Chamfer: lines meet at a sharp corner.'
          : 'Chamfer: ${dist1.toStringAsFixed(4)} x '
                '${dist2.toStringAsFixed(4)}.',
      data: {
        'ids': [result.first.id, result.second.id, ...committed.change.added],
      },
      transaction: committed,
    );
  }
}

Future<CommandResult> _chamferPolyline(
  CommandContext context,
  PolylineEntity polyline,
  double dist1,
  double dist2,
) async {
  if (dist1 <= 0 || dist2 <= 0) {
    return const CommandResult.failed(
      'A polyline chamfer needs positive distances.',
    );
  }
  final chamferAll =
      context.args.boolean('all') ??
      (context.args.point('pick1') == null &&
          context.args.point('pick') == null &&
          context.input.isInteractive &&
          await context.input.keyword('CHAMFER  Chamfer [Vertex/All]:', const [
                'Vertex',
                'All',
              ], defaultOption: 'Vertex') ==
              'All');
  final PolylineEntity? result;
  if (chamferAll) {
    result = Construct.chamferPolyline(polyline, dist1: dist1, dist2: dist2);
  } else {
    final pick =
        context.args.point('pick1') ??
        context.args.point('pick') ??
        await context.input.point('CHAMFER  Specify a vertex to bevel:');
    result = Construct.chamferPolylineVertex(
      polyline,
      pick,
      dist1: dist1,
      dist2: dist2,
    );
  }
  if (result == null) {
    return CommandResult.failed(
      chamferAll
          ? 'No polyline vertex could be chamfered; the distances may be '
                'longer than the adjoining segments.'
          : 'That vertex cannot be chamfered; the distances may be longer '
                'than the adjoining segments, or the corner may already be '
                'an arc.',
    );
  }
  final chamfered = result;
  final committed = context.edit('Chamfer', (transaction) {
    transaction.modify(chamfered);
  });
  if (committed == null) {
    return const CommandResult.failed(
      'Nothing was chamfered; the polyline may be on a locked layer.',
    );
  }
  context.selection.replace([polyline.id]);
  return CommandResult(
    status: CommandStatus.ok,
    message: chamferAll
        ? 'Chamfer: polyline, ${dist1.toStringAsFixed(4)} x '
              '${dist2.toStringAsFixed(4)}.'
        : 'Chamfer: polyline vertex, ${dist1.toStringAsFixed(4)} x '
              '${dist2.toStringAsFixed(4)}.',
    data: {
      'ids': [polyline.id],
    },
    transaction: committed,
  );
}
