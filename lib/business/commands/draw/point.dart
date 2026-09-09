import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawPointCommand extends FanCadCommand {
  const DrawPointCommand();

  @override
  String get id => 'draw.point';
  @override
  String get title => 'Point';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['po', 'point'];
  @override
  String get description => 'Places a point marker.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.point('at', description: 'Where to place it'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    context.input.setPreview((cursor) => [OverlayPoint(cursor)]);
    final at = await context.resolvePoint('at', 'POINT  Specify a location:');
    context.input.setPreview(null);
    return commitDraw(context, 'Point', [
      PointEntity(
        id: 0,
        props: EntityProps(layer: context.document.currentLayer),
        position: at,
      ),
    ]);
  }
}
