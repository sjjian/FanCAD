import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';

import '../command_base.dart';
import 'xref_helpers.dart';

const _category = 'Output';

class XrefReloadCommand extends FanCadCommand {
  const XrefReloadCommand();

  @override
  String get id => 'xref.reload';
  @override
  String get title => 'Reload Xref';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['xrefreload'];
  @override
  String get description =>
      'Re-reads attached external references from their stored paths. '
      'Omit the name to reload the selected xref, or the only xref in '
      'the drawing.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'name',
      type: ParamType.text,
      required: false,
      description: 'Xref block to reload. Defaults to the selection.',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final targets = xrefsFromContext(context);
    if (targets.isEmpty) {
      return const CommandResult.failed('No xref was selected.');
    }

    final loaded = <({BlockRecord block, CadDocument foreign})>[];
    for (final block in targets) {
      final path = block.xrefPath;
      if (path.isEmpty || !File(path).existsSync()) {
        return CommandResult.failed(
          'Cannot find the file for "${block.name}".',
        );
      }
      try {
        final imported = await DrawingImporter().open(path);
        loaded.add((block: block, foreign: imported.document));
      } on Object catch (error) {
        return CommandResult.failed('Could not reload "${block.name}": $error');
      }
    }

    final committed = context.edit('Reload xref', (transaction) {
      for (final item in loaded) {
        const XrefResolver().attach(
          host: context.document,
          foreign: item.foreign,
          path: item.block.xrefPath,
          blockName: item.block.name,
          transaction: transaction,
        );
      }
    });
    if (committed == null) {
      return const CommandResult.failed('The xref was not reloaded.');
    }
    context.services.invalidate();
    final names = [for (final item in loaded) item.block.name];
    return CommandResult(
      status: CommandStatus.ok,
      message: names.length == 1
          ? 'Reloaded ${names.single}.'
          : 'Reloaded ${names.length} xrefs.',
      data: {
        'blocks': names,
        'entities': [for (final item in loaded) item.foreign.entityCount],
      },
      transaction: committed,
    );
  }
}
