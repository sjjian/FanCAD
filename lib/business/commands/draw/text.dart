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
  String get description =>
      'Places a single line of text. Style defaults to the current '
      'TEXTSTYLE. Justify is Left, Center, Right or a corner code such as TL.';
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
    textStyleParam,
    ParamSpec(
      name: 'justify',
      type: ParamType.text,
      description: 'Left, Center, Right, TL, TC, TR, ML, MC, MR, BL, BC, BR',
      required: false,
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
    final styleName = textStyleName(context);
    final style = context.document.namedTextStyle(styleName);
    if (style == null) {
      return CommandResult.failed('There is no text style named "$styleName".');
    }
    final align = _textAlign(context.args.text('justify')?.trim() ?? '');
    if (align == null) {
      return const CommandResult.failed(
        'Justify must be Left, Center, Right or a corner code such as TL.',
      );
    }
    final height =
        context.args.number('height') ??
        (style.height > 0
            ? style.height
            : await context.input.number(
                'TEXT  Specify height:',
                defaultValue: 2.5,
              ));
    if (height <= 0) {
      return const CommandResult.failed('Text height must be positive.');
    }
    final rotationDegrees = context.args.number('rotation') ?? 0;
    final rotation = rotationDegrees * math.pi / 180;

    context.input.setPreview((cursor) {
      final box = TextGeometry(
        text: content,
        origin: cursor,
        height: height,
        rotation: rotation,
        styleName: style.name,
        hAlign: align.h,
        vAlign: align.v,
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
        styleName: style.name,
        hAlign: align.h,
        vAlign: align.v,
      ),
    ]);
  }
}

({TextHAlign h, TextVAlign v})? _textAlign(String justify) {
  if (justify.isEmpty) {
    return (h: TextHAlign.left, v: TextVAlign.baseline);
  }
  final key = justify.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
  if (const {'a', 'align', 'aligned', 'f', 'fit'}.contains(key)) {
    return null;
  }
  return Construct.parseTextJustify(
    justify,
    currentH: TextHAlign.left,
    currentV: TextVAlign.baseline,
  );
}
