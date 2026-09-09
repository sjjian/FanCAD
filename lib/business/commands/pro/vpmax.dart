import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'viewport_helpers.dart';

const _category = 'Output';

class LayoutVpmaxCommand extends FanCadCommand {
  const LayoutVpmaxCommand();

  @override
  String get id => 'layout.vpmax';
  @override
  String get title => 'Maximize Viewport';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['vpmax'];
  @override
  String get description =>
      'Opens model space framed to a paper viewport so the model can '
      'be edited through that window. VPMIN returns to the sheet.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'index',
      type: ParamType.integer,
      description: 'Viewport index on the current layout, from 0',
      required: false,
    ),
    ParamSpec(
      name: 'point',
      type: ParamType.point,
      description: 'A point on the viewport to maximize',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    if (context.session.maximizedLayoutName != null &&
        context.document.activeLayout.isModelSpace) {
      return CommandResult.ok(
        message: 'Viewport is already maximized.',
        data: {
          'layout': context.session.maximizedLayoutName,
          'index': context.session.maximizedViewportIndex,
        },
      );
    }
    final layout = context.document.activeLayout;
    if (layout.isModelSpace) {
      return const CommandResult.failed('VPMAX only works on a paper layout.');
    }
    if (layout.viewports.isEmpty) {
      return const CommandResult.failed('This layout has no viewports.');
    }
    final index = await resolveViewportIndex(context, layout);
    if (index == null) {
      return const CommandResult.failed('No viewport was selected.');
    }
    final viewport = layout.viewports[index];
    if (!viewport.isOn) {
      return const CommandResult.failed(
        'Turn the viewport on before maximizing it.',
      );
    }
    final model = context.document.layouts.firstWhere(
      (item) => item.isModelSpace,
    );
    if (!context.document.setActiveLayout(model.name)) {
      return const CommandResult.failed('Model space is missing.');
    }
    context.session
      ..maximizedLayoutName = layout.name
      ..maximizedViewportIndex = index;
    context.services.invalidate();
    context.services.zoomTo(viewport.modelWindow);
    return CommandResult.ok(
      message: 'Maximized viewport $index from ${layout.name}.',
      data: {
        'layout': layout.name,
        'index': index,
        'center': [viewport.modelCenter.x, viewport.modelCenter.y],
        'scale': viewport.scale,
      },
    );
  }
}
