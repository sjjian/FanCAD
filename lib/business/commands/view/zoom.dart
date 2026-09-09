import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _view = 'View';

class ViewZoomInCommand extends FanCadCommand implements CommandKeybindings {
  const ViewZoomInCommand();

  @override
  String get id => 'view.zoomIn';
  @override
  String get title => 'Zoom In';
  @override
  String get category => _view;
  @override
  String? get icon => 'zoom-in';
  @override
  List<String> get keybindings => const ['ctrl+=', 'ctrl+numpadadd'];
  @override
  String get description => 'Magnifies the view about its centre.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    context.services.zoomBy(2);
    return const CommandResult.ok();
  }
}

class ViewZoomOutCommand extends FanCadCommand implements CommandKeybindings {
  const ViewZoomOutCommand();

  @override
  String get id => 'view.zoomOut';
  @override
  String get title => 'Zoom Out';
  @override
  String get category => _view;
  @override
  String? get icon => 'zoom-out';
  @override
  List<String> get keybindings => const ['ctrl+-', 'ctrl+numpadsubtract'];
  @override
  String get description => 'Shrinks the view about its centre.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    context.services.zoomBy(0.5);
    return const CommandResult.ok();
  }
}
