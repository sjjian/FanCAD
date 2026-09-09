import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'xref_helpers.dart';

const _category = 'Output';

class XrefBindCommand extends FanCadCommand {
  const XrefBindCommand();

  @override
  String get id => 'xref.bind';
  @override
  String get title => 'Bind Xref';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['xrefbind'];
  @override
  String get description =>
      'Turns an external reference into a local block so the drawing '
      'no longer depends on that file. Inserts stay where they are. '
      'Omit the name to bind the selected xref, or the only xref in '
      'the drawing.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'name',
      type: ParamType.text,
      required: false,
      description: 'Xref block to bind. Defaults to the selection.',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final targets = xrefsFromContext(context);
    if (targets.isEmpty) {
      return const CommandResult.failed('No xref was selected.');
    }

    final names = [for (final block in targets) block.name];
    final committed = context.edit('Bind xref', (transaction) {
      for (final block in targets) {
        const XrefResolver().bind(
          host: context.document,
          name: block.name,
          transaction: transaction,
        );
      }
    });
    if (committed == null) {
      return const CommandResult.failed('The xref was not bound.');
    }
    context.services.invalidate();
    return CommandResult(
      status: CommandStatus.ok,
      message: names.length == 1
          ? 'Bound ${names.single}.'
          : 'Bound ${names.length} xrefs.',
      data: {'blocks': names},
      transaction: committed,
    );
  }
}
