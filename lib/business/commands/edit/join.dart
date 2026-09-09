import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditJoinCommand extends FanCadCommand {
  const EditJoinCommand();

  @override
  String get id => 'edit.join';
  @override
  String get title => 'Join';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['j', 'join'];
  @override
  String get description =>
      'Joins selected lines, arcs and open polylines whose endpoints meet '
      'into a single polyline. A piece is reversed when that is how it '
      'touches the chain; a loop whose ends meet is stored closed.';
  @override
  List<ParamSpec> get params => const [ParamSpec.selection('ids')];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'JOIN  Select lines, arcs or polylines to join:',
    );
    final pieces = <CadEntity>[
      for (final id in ids)
        if (context.document.entity(id) case final CadEntity entity)
          if (entity is LineEntity ||
              entity is ArcEntity ||
              (entity is PolylineEntity && !entity.closed))
            entity,
    ];
    if (pieces.length < 2) {
      return const CommandResult.failed(
        'Select at least two lines, arcs or open polylines to join.',
      );
    }

    final joined = Construct.joinEntities(pieces);
    if (joined == null) {
      return const CommandResult.failed(
        'The selected objects do not form a single connected chain.',
      );
    }
    final committed = context.edit('Join', (transaction) {
      transaction
        ..add(joined)
        ..eraseAll([for (final piece in pieces) piece.id]);
    });
    if (committed == null) {
      return const CommandResult.failed('Nothing was joined.');
    }
    context.selection.replace(committed.change.added);
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Joined ${pieces.length} objects into one polyline.',
      transaction: committed,
    );
  }
}
