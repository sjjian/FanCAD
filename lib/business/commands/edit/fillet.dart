import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditFilletCommand extends FanCadCommand {
  const EditFilletCommand();

  @override
  String get id => 'edit.fillet';
  @override
  String get title => 'Fillet';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['f', 'fillet'];
  @override
  String? get icon => 'fillet';
  @override
  String get description =>
      'Rounds the corner between two lines, or vertices of a polyline, with '
      'an arc of a given radius. Pass all=true to fillet every straight '
      'corner of a polyline. A radius of zero trims or extends two lines to '
      'a sharp corner.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'radius',
      type: ParamType.distance,
      description: 'Fillet radius; 0 for a sharp corner',
      required: false,
      min: 0,
    ),
    ParamSpec(
      name: 'all',
      type: ParamType.boolean,
      description: 'Round every straight vertex of a polyline',
      required: false,
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
    final radius =
        context.args.number('radius') ??
        await context.input.number(
          'FILLET  Specify fillet radius:',
          defaultValue: 0,
        );
    if (radius < 0) {
      return const CommandResult.failed('The radius cannot be negative.');
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
        'FILLET  Select first object:',
        useExistingSelection: false,
        single: true,
      );
      if (firstPick.isEmpty) return const CommandResult.cancelled();
      id1 = firstPick.first;
      final firstEntity = context.document.entity(id1);
      if (firstEntity is PolylineEntity) {
        return _filletPolyline(context, firstEntity, radius);
      }
      final secondPick = await context.input.selection(
        'FILLET  Select second line:',
        useExistingSelection: false,
        single: true,
      );
      if (secondPick.isEmpty) return const CommandResult.cancelled();
      id2 = secondPick.first;
    }

    final first = context.document.entity(id1);
    if (first is PolylineEntity && (id2 == null || id2 == id1)) {
      return _filletPolyline(context, first, radius);
    }

    final second = id2 == null ? null : context.document.entity(id2);
    if (first is! LineEntity || second is! LineEntity) {
      return const CommandResult.failed(
        'Fillet a polyline vertex, or two lines.',
      );
    }
    if (id1 == id2) {
      return const CommandResult.failed('Select two different lines.');
    }

    final pick1 = context.args.point('pick1') ?? first.midpoint;
    final pick2 = context.args.point('pick2') ?? second.midpoint;
    final result = Construct.filletLines(
      first,
      second,
      radius,
      pick1,
      pick2,
      arcProps: EntityProps(layer: context.document.currentLayer),
    );
    if (result == null) {
      return const CommandResult.failed(
        'The two lines are parallel or do not form a filletable corner.',
      );
    }

    final committed = context.edit('Fillet', (transaction) {
      transaction
        ..modify(result.first)
        ..modify(result.second);
      if (result.arc != null) transaction.add(result.arc!);
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing was filleted; the lines may be on a locked layer.',
      );
    }
    context.selection.replace([
      result.first.id,
      result.second.id,
      ...committed.change.added,
    ]);
    return CommandResult(
      status: CommandStatus.ok,
      message: result.arc == null
          ? 'Fillet: lines meet at a sharp corner.'
          : 'Fillet: radius ${radius.toStringAsFixed(4)}.',
      data: {
        'ids': [result.first.id, result.second.id, ...committed.change.added],
      },
      transaction: committed,
    );
  }
}

Future<CommandResult> _filletPolyline(
  CommandContext context,
  PolylineEntity polyline,
  double radius,
) async {
  if (radius <= 0) {
    return const CommandResult.failed(
      'A polyline fillet needs a positive radius.',
    );
  }
  final filletAll =
      context.args.boolean('all') ??
      (context.args.point('pick1') == null &&
          context.args.point('pick') == null &&
          context.input.isInteractive &&
          await context.input.keyword('FILLET  Fillet [Vertex/All]:', const [
                'Vertex',
                'All',
              ], defaultOption: 'Vertex') ==
              'All');
  final PolylineEntity? result;
  if (filletAll) {
    result = Construct.filletPolyline(polyline, radius);
  } else {
    final pick =
        context.args.point('pick1') ??
        context.args.point('pick') ??
        await context.input.point('FILLET  Specify a vertex to round:');
    result = Construct.filletPolylineVertex(polyline, pick, radius);
  }
  if (result == null) {
    return CommandResult.failed(
      filletAll
          ? 'No polyline vertex could be filleted; the radius may be '
                'larger than the adjoining segments.'
          : 'That vertex cannot be filleted; the radius may be larger than '
                'the adjoining segments, or the corner may already be an arc.',
    );
  }
  final filleted = result;
  final committed = context.edit('Fillet', (transaction) {
    transaction.modify(filleted);
  });
  if (committed == null) {
    return const CommandResult.failed(
      'Nothing was filleted; the polyline may be on a locked layer.',
    );
  }
  context.selection.replace([polyline.id]);
  return CommandResult(
    status: CommandStatus.ok,
    message: filletAll
        ? 'Fillet: polyline, radius ${radius.toStringAsFixed(4)}.'
        : 'Fillet: polyline vertex, radius ${radius.toStringAsFixed(4)}.',
    data: {
      'ids': [polyline.id],
    },
    transaction: committed,
  );
}
