import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditChangeLinetypeCommand extends FanCadCommand {
  const EditChangeLinetypeCommand();

  @override
  String get id => 'edit.changeLinetype';
  @override
  String get title => 'Change Linetype';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['lt', 'linetype', 'chlt'];
  @override
  String get description =>
      'Sets the linetype of the selected objects. Stock names '
      '(DASHED, HIDDEN, CENTER, PHANTOM, DOT, DASHDOT, DIVIDE, Continuous) '
      'are added to the drawing if they are not there yet. ByLayer and '
      'ByBlock inherit instead.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec(
      name: 'linetype',
      type: ParamType.text,
      description: 'Linetype name, ByLayer or ByBlock',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'LINETYPE  Select objects:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final raw = (await context.resolveText(
      'linetype',
      'LINETYPE  Enter name (DASHED, HIDDEN, CENTER, ByLayer):',
    )).trim();
    if (raw.isEmpty) {
      return const CommandResult.failed('A linetype name is required.');
    }

    final lower = raw.toLowerCase();
    final String applied;
    LineTypeDef? install;
    if (lower == 'bylayer') {
      applied = 'ByLayer';
    } else if (lower == 'byblock') {
      applied = 'ByBlock';
    } else {
      final existing = _lineTypeNamed(context.document, raw);
      final stock = existing ?? LineTypeDef.builtin(raw);
      if (stock == null) {
        return CommandResult.failed(
          'Unknown linetype "$raw". Use DASHED, HIDDEN, CENTER, PHANTOM, '
          'DOT, DASHDOT, DIVIDE, Continuous, ByLayer or ByBlock.',
        );
      }
      applied = stock.name;
      if (existing == null) install = stock;
    }

    final committed = context.edit('Change Linetype', (transaction) {
      if (install != null) transaction.putLineType(install);
      transaction.setLineTypeOf(ids, applied);
    });
    if (committed == null) {
      return const CommandResult.failed('Nothing changed.');
    }
    return CommandResult(
      status: CommandStatus.ok,
      message:
          'Set linetype "$applied" on '
          '${committed.change.modified.length} object(s).',
      transaction: committed,
    );
  }
}

LineTypeDef? _lineTypeNamed(CadDocument document, String name) {
  final exact = document.lineTypes[name];
  if (exact != null) return exact;
  final lower = name.toLowerCase();
  for (final def in document.lineTypes.values) {
    if (def.name.toLowerCase() == lower) return def;
  }
  return null;
}
