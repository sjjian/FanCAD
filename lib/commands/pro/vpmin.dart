import 'package:fancad_command/fancad_command.dart';

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
    final name = context.services.maximizedLayout(context.session);
    if (name == null) {
      return const CommandResult.failed('No viewport is maximized.');
    }
    if (!context.document.setActiveLayout(name)) {
      context.services.setMaximizedViewport(context.session);
      return CommandResult.failed('Layout "$name" is gone.');
    }
    context.services.setMaximizedViewport(context.session);
    context.services.invalidate();
    context.services.zoomTo(null);
    return CommandResult.ok(
      message: 'Returned to $name.',
      data: {'layout': name},
    );
  }
}
