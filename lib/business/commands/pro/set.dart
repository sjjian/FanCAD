import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Output';

class LayoutSetCommand extends FanCadCommand {
  const LayoutSetCommand();

  @override
  String get id => 'layout.set';
  @override
  String get title => 'Set Layout';
  @override
  String get category => _category;
  @override
  String get description =>
      'Switches the active layout (Model or a paper tab).';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'name', type: ParamType.text, description: 'Layout name'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final name = await context.resolveText('name', 'Layout name:');
    if (!context.document.setActiveLayout(name)) {
      return CommandResult.failed('No layout named $name');
    }
    context.session
      ..maximizedLayoutName = null
      ..maximizedViewportIndex = null;
    context.services.invalidate();
    context.services.zoomTo(null);
    return CommandResult.ok(message: 'Active layout is $name');
  }
}
