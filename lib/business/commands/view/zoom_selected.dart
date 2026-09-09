import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _view = 'View';

class ViewZoomSelectedCommand extends FanCadCommand {
  const ViewZoomSelectedCommand();

  @override
  String get id => 'view.zoomSelected';
  @override
  String get title => 'Zoom to Selection';
  @override
  String get category => _view;
  @override
  List<String> get aliases => const ['zs'];
  @override
  String get description => 'Fits the selected objects in the window.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = context.selection.ids;
    if (ids.isEmpty) {
      return const CommandResult.failed('Nothing is selected.');
    }
    var box = const Bounds2.empty();
    for (final id in ids) {
      final entity = context.document.entity(id);
      if (entity != null) {
        box = box.union(context.document.boundsOfEntity(entity));
      }
    }
    if (box.isEmpty) {
      return const CommandResult.failed('The selection has no extent.');
    }
    context.services.zoomTo(box);
    return const CommandResult.ok();
  }
}
