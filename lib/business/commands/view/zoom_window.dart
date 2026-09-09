import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _view = 'View';

class ViewZoomWindowCommand extends FanCadCommand {
  const ViewZoomWindowCommand();

  @override
  String get id => 'view.zoomWindow';
  @override
  String get title => 'Zoom Window';
  @override
  String get category => _view;
  @override
  List<String> get aliases => const ['zw', 'zoomwindow'];
  @override
  String get description => 'Zooms to a rectangle you specify.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.point('corner1', description: 'First corner'),
    ParamSpec.point('corner2', description: 'Opposite corner'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final first = await context.resolvePoint(
      'corner1',
      'ZOOM  Specify first corner:',
    );
    context.input.setPreview((cursor) => [OverlayRect(first, cursor)]);
    final second = await context.resolvePoint(
      'corner2',
      'ZOOM  Specify opposite corner:',
      basePoint: first,
    );
    context.input.setPreview(null);
    context.services.zoomTo(Bounds2.fromCorners(first, second));
    return const CommandResult.ok();
  }
}
