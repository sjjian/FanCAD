import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawTextCommand extends FanCadCommand {
  const DrawTextCommand();

  @override
  String get id => 'draw.text';
  @override
  String get title => 'Text';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['t', 'text', 'dtext'];
  @override
  String? get icon => 'text';
  @override
  String get description => 'Places a single line of text.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'content',
      type: ParamType.text,
      description: 'The text to place',
    ),
    ParamSpec.point('at', description: 'Insertion point'),
    ParamSpec(
      name: 'height',
      type: ParamType.distance,
      description: 'Cap height in drawing units',
      required: false,
      defaultValue: 2.5,
    ),
    ParamSpec(
      name: 'rotation',
      type: ParamType.angle,
      description: 'Rotation in degrees',
      required: false,
      defaultValue: 0,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final content = await context.resolveText(
      'content',
      'TEXT  Enter the text:',
    );
    if (content.isEmpty) {
      return const CommandResult.cancelled('No text was entered.');
    }
    final height =
        context.args.number('height') ??
        await context.input.number('TEXT  Specify height:', defaultValue: 2.5);
    final rotationDegrees = context.args.number('rotation') ?? 0;
    final rotation = rotationDegrees * math.pi / 180;

    context.input.setPreview((cursor) {
      final box = TextGeometry(
        text: content,
        origin: cursor,
        height: height,
        rotation: rotation,
        styleName: 'Standard',
      ).estimatedBounds();
      return box.isEmpty ? const [] : [OverlayRect(box.min, box.max)];
    });
    final at = await context.resolvePoint(
      'at',
      'TEXT  Specify insertion point:',
    );
    context.input.setPreview(null);

    return commitDraw(context, 'Text', [
      TextEntity(
        id: 0,
        props: EntityProps(layer: context.document.currentLayer),
        position: at,
        content: content,
        height: height,
        rotation: rotation,
      ),
    ]);
  }
}
