import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditTrimCommand extends FanCadCommand {
  const EditTrimCommand();

  @override
  String get id => 'edit.trim';
  @override
  String get title => 'Trim';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['tr', 'trim'];
  @override
  String? get icon => 'trim';
  @override
  String get description =>
      'Shortens a line, polyline or arc back to where it crosses the '
      'selected cutting edges. The part containing the pick point is '
      'removed. A closed polyline opens; a bulge is cut on the arc, not '
      'the chord.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('edges', description: 'Cutting edges'),
    ParamSpec(
      name: 'target',
      type: ParamType.entity,
      description: 'The line, polyline or arc to trim',
    ),
    ParamSpec.point('pick', description: 'A point on the piece to remove'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) =>
      _trimOrExtend(context, extend: false);
}

class EditExtendCommand extends FanCadCommand {
  const EditExtendCommand();

  @override
  String get id => 'edit.extend';
  @override
  String get title => 'Extend';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['ex', 'extend'];
  @override
  String get description =>
      'Lengthens a line, open polyline or arc until it meets the '
      'selected boundary edges. A bulge grows along its circle. The pick '
      'chooses which end moves.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('edges', description: 'Boundary edges'),
    ParamSpec(
      name: 'target',
      type: ParamType.entity,
      description: 'The line, polyline or arc to extend',
    ),
    ParamSpec.point('pick', description: 'A point nearer the end to move'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) =>
      _trimOrExtend(context, extend: true);
}

Future<CommandResult> _trimOrExtend(
  CommandContext context, {
  required bool extend,
}) async {
  final verb = extend ? 'EXTEND' : 'TRIM';
  final edgeIds = await context.resolveSelection(
    'edges',
    extend
        ? context.commandPrompt(
            'EXTEND',
            context.l10n.prompt_select_boundary_edges,
          )
        : context.commandPrompt(
            'TRIM',
            context.l10n.prompt_select_cutting_edges,
          ),
  );
  if (edgeIds.isEmpty) return const CommandResult.cancelled();
  // The edges are now fixed; clearing the selection stops the next prompt
  // from silently reusing them as the thing to modify.
  context.selection.clear();

  final edges = <CadEntity>[
    for (final id in edgeIds) ?context.document.entity(id),
  ];

  // A supplied target means one pass; otherwise the command keeps asking,
  // which is how TRIM is used in practice — pick edges once, then trim as
  // many objects as you like until Escape.
  final suppliedTarget = context.args.integer('target');
  final suppliedPick = context.args.point('pick');

  var changed = 0;
  var attempts = 0;
  CommittedTransaction? last;
  while (true) {
    final int targetId;
    if (suppliedTarget != null) {
      if (attempts > 0) break;
      targetId = suppliedTarget;
    } else {
      final picked = await context.input.selection(
        context.commandPrompt(
          verb,
          extend
              ? context.l10n.prompt_select_object_to_extend
              : context.l10n.prompt_select_object_to_trim,
        ),
        useExistingSelection: false,
        single: true,
      );
      if (picked.isEmpty) break;
      targetId = picked.first;
    }
    attempts++;

    final target = context.document.entity(targetId);
    if (target is! LineEntity &&
        target is! PolylineEntity &&
        target is! ArcEntity &&
        target is! EllipseEntity &&
        target is! SplineEntity) {
      context.input.write(
        '$verb supports lines, polylines, arcs, ellipses and splines; '
        '${target?.kind.name ?? 'that object'} was skipped.',
      );
      if (suppliedTarget != null) {
        return CommandResult.failed(
          '$verb supports lines, polylines, arcs, ellipses and splines.',
        );
      }
      continue;
    }
    final curve = target as Curve;
    if (extend && curve.isLoop) {
      context.input.write('EXTEND cannot change a closed curve.');
      if (suppliedTarget != null) {
        return const CommandResult.failed(
          'EXTEND cannot change a closed curve.',
        );
      }
      continue;
    }
    final CadEntity? result;
    if (extend) {
      result = Construct.extend(curve, edges, suppliedPick);
    } else {
      final crossings = <Vec2>[
        for (final edge in edges) ...Construct.crossingsAlong(curve, edge),
      ];
      // Without a pick point there is no way to know which side to discard,
      // so the middle of the object is the least surprising guess.
      result = Construct.trim(
        curve,
        crossings,
        suppliedPick ?? curve.along(0.5),
      );
    }
    if (result == null) {
      context.input.write(
        '$verb: no usable intersection with the selected edges.',
      );
      if (suppliedTarget != null) {
        return CommandResult.failed(
          '$verb found no usable intersection with the selected edges.',
        );
      }
      continue;
    }
    last = context.edit(extend ? 'Extend' : 'Trim', (transaction) {
      transaction.modify(result!);
    });
    if (last != null) changed++;
    context.selection.clear();
  }

  if (changed == 0) return const CommandResult.cancelled();
  return CommandResult(
    status: CommandStatus.ok,
    message: '$verb: $changed object(s) modified.',
    transaction: last,
  );
}
