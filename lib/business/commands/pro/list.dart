import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Output';

class LayoutListCommand extends FanCadCommand {
  const LayoutListCommand();

  @override
  String get id => 'layout.list';
  @override
  String get title => 'List Layouts';
  @override
  String get category => _category;
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  String get description =>
      'Lists model and paper-space layouts and their viewports.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final layouts = [
      for (final layout in context.document.layouts)
        {
          'name': layout.name,
          'model': layout.isModelSpace,
          'paper': [layout.paperWidth, layout.paperHeight],
          'viewports': layout.viewports.length,
          'tabOrder': layout.tabOrder,
          'plotRotation': layout.plotRotation,
          'plotScale': layout.plotScale,
          'plotFit': layout.plotFit,
          'plotOffset': [layout.plotOffsetX, layout.plotOffsetY],
          'current': layout.name == context.document.activeLayoutName,
          if (layout.plotWindow case final box?)
            'plotWindow': [box.minX, box.minY, box.maxX, box.maxY],
        },
    ];
    return CommandResult.ok(
      message: '${layouts.length} layout(s).',
      data: {'layouts': layouts},
    );
  }
}
