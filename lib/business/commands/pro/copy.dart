import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'layout_helpers.dart';

const _category = 'Output';

class LayoutCopyCommand extends FanCadCommand {
  const LayoutCopyCommand();

  @override
  String get id => 'layout.copy';
  @override
  String get title => 'Copy Layout';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['layoutcopy', 'copylayout'];
  @override
  String get description =>
      'Duplicates a paper layout: sheet size, viewports, and the '
      'entities on that sheet. Model cannot be copied.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'name',
      type: ParamType.text,
      description: 'Tab to copy. Defaults to the current paper layout.',
      required: false,
    ),
    ParamSpec(
      name: 'to',
      type: ParamType.text,
      description: 'Name of the new tab. Defaults to the next LayoutN.',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    var requested = context.args.text('name')?.trim() ?? '';
    if (requested.isEmpty) {
      if (context.document.activeLayout.isModelSpace) {
        requested = await context.resolveText('name', 'Layout to copy:');
      } else {
        requested = context.document.activeLayoutName;
      }
    }
    final source = layoutNamed(context.document, requested);
    if (source == null) {
      return CommandResult.failed('No layout named $requested');
    }
    if (source.isModelSpace) {
      return const CommandResult.failed('Model cannot be copied.');
    }

    var destName = context.args.text('to')?.trim() ?? '';
    if (destName.isEmpty) destName = nextLayoutName(context.document);
    if (destName.toLowerCase() == 'model') {
      return const CommandResult.failed('Model is reserved.');
    }
    final clash = context.document.layouts.any(
      (layout) => layout.name.toLowerCase() == destName.toLowerCase(),
    );
    if (clash) {
      return CommandResult.failed('Layout "$destName" already exists.');
    }

    var tabOrder = 0;
    for (final layout in context.document.layouts) {
      if (layout.tabOrder > tabOrder) tabOrder = layout.tabOrder;
    }
    final dest = Layout(
      name: destName,
      blockName: nextPaperBlock(context.document),
      tabOrder: tabOrder + 1,
      paperWidth: source.paperWidth,
      paperHeight: source.paperHeight,
      plotRotation: source.plotRotation,
      plotWindow: source.plotWindow,
      plotScale: source.plotScale,
      plotFit: source.plotFit,
      plotOffsetX: source.plotOffsetX,
      plotOffsetY: source.plotOffsetY,
      viewports: [...source.viewports],
    );
    final paper = context.document.entitiesOf(source.blockName).toList();
    final committed = context.edit('Copy Layout', (transaction) {
      transaction
        ..putLayout(dest)
        ..setActiveLayout(destName);
      for (final entity in paper) {
        transaction.add(entity.withId(0), blockName: dest.blockName);
      }
    });
    if (committed == null) {
      return const CommandResult.failed('The layout was not copied.');
    }
    context.services.invalidate();
    context.services.zoomTo(null);
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Layout "$destName" copied from "${source.name}".',
      data: {
        'name': destName,
        'from': source.name,
        'block': dest.blockName,
        'entities': paper.length,
        'viewports': dest.viewports.length,
      },
      transaction: committed,
    );
  }
}
