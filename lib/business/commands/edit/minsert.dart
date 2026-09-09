import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Modify';

class EditMinsertCommand extends FanCadCommand {
  const EditMinsertCommand();

  @override
  String get id => 'edit.minsert';
  @override
  String get title => 'MInsert';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['minsert'];
  @override
  String get description =>
      'Places a rectangular array of a named block as one insert. The '
      'copies stay one object, so moving the insert moves the whole grid.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'name',
      type: ParamType.text,
      description: 'Block to array',
    ),
    ParamSpec.point('at', description: 'Insertion point of the first cell'),
    ParamSpec(
      name: 'columns',
      type: ParamType.integer,
      description: 'Number of columns',
    ),
    ParamSpec(
      name: 'rows',
      type: ParamType.integer,
      description: 'Number of rows',
    ),
    ParamSpec(
      name: 'columnSpacing',
      type: ParamType.distance,
      description: 'Distance between columns',
      required: false,
    ),
    ParamSpec(
      name: 'rowSpacing',
      type: ParamType.distance,
      description: 'Distance between rows',
      required: false,
    ),
    ParamSpec(
      name: 'scale',
      type: ParamType.distance,
      description: 'Uniform scale factor',
      required: false,
      defaultValue: 1,
    ),
    ParamSpec(
      name: 'rotation',
      type: ParamType.angle,
      description: 'Rotation in degrees',
      required: false,
      defaultValue: 0,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final requested = (await context.resolveText(
      'name',
      'MINSERT  Enter block name:',
    )).trim();
    if (requested.isEmpty) {
      return const CommandResult.failed('MINSERT needs a block name.');
    }
    final block = insertableBlock(context.document, requested);
    if (block == null) {
      return CommandResult.failed(
        'There is no insertable block named "$requested".',
      );
    }
    final columns = await _resolveCount(
      context,
      'columns',
      'MINSERT  Enter number of columns:',
    );
    final rows = await _resolveCount(
      context,
      'rows',
      'MINSERT  Enter number of rows:',
    );
    if (columns < 1 || rows < 1) {
      return const CommandResult.failed(
        'MINSERT needs at least one column and one row.',
      );
    }
    if (columns == 1 && rows == 1) {
      return const CommandResult.failed(
        'MINSERT needs more than one row or column. Use INSERT for a single copy.',
      );
    }
    final columnSpacing = columns == 1
        ? 0.0
        : await context.resolveNumber(
            'columnSpacing',
            'MINSERT  Specify distance between columns:',
          );
    final rowSpacing = rows == 1
        ? 0.0
        : await context.resolveNumber(
            'rowSpacing',
            'MINSERT  Specify distance between rows:',
          );
    if (columns > 1 && columnSpacing.abs() < 1e-12) {
      return const CommandResult.failed(
        'Column spacing must be non-zero when there is more than one column.',
      );
    }
    if (rows > 1 && rowSpacing.abs() < 1e-12) {
      return const CommandResult.failed(
        'Row spacing must be non-zero when there is more than one row.',
      );
    }
    final scale = context.args.number('scale') ?? 1;
    if (scale.abs() < 1e-12) {
      return const CommandResult.failed('Insert scale cannot be zero.');
    }
    final rotation = (context.args.number('rotation') ?? 0) * math.pi / 180;
    final at = await context.resolvePoint(
      'at',
      'MINSERT  Specify insertion point:',
    );
    final attributes = await attributeValues(context, block.name);
    final committed = context.edit('MInsert', (transaction) {
      transaction.add(
        InsertEntity(
          id: 0,
          props: EntityProps(layer: context.document.currentLayer),
          blockName: block.name,
          position: at,
          scale: Vec2(scale, scale),
          rotation: rotation,
          columnCount: columns,
          rowCount: rows,
          columnSpacing: columnSpacing,
          rowSpacing: rowSpacing,
          attributes: attributes,
        ),
      );
    });
    if (committed == null) {
      return const CommandResult.failed('Nothing was inserted.');
    }
    context.selection.replace(committed.change.added);
    return CommandResult(
      status: CommandStatus.ok,
      message: 'MInsert "${block.name}": $columns×$rows references.',
      data: {'block': block.name, 'ids': committed.change.added},
      transaction: committed,
    );
  }
}

Future<int> _resolveCount(
  CommandContext context,
  String name,
  String prompt,
) async {
  final supplied = context.args.integer(name);
  if (supplied != null) return supplied;
  final value = await context.input.number(prompt, defaultValue: 1);
  return value.round();
}
