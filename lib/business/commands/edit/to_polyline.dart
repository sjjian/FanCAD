import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditToPolylineCommand extends FanCadCommand {
  const EditToPolylineCommand();

  @override
  String get id => 'edit.toPolyline';
  @override
  String get title => 'Convert to Polyline';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['convpline', 'topoly'];
  @override
  String get description =>
      'Turns selected lines into two-vertex polylines so they can be '
      'closed, opened or reversed as a chain.';
  @override
  List<ParamSpec> get params => const [ParamSpec.selection('ids')];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'PEDIT  Select lines to convert:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();

    final lines = <LineEntity>[
      for (final id in ids)
        if (context.document.entity(id) case final LineEntity line) line,
    ];
    if (lines.isEmpty) {
      return const CommandResult.failed('Select at least one line to convert.');
    }

    final committed = context.edit('Convert to Polyline', (transaction) {
      for (final line in lines) {
        transaction
          ..add(
            PolylineEntity.fromPoints(
              id: 0,
              props: line.props,
              points: [line.start, line.end],
            ),
          )
          ..erase(line.id);
      }
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing was converted; the lines may be on a locked layer.',
      );
    }
    context.selection.replace(committed.change.added);
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Converted ${lines.length} line(s) to polylines.',
      data: {'ids': committed.change.added},
      transaction: committed,
    );
  }
}
