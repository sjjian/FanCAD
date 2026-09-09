import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawRectangleCommand extends FanCadCommand {
  const DrawRectangleCommand();

  @override
  String get id => 'draw.rectangle';
  @override
  String get title => 'Rectangle';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['rec', 'rectang', 'rectangle'];
  @override
  String? get icon => 'rectangle';
  @override
  String get description =>
      'Draws an axis-aligned rectangle as a closed polyline.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.point('corner1', description: 'First corner'),
    ParamSpec.point('corner2', description: 'Opposite corner'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final first = await context.resolvePoint(
      'corner1',
      'RECTANG  Specify first corner:',
    );
    context.input.setPreview((cursor) => [OverlayRect(first, cursor)]);
    final second = await context.resolvePoint(
      'corner2',
      'RECTANG  Specify opposite corner:',
      basePoint: first,
    );
    context.input.setPreview(null);

    final rectangle = Construct.rectangle(
      first,
      second,
      props: EntityProps(layer: context.document.currentLayer),
    );
    if (rectangle == null) {
      return const CommandResult.failed('The rectangle has no area.');
    }
    return commitDraw(context, 'Rectangle', [rectangle]);
  }
}
