import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'layout_helpers.dart';

const _category = 'Output';

class LayoutDeleteCommand extends FanCadCommand {
  const LayoutDeleteCommand();

  @override
  String get id => 'layout.delete';
  @override
  String get title => 'Delete Layout';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['layoutremove'];
  @override
  CommandRisk get risk => CommandRisk.destructive;
  @override
  String get description =>
      'Removes a paper-space layout tab and the entities on that sheet. '
      'Model cannot be deleted. Omit the name to delete the current tab.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'name',
      type: ParamType.text,
      description: 'Tab to delete. Defaults to the current paper layout.',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    var requested = context.args.text('name')?.trim() ?? '';
    if (requested.isEmpty) {
      if (context.document.activeLayout.isModelSpace) {
        requested = await context.resolveText('name', 'Layout to delete:');
      } else {
        requested = context.document.activeLayoutName;
      }
    }
    final layout = layoutNamed(context.document, requested);
    if (layout == null) {
      return CommandResult.failed('No layout named $requested');
    }
    if (layout.isModelSpace) {
      return const CommandResult.failed('Model cannot be deleted.');
    }

    final paperIds = [
      for (final entity in context.document.entitiesOf(layout.blockName))
        entity.id,
    ];
    final sharedBlock =
        context.document.layouts
            .where((item) => item.blockName == layout.blockName)
            .length >
        1;
    final wasActive = context.document.activeLayoutName == layout.name;
    final modelName = context.document.layouts
        .firstWhere((item) => item.isModelSpace)
        .name;

    final committed = context.edit('Delete Layout', (transaction) {
      if (!sharedBlock) {
        for (final id in paperIds) {
          transaction.erase(id);
        }
      }
      if (wasActive) transaction.setActiveLayout(modelName);
      transaction.removeLayout(layout.name);
    });
    if (committed == null) {
      return const CommandResult.failed('The layout was not deleted.');
    }
    context.services.invalidate();
    context.services.zoomTo(null);
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Layout "${layout.name}" deleted.',
      data: {'name': layout.name, 'erased': sharedBlock ? 0 : paperIds.length},
      transaction: committed,
    );
  }
}
