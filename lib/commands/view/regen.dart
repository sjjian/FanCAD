import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _view = 'View';

class ViewRegenCommand extends FanCadCommand {
  const ViewRegenCommand();

  @override
  String get id => 'view.regen';
  @override
  String get title => 'Regenerate';
  @override
  String get category => _view;
  @override
  List<String> get aliases => const ['re', 'regen'];
  @override
  String get description =>
      'Rebuilds the display list, discarding cached curve tessellations.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    context.services.invalidate();
    return const CommandResult.ok(message: 'Display regenerated.');
  }
}
