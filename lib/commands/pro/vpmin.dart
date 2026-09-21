import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Output';

class LayoutVpminCommand extends FanCadCommand {
  const LayoutVpminCommand();

  @override
  String get id => 'layout.vpmin';
  @override
  String get title => 'Minimize Viewport';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['vpmin'];
  @override
  String get description =>
      'Returns to the paper layout left by VPMAX and frames the sheet.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final name = context.session.maximizedLayoutName;
    if (name == null) {
      return const CommandResult.failed('No viewport is maximized.');
    }
    if (!context.document.setActiveLayout(name)) {
      context.session
        ..maximizedLayoutName = null
        ..maximizedViewportIndex = null;
      return CommandResult.failed('Layout "$name" is gone.');
    }
    context.session
      ..maximizedLayoutName = null
      ..maximizedViewportIndex = null;
    context.services.invalidate();
    context.services.zoomTo(null);
    return CommandResult.ok(
      message: 'Returned to $name.',
      data: {'layout': name},
    );
  }
}
