import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _view = 'View';

class ViewZoomExtentsCommand extends FanCadCommand
    implements CommandKeybindings {
  const ViewZoomExtentsCommand();

  @override
  String get id => 'view.zoomExtents';
  @override
  String get title => 'Zoom Extents';
  @override
  String get category => _view;
  @override
  List<String> get aliases => const ['ze', 'zoomextents'];
  @override
  String? get icon => 'zoom-extents';
  @override
  List<String> get keybindings => const ['ctrl+shift+e', 'home'];
  @override
  String get description => 'Fits the whole drawing in the window.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    if (context.document.isEmpty) {
      return const CommandResult.failed('The drawing is empty.');
    }
    context.services.zoomTo(null);
    return const CommandResult.ok();
  }
}
