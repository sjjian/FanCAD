import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'layout_helpers.dart';

const _category = 'Output';

class LayoutRenameCommand extends FanCadCommand {
  const LayoutRenameCommand();

  @override
  String get id => 'layout.rename';
  @override
  String get title => 'Rename Layout';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['layoutrename', 'renamelayout'];
  @override
  String get description =>
      'Renames a paper layout tab. The sheet, viewports and paper '
      'entities stay put. Model cannot be renamed.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'name',
      type: ParamType.text,
      description: 'Tab to rename. Defaults to the current paper layout.',
      required: false,
    ),
    ParamSpec(name: 'to', type: ParamType.text, description: 'New tab name'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    var requested = context.args.text('name')?.trim() ?? '';
    if (requested.isEmpty) {
      if (context.document.activeLayout.isModelSpace) {
        requested = await context.resolveText('name', 'Layout to rename:');
      } else {
        requested = context.document.activeLayoutName;
      }
    }
    final source = layoutNamed(context.document, requested);
    if (source == null) {
      return CommandResult.failed('No layout named $requested');
    }
    if (source.isModelSpace) {
      return const CommandResult.failed('Model cannot be renamed.');
    }

    final destName = (await context.resolveText(
      'to',
      'New layout name:',
    )).trim();
    if (destName.isEmpty) {
      return const CommandResult.failed('The new name is empty.');
    }
    if (destName.toLowerCase() == 'model') {
      return const CommandResult.failed('Model is reserved.');
    }
    if (destName == source.name) {
      return CommandResult.ok(
        message: 'Layout is already "$destName".',
        data: {'name': destName},
      );
    }
    final clash = context.document.layouts.any(
      (layout) =>
          layout.name.toLowerCase() == destName.toLowerCase() &&
          layout.name.toLowerCase() != source.name.toLowerCase(),
    );
    if (clash) {
      return CommandResult.failed('Layout "$destName" already exists.');
    }

    final wasActive = context.document.activeLayoutName == source.name;
    final committed = context.edit('Rename Layout', (transaction) {
      transaction.putLayout(source.copyWith(name: destName));
      if (wasActive) transaction.setActiveLayout(destName);
      transaction.removeLayout(source.name);
    });
    if (committed == null) {
      return const CommandResult.failed('The layout was not renamed.');
    }
    context.services.invalidate();
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Layout "${source.name}" is now "$destName".',
      data: {'name': destName, 'from': source.name, 'block': source.blockName},
      transaction: committed,
    );
  }
}
