import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawMtextCommand extends FanCadCommand {
  const DrawMtextCommand();

  @override
  String get id => 'draw.mtext';
  @override
  String get title => 'MText';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['mt', 'mtext'];
  @override
  String? get icon => 'text';
  @override
  String get description =>
      'Places multiline text. Newlines become \\P. Width 0 does not wrap. '
      'Justify is TL…BR or attachment 1–9 (1 is top-left).';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'content',
      type: ParamType.text,
      description: 'The text to place. Use \\P or a newline for a break.',
    ),
    ParamSpec.point('at', description: 'Attachment point'),
    ParamSpec(
      name: 'height',
      type: ParamType.distance,
      description: 'Cap height in drawing units',
      required: false,
      defaultValue: 2.5,
    ),
    ParamSpec(
      name: 'width',
      type: ParamType.distance,
      description: 'Wrapping width. 0 means no wrap.',
      required: false,
      defaultValue: 0,
    ),
    ParamSpec(
      name: 'rotation',
      type: ParamType.angle,
      description: 'Rotation in degrees',
      required: false,
      defaultValue: 0,
    ),
    ParamSpec(
      name: 'justify',
      type: ParamType.text,
      description: 'TL, TC, TR, ML, MC, MR, BL, BC, BR',
      required: false,
    ),
    ParamSpec(
      name: 'attachment',
      type: ParamType.integer,
      description: 'Attachment point 1–9',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final raw = await context.resolveText('content', 'MTEXT  Enter the text:');
    if (raw.isEmpty) {
      return const CommandResult.cancelled('No text was entered.');
    }
    final content = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\n', r'\P');
    final height =
        context.args.number('height') ??
        await context.input.number('MTEXT  Specify height:', defaultValue: 2.5);
    if (height <= 0) {
      return const CommandResult.failed('Text height must be positive.');
    }
    final width = context.args.number('width') ?? 0;
    if (width < 0) {
      return const CommandResult.failed('Text width cannot be negative.');
    }
    final rotationDegrees = context.args.number('rotation') ?? 0;
    final rotation = rotationDegrees * math.pi / 180;
    final attachment = _mtextAttachment(context);
    if (attachment == null) {
      return const CommandResult.failed(
        'Justify must be TL…BR or attachment 1–9.',
      );
    }

    context.input.setPreview((cursor) {
      final box = TextGeometry(
        text: stripMTextFormatting(content),
        origin: cursor,
        height: height,
        rotation: rotation,
        styleName: 'Standard',
        rectangleWidth: width,
        isMultiline: true,
      ).estimatedBounds();
      return box.isEmpty ? const [] : [OverlayRect(box.min, box.max)];
    });
    final at = await context.resolvePoint(
      'at',
      'MTEXT  Specify attachment point:',
    );
    context.input.setPreview(null);

    return commitDraw(context, 'MText', [
      MTextEntity(
        id: 0,
        props: EntityProps(layer: context.document.currentLayer),
        position: at,
        content: content,
        height: height,
        rotation: rotation,
        rectangleWidth: width,
        attachment: attachment,
      ),
    ]);
  }
}

int? _mtextAttachment(CommandContext context) {
  final code = context.args.integer('attachment');
  if (code != null) {
    if (code < 1 || code > 9) return null;
    return code;
  }
  final justify = context.args.text('justify')?.trim() ?? '';
  if (justify.isEmpty) return 1;
  final next = Construct.parseTextJustify(
    justify,
    currentH: TextHAlign.left,
    currentV: TextVAlign.top,
  );
  if (next == null) return null;
  final h = switch (next.h) {
    TextHAlign.right => 2,
    TextHAlign.center || TextHAlign.middle || TextHAlign.fit => 1,
    _ => 0,
  };
  final v = switch (next.v) {
    TextVAlign.top => 0,
    TextVAlign.middle => 1,
    _ => 2,
  };
  return 1 + v * 3 + h;
}
