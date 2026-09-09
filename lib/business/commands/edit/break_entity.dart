import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditBreakCommand extends FanCadCommand {
  const EditBreakCommand();

  @override
  String get id => 'edit.break';
  @override
  String get title => 'Break';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['br', 'break'];
  @override
  String get description =>
      'Splits a line, polyline or arc at a point, or removes the portion '
      'between two points. A bulge is split into two smaller arcs. A circle '
      'needs two points and keeps the counter-clockwise remnant from the '
      'second pick back to the first. Omit the second point to only split '
      '(arcs and open chains).';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'target',
      type: ParamType.entity,
      description: 'The line, polyline, arc or circle to break',
      required: false,
    ),
    ParamSpec.point('first', description: 'First break point'),
    ParamSpec(
      name: 'second',
      type: ParamType.point,
      description: 'Second break point; omit to split at the first',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final supplied = context.args.integer('target');
    final int targetId;
    if (supplied != null) {
      targetId = supplied;
    } else {
      context.selection.clear();
      final picked = await context.input.selection(
        'BREAK  Select object to break:',
        useExistingSelection: false,
        single: true,
      );
      if (picked.isEmpty) return const CommandResult.cancelled();
      targetId = picked.first;
    }

    final target = context.document.entity(targetId);
    if (target is! LineEntity &&
        target is! PolylineEntity &&
        target is! ArcEntity &&
        target is! CircleEntity) {
      return const CommandResult.failed(
        'Break supports lines, polylines, arcs and circles.',
      );
    }

    final first = await context.resolvePoint(
      'first',
      'BREAK  Specify first break point:',
    );
    context.input
      ..setMarkers([first])
      ..setPreview((cursor) => [OverlayLine(first, cursor)]);
    final second =
        context.args.point('second') ??
        (context.input.isInteractive
            ? await context.input.pointOrNull(
                'BREAK  Specify second break point (Escape to split):',
              )
            : null);
    context.input
      ..setPreview(null)
      ..setMarkers(const []);
    if (target is CircleEntity && second == null) {
      return const CommandResult.failed('A circle needs two break points.');
    }

    final pieces = switch (target) {
      LineEntity() => Construct.breakLine(target, first, second),
      PolylineEntity() => Construct.breakPolyline(target, first, second),
      ArcEntity() => Construct.breakArc(target, first, second),
      CircleEntity() => Construct.breakCircle(target, first, second),
      _ => null,
    };
    if (pieces == null) {
      return const CommandResult.failed(
        'The break point is at an end of the object, so nothing changed.',
      );
    }

    final committed = context.edit('Break', (transaction) {
      if (pieces.isEmpty) {
        transaction.erase(targetId);
        return;
      }
      transaction.modify(pieces.first);
      for (var i = 1; i < pieces.length; i++) {
        transaction.add(pieces[i]);
      }
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing was broken; the object may be on a locked layer.',
      );
    }
    context.selection.replace([
      if (pieces.isNotEmpty) pieces.first.id,
      ...committed.change.added,
    ]);
    return CommandResult(
      status: CommandStatus.ok,
      message: pieces.isEmpty
          ? 'Break: the object was removed.'
          : pieces.length == 1
          ? 'Break: one remnant remains.'
          : 'Break: the object was split.',
      data: {
        'ids': [
          if (pieces.isNotEmpty) pieces.first.id,
          ...committed.change.added,
        ],
      },
      transaction: committed,
    );
  }
}
