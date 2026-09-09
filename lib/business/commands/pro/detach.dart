import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'xref_helpers.dart';

const _category = 'Output';

class XrefDetachCommand extends FanCadCommand {
  const XrefDetachCommand();

  @override
  String get id => 'xref.detach';
  @override
  String get title => 'Detach Xref';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['xrefdetach'];
  @override
  CommandRisk get risk => CommandRisk.destructive;
  @override
  String get description =>
      'Removes an external reference and every insert that shows it. '
      'Omit the name to detach the selected xref, or the only xref in '
      'the drawing.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'name',
      type: ParamType.text,
      required: false,
      description: 'Xref block to detach. Defaults to the selection.',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final targets = xrefsFromContext(context);
    if (targets.isEmpty) {
      return const CommandResult.failed('No xref was selected.');
    }

    final names = [for (final block in targets) block.name];
    final committed = context.edit('Detach xref', (transaction) {
      for (final block in targets) {
        const XrefResolver().detach(
          host: context.document,
          name: block.name,
          transaction: transaction,
        );
      }
    });
    if (committed == null) {
      return const CommandResult.failed('The xref was not detached.');
    }
    context.selection.clear();
    context.services.invalidate();
    return CommandResult(
      status: CommandStatus.ok,
      message: names.length == 1
          ? 'Detached ${names.single}.'
          : 'Detached ${names.length} xrefs.',
      data: {'blocks': names},
      transaction: committed,
    );
  }
}
