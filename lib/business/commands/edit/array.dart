import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditArrayCommand extends FanCadCommand {
  const EditArrayCommand();

  @override
  String get id => 'edit.array';
  @override
  String get title => 'Rectangular Array';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['ar', 'array'];
  @override
  String get description =>
      'Creates a rectangular grid of copies of the selected objects.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec(
      name: 'columns',
      type: ParamType.integer,
      description: 'Number of columns, including the original',
      min: 1,
    ),
    ParamSpec(
      name: 'rows',
      type: ParamType.integer,
      description: 'Number of rows, including the original',
      min: 1,
    ),
    ParamSpec(
      name: 'columnSpacing',
      type: ParamType.distance,
      description: 'Distance between columns along X',
    ),
    ParamSpec(
      name: 'rowSpacing',
      type: ParamType.distance,
      description: 'Distance between rows along Y',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'ARRAY  Select objects to array:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();

    final columns =
        context.args.integer('columns') ??
        await context.input.integer(
          'ARRAY  Enter number of columns:',
          defaultValue: 3,
        );
    final rows =
        context.args.integer('rows') ??
        await context.input.integer(
          'ARRAY  Enter number of rows:',
          defaultValue: 3,
        );
    if (columns < 1 || rows < 1) {
      return const CommandResult.failed(
        'The array needs at least one row and one column.',
      );
    }
    final columnSpacing =
        context.args.number('columnSpacing') ??
        await context.input.number('ARRAY  Enter the column spacing:');
    final rowSpacing =
        context.args.number('rowSpacing') ??
        await context.input.number('ARRAY  Enter the row spacing:');

    final total = columns * rows - 1;
    if (total <= 0) {
      return const CommandResult.cancelled(
        'A one-by-one array is the original.',
      );
    }
    // A large array is easy to ask for by accident and expensive to undo by
    // hand, so a confirmation stands between the request and the drawing.
    if (total * ids.length > 5000) {
      final proceed = await context.services.requestApproval(
        'Create a large array?',
        'This would add ${total * ids.length} objects to the drawing.',
      );
      if (!proceed) return const CommandResult.cancelled();
    }

    final committed = context.edit('Array', (transaction) {
      for (var row = 0; row < rows; row++) {
        for (var column = 0; column < columns; column++) {
          if (row == 0 && column == 0) continue;
          transaction.duplicate(
            ids,
            Mat3.translation(columnSpacing * column, rowSpacing * row),
          );
        }
      }
    });
    if (committed == null) {
      return const CommandResult.failed('Nothing was arrayed.');
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Array: ${committed.change.added.length} copies created.',
      data: {'ids': committed.change.added},
      transaction: committed,
    );
  }
}
